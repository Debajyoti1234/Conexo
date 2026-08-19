import 'dart:math' as math;

const _earthRadiusMeters = 6371000.0;
const _locationFreshThresholdMinutes = 60;
const _newProfileDaysThreshold = 30;

double haversine(double lat1, double lng1, double lat2, double lng2) {
  final dLat = _toRadians(lat2 - lat1);
  final dLng = _toRadians(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a.clamp(0.0, 1.0)));
  return _earthRadiusMeters * c;
}

double _toRadians(double degrees) => degrees * math.pi / 180.0;

bool isLocationFresh(DateTime? updatedAt) {
  if (updatedAt == null) return false;
  return DateTime.now().difference(updatedAt).inMinutes <=
      _locationFreshThresholdMinutes;
}

bool isNewProfile(DateTime? createdAt) {
  if (createdAt == null) return false;
  return DateTime.now().difference(createdAt).inDays <= _newProfileDaysThreshold;
}

Set<String> eligibleTargetGenders(String? viewerGender) {
  final g = viewerGender?.toLowerCase();
  switch (g) {
    case 'man':
      return const {'Woman'};
    case 'woman':
      return const {'Man'};
    case 'non-binary':
    case 'prefer not to say':
      return const {'Man', 'Woman'};
    default:
      return const {'Man', 'Woman'};
  }
}

bool isValidCoordinate(double? lat, double? lng) {
  if (lat == null || lng == null) return false;
  return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}

String formatDistance(double meters) {
  if (meters.isInfinite || meters.isNaN) return 'Unknown distance';
  if (meters < 1000) {
    final rounded = meters.round();
    return '$rounded m away';
  }
  final km = meters / 1000;
  final roundedKm = km.toStringAsFixed(1);
  return '$roundedKm km away';
}

bool hasSharedInterests(
    List<String> viewerInterests, List<String> candidateInterests) {
  final normalizedViewer = viewerInterests
      .map((i) => i.trim().toLowerCase())
      .where((i) => i.isNotEmpty)
      .toSet();
  final normalizedCandidate = candidateInterests
      .map((i) => i.trim().toLowerCase())
      .where((i) => i.isNotEmpty)
      .toSet();
  return normalizedViewer.any(normalizedCandidate.contains);
}

/// Whether a candidate [age] satisfies the current user's saved age-range
/// discovery preference (`discovery_min_age` / `discovery_max_age`).
///
/// Null boundaries mean "no restriction" for that side, so:
///   • both null  → no age filtering
///   • min only   → age must be >= min
///   • max only   → age must be <= max
///
/// An invalid range (min > max, which the Discovery Preferences UI prevents via
/// clamping) is treated as "no age restriction" rather than hiding everyone.
bool ageWithinDiscoveryPreference(int age, int? minAge, int? maxAge) {
  if (minAge != null && maxAge != null && minAge > maxAge) return true;
  if (minAge != null && age < minAge) return false;
  if (maxAge != null && age > maxAge) return false;
  return true;
}

/// Whether a candidate at [distanceMeters] satisfies the current user's saved
/// distance discovery preference (`discovery_distance_km`).
///
/// A null [maxDistanceKm] represents the "Any" option and applies no distance
/// restriction. The comparison is inclusive of the boundary.
bool distanceWithinDiscoveryPreference(double distanceMeters, int? maxDistanceKm) {
  if (maxDistanceKm == null) return true;
  return distanceMeters <= maxDistanceKm * 1000;
}


