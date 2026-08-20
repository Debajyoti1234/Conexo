import 'profile_data.dart';
import 'profile_validation.dart';
import 'discovery_helpers.dart';

class DiscoveryProfile {
  const DiscoveryProfile({
    required this.id,
    required this.name,
    required this.dateOfBirth,
    required this.photos,
    required this.bio,
    required this.interests,
    required this.languages,
    required this.gender,
    required this.location,
    required this.verificationStatus,
    required this.profileVisibility,
    this.latitude,
    this.longitude,
    this.liveLocationUpdatedAt,
    this.distanceMeters,
    this.createdAt,
    this.occupation,
    this.displayName = '',
    this.availabilityStatus = 'offline',
    this.sharedInterestsCount = 0,
  });

  final String id;
  final String name;
  final DateTime dateOfBirth;
  final List<ProfilePhoto> photos;
  final String bio;
  final List<String> interests;
  final List<String> languages;
  final String gender;
  final String location;
  final VerificationStatus verificationStatus;
  final ProfileVisibility profileVisibility;
  final double? latitude;
  final double? longitude;
  final DateTime? liveLocationUpdatedAt;
  final double? distanceMeters;
  final DateTime? createdAt;
  final String? occupation;
  final String displayName;
  final String availabilityStatus;
  final int sharedInterestsCount;

  int get age => ageFromDate(dateOfBirth);
  String get portrait => photos.isNotEmpty ? photos.first.assetPath : '';
  bool get verified => verificationStatus == VerificationStatus.verified;
  String get formattedDistance => formatDistance(distanceMeters ?? double.infinity);

  factory DiscoveryProfile.fromJson(Map<String, dynamic> json) {
    return DiscoveryProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ??
          json['full_name'] as String? ??
          json['display_name'] as String? ??
          'Unknown',
      dateOfBirth: _parseDateOnly(json['date_of_birth']) ?? DateTime(2000, 1, 1),
      photos: _mapPhotos(json['photos']),
      bio: json['bio'] as String? ?? '',
      interests: _stringList(json['interests']),
      languages: _stringList(json['languages']),
      gender: json['gender'] as String? ?? '',
      location: json['location'] as String? ?? '',
      verificationStatus: _verificationFromJson(json['verification_status']),
      profileVisibility: _visibilityFromJson(json['profile_visibility']),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: _parseDate(json['created_at']),
      occupation: json['occupation'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      availabilityStatus: json['availability_status'] as String? ?? 'offline',
    );
  }

  static List<ProfilePhoto> _mapPhotos(dynamic photosJson) {
    if (photosJson is! List) return const [];
    final photos = <ProfilePhoto>[];
    for (var i = 0; i < photosJson.length; i++) {
      final p = photosJson[i];
      if (p is Map<String, dynamic>) {
        photos.add(ProfilePhoto(
          id: p['id'] as String? ?? 'photo_$i',
          assetPath: p['assetPath'] as String? ?? '',
          isPrimary: p['isPrimary'] as bool? ?? i == 0,
          remoteUrl: p['remoteUrl'] as String?,
          uploadStatus: _uploadStatusFromJson(p['uploadStatus']),
        ));
      }
    }
    return photos;
  }

  static PhotoUploadStatus _uploadStatusFromJson(Object? raw) {
    switch (raw) {
      case 'uploading':
        return PhotoUploadStatus.uploading;
      case 'uploaded':
        return PhotoUploadStatus.uploaded;
      case 'failed':
        return PhotoUploadStatus.failed;
      default:
        return PhotoUploadStatus.local;
    }
  }

  static VerificationStatus _verificationFromJson(Object? raw) {
    switch (raw) {
      case 'pending':
        return VerificationStatus.pending;
      case 'verified':
        return VerificationStatus.verified;
      default:
        return VerificationStatus.notVerified;
    }
  }

  static ProfileVisibility _visibilityFromJson(Object? raw) {
    switch (raw) {
      case 'private':
        return ProfileVisibility.private;
      default:
        return ProfileVisibility.public;
    }
  }

  static List<String> _stringList(Object? raw) {
    if (raw is List) {
      return [for (final e in raw) '$e'];
    }
    return const [];
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  static DateTime? _parseDateOnly(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return null;
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    return null;
  }
}

/// Sort ordering applied to Discovery results.
///
/// Previously declared in `discovery_repository.dart`; relocated here so that
/// the filter-state model and the sort enum live in the same data layer and
/// avoid a circular import between data and repository.
enum DiscoverySortMode { closest, recentlyJoined, bestMatch, mostActive }

/// Verification filter for the temporary Discovery filter sheet.
enum VerificationFilter { any, verified, notVerified }

/// Availability filter for the temporary Discovery filter sheet.
enum AvailabilityFilter { any, available, notAvailable }

/// Sentinel used by [DiscoveryFilterState.copyWith] to distinguish "leave the
/// field unchanged" from "explicitly set to null".
class _FilterCopyWithUnspecified {
  const _FilterCopyWithUnspecified();
  static const _FilterCopyWithUnspecified instance =
      _FilterCopyWithUnspecified();
}

/// One coherent source of truth for the temporary Discovery filter sheet.
///
/// Fields:
///  - [distanceKm]: null means **unrestricted** (no distance cap).
///  - [minAge] / [maxAge]: null means **no bound** on that side.
///  - [sortMode]: how results are ordered (reused from existing sort backend).
///  - [verification]: Any / Verified / Not Verified.
///  - [availability]: Any / Available / Not Available.
///  - [sharedInterests]: when true, only candidates sharing ≥1 interest remain.
///
/// This is a **temporary** filter state — it is applied to the live Discovery
/// result set without persisting to `profiles.discovery_*` columns.
class DiscoveryFilterState {
  const DiscoveryFilterState({
    this.distanceKm,
    this.minAge,
    this.maxAge,
    this.sortMode = DiscoverySortMode.closest,
    this.verification = VerificationFilter.any,
    this.availability = AvailabilityFilter.any,
    this.sharedInterests = false,
  });

  final int? distanceKm;
  final int? minAge;
  final int? maxAge;
  final DiscoverySortMode sortMode;
  final VerificationFilter verification;
  final AvailabilityFilter availability;
  final bool sharedInterests;

  /// The default (reset) state — everything unrestricted except sort, which
  /// defaults to the existing default of [DiscoverySortMode.closest].
  static const defaultValue = DiscoveryFilterState();

  DiscoveryFilterState copyWith({
    Object? distanceKm = _FilterCopyWithUnspecified.instance,
    Object? minAge = _FilterCopyWithUnspecified.instance,
    Object? maxAge = _FilterCopyWithUnspecified.instance,
    DiscoverySortMode? sortMode,
    VerificationFilter? verification,
    AvailabilityFilter? availability,
    bool? sharedInterests,
  }) {
    return DiscoveryFilterState(
      distanceKm: distanceKm is _FilterCopyWithUnspecified
          ? this.distanceKm
          : distanceKm as int?,
      minAge: minAge is _FilterCopyWithUnspecified
          ? this.minAge
          : minAge as int?,
      maxAge: maxAge is _FilterCopyWithUnspecified
          ? this.maxAge
          : maxAge as int?,
      sortMode: sortMode ?? this.sortMode,
      verification: verification ?? this.verification,
      availability: availability ?? this.availability,
      sharedInterests: sharedInterests ?? this.sharedInterests,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiscoveryFilterState &&
        other.distanceKm == distanceKm &&
        other.minAge == minAge &&
        other.maxAge == maxAge &&
        other.sortMode == sortMode &&
        other.verification == verification &&
        other.availability == availability &&
        other.sharedInterests == sharedInterests;
  }

  @override
  int get hashCode => Object.hash(
        distanceKm,
        minAge,
        maxAge,
        sortMode,
        verification,
        availability,
        sharedInterests,
      );
}
