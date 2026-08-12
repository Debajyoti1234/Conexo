import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'permission_manager.dart';
import '../../features/profile/live_location_repository.dart';
import '../../core/supabase/auth_service.dart';

abstract final class LiveLocationTracker {
  static const _interval = Duration(minutes: 30);
  static const _accuracy = LocationAccuracy.high;

  static Timer? _timer;
  static final LiveLocationRepository _repo = const LiveLocationRepository();

  static bool get isRunning => _timer != null && _timer!.isActive;

  static Future<void> start() async {
    if (isRunning) return;

    final granted = await _checkPermission();
    if (!granted) return;

    await _tick();
    _timer = Timer.periodic(_interval, (_) => _tick());
  }

  static Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _tick() async {
    if (AuthService.currentUser == null) {
      stop();
      return;
    }

    final position = await _getPosition();
    if (position == null) return;

    await _repo.upsert(
      userId: AuthService.currentUser!.id,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  static Future<bool> _checkPermission() async {
    final status = await PermissionManager.check(
      PermissionType.locationWhenInUse,
    );
    if (status == PermissionStatus.granted ||
        status == PermissionStatus.limited) {
      return true;
    }
    if (status == PermissionStatus.denied) {
      final requested = await PermissionManager.request(
        PermissionType.locationWhenInUse,
      );
      return requested == PermissionStatus.granted ||
          requested == PermissionStatus.limited;
    }
    return false;
  }

  static Future<Position?> _getPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: _accuracy),
      );
    } on Exception {
      return null;
    }
  }
}
