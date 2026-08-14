import 'package:geocoding/geocoding.dart';
// ignore: depend_on_referenced_packages
import 'package:geocoding_platform_interface/geocoding_platform_interface.dart'
    as pi;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

import 'permission_manager.dart';
import 'location_service_web_stub.dart'
    if (dart.library.html) 'location_service_web_impl.dart';

/// Outcome of a "use current location" request.
///
/// The UI switches on [outcome] to decide what feedback to show. Coordinates
/// and [areaName] are only populated when [outcome] is [LocationOutcome.success]
/// — they are NEVER fabricated for any failure path.
enum LocationOutcome {
  /// Real GPS coordinates were obtained. [latitude]/[longitude] are set and
  /// [areaName] may be set if reverse geocoding succeeded.
  success,

  /// The user declined the permission this time (can be re-requested later).
  permissionDenied,

  /// The user permanently denied (or the OS restricted) location. The UI should
  /// route the user to App Settings via [PermissionManager.openAppSettings].
  permissionPermanentlyDenied,

  /// Device location services are turned off at the OS level.
  serviceDisabled,

  /// Permission was granted but acquiring a fix failed (timeout / hardware).
  failed,
}

/// Clean result returned to the UI. When [outcome] is not
/// [LocationOutcome.success], all coordinate fields are null by construction.
class LocationResult {
  const LocationResult._({
    required this.outcome,
    this.latitude,
    this.longitude,
    this.areaName,
  });

  const LocationResult.failure(LocationOutcome outcome)
      : this._(outcome: outcome);

  const LocationResult.success({
    required double latitude,
    required double longitude,
    String? areaName,
  }) : this._(
          outcome: LocationOutcome.success,
          latitude: latitude,
          longitude: longitude,
          areaName: areaName,
        );

  final LocationOutcome outcome;

  /// Actual GPS latitude — only non-null on success.
  final double? latitude;

  /// Actual GPS longitude — only non-null on success.
  final double? longitude;

  /// Human-readable area name from reverse geocoding. May be null on success
  /// when the OS geocoder returns nothing; the UI then keeps the name manual.
  final String? areaName;

  bool get isSuccess => outcome == LocationOutcome.success;
}

/// Thin, reusable wrapper around device location + reverse geocoding.
///
/// Keeps all GPS / geocoding logic out of the widgets. Permission handling is
/// delegated to the existing [PermissionManager] — this service does NOT
/// introduce a second permission architecture.
abstract final class LocationService {
  /// Requests permission (if needed), acquires the current GPS position, and
  /// reverse-geocodes it into a readable area name.
  ///
  /// Returns a [LocationResult] describing exactly what happened. Coordinates
  /// are only ever set from a real device fix.
  static Future<LocationResult> detectCurrentLocation() async {
    // OS-level location services must be enabled first — this is distinct from
    // an app permission being denied.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationResult.failure(LocationOutcome.serviceDisabled);
    }

    // Permission via the existing PermissionManager. Only request when the
    // current status is a plain denial (never re-prompt a permanent denial).
    var status = await PermissionManager.check(
      PermissionType.locationWhenInUse,
    );
    if (status == PermissionStatus.denied) {
      status = await PermissionManager.request(
        PermissionType.locationWhenInUse,
      );
    }

    switch (status) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        break;
      case PermissionStatus.permanentlyDenied:
      case PermissionStatus.restricted:
        return const LocationResult.failure(
          LocationOutcome.permissionPermanentlyDenied,
        );
      case PermissionStatus.denied:
        return const LocationResult.failure(LocationOutcome.permissionDenied);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final areaName = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );
      return LocationResult.success(
        latitude: position.latitude,
        longitude: position.longitude,
        areaName: areaName,
      );
    } catch (e) {
      debugPrint('LocationService.detectCurrentLocation failed: $e');
      return const LocationResult.failure(LocationOutcome.failed);
    }
  }

  /// Reverse-geocodes coordinates into a concise "Locality, Country" style name.
  ///
  /// Returns null (never throws) when the OS geocoder yields nothing, so callers
  /// can keep real coordinates while leaving the name for manual entry.
  static Future<String?> _reverseGeocode(double lat, double lng) async {
    if (kIsWeb) {
      return webReverseGeocode(lat, lng);
    }

    try {
      final geocoding = Geocoding();
      final placemarks = await geocoding.placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      return _formatPlacemark(placemarks.first);
    } catch (_) {
      return null;
    }
  }

  /// Builds a short, editable area label from a [pi.Placemark].
  ///
  /// Prefers the most specific populated locality field, then the country,
  /// de-duplicating and dropping empties (e.g. "Bengaluru, India").
  static String? _formatPlacemark(pi.Placemark p) {
    final primary = _firstNonEmpty([
      p.locality,
      p.subLocality,
      p.subAdministrativeArea,
      p.administrativeArea,
    ]);
    final country = p.country?.trim();

    final parts = <String>[];
    if (primary != null) parts.add(primary);
    if (country != null &&
        country.isNotEmpty &&
        country.toLowerCase() != primary?.toLowerCase()) {
      parts.add(country);
    }

    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }
}
