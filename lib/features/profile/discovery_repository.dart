import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
import 'discovery_data.dart';
import 'discovery_helpers.dart';

enum DiscoverySortMode { closest, recentlyJoined, bestMatch, mostActive }

class DiscoveryRepository {
  const DiscoveryRepository();

  Future<List<DiscoveryProfile>> fetchNearby({
    double? maxDistanceMeters,
    DiscoverySortMode sort = DiscoverySortMode.closest,
  }) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return const [];

      final viewerProfile = await Supabase.instance.client
          .from('profiles')
          .select(
              'gender, latitude, longitude, interests, display_name, availability_status, discovery_distance_km, discovery_min_age, discovery_max_age')
          .eq('id', user.id)
          .maybeSingle();

      if (viewerProfile == null) return const [];

      final viewerGender = (viewerProfile['gender'] as String?)?.toLowerCase();
      final eligibleGenders = eligibleTargetGenders(viewerGender);
      if (eligibleGenders.isEmpty) return const [];

      final viewerCoords = await _resolveViewerCoords(user.id);
      if (viewerCoords == null) return const [];

      final (viewerLat, viewerLng) = viewerCoords;
      final viewerInterests = _normalizeInterests(
          (viewerProfile['interests'] as List?)?.cast<String>());

      // Phase 9.1B: the current user's saved Discovery Preferences, loaded once
      // per query. Null values mean "no restriction" and leave the existing
      // discovery behavior unchanged.
      final viewerMaxDistanceKm =
          (viewerProfile['discovery_distance_km'] as num?)?.toInt();
      final viewerMinAge = (viewerProfile['discovery_min_age'] as num?)?.toInt();
      final viewerMaxAge = (viewerProfile['discovery_max_age'] as num?)?.toInt();

      final candidateIds = <String>[];
      final candidateRows = <Map<String, dynamic>>[];

      final consumedIds = await _loadConsumedProfileIds(user.id);

      var page = Supabase.instance.client
          .from('profiles')
          .select(
              'id, date_of_birth, photos, bio, interests, languages, gender, location, verification_status, profile_visibility, latitude, longitude, created_at, occupation, display_name, availability_status')
          .neq('id', user.id)
          .eq('profile_visibility', 'public')
          .eq('profile_completed', true)
          .not('date_of_birth', 'is', null)
          .inFilter('gender', eligibleGenders.toList());

      if (consumedIds.isNotEmpty) {
        page = page.not('id', 'in', List<dynamic>.from(consumedIds));
      }

      final candidates = await page;
      for (final row in candidates) {
        candidateIds.add(row['id'] as String);
        candidateRows.add(row);
      }

      final liveLocations = await _fetchLiveLocationsBatch(candidateIds);

      final results = <DiscoveryProfile>[];
      for (final row in candidateRows) {
        final candidateId = row['id'] as String;
        final coords = _resolveCoordsFromBatch(
          candidateId,
          row,
          liveLocations,
        );
        if (coords == null) continue;

        final distance = haversine(
          viewerLat,
          viewerLng,
          coords.lat,
          coords.lng,
        );

        if (maxDistanceMeters != null && distance > maxDistanceMeters) continue;

        // Phase 9.1B: apply the current user's saved distance preference
        // (discovery_distance_km). Null / "Any" applies no restriction.
        if (!distanceWithinDiscoveryPreference(distance, viewerMaxDistanceKm)) {
          continue;
        }

        final base = DiscoveryProfile.fromJson(row);

        // Phase 9.1B: apply the current user's saved age-range preference
        // (discovery_min_age / discovery_max_age). Reuses the existing
        // DOB-based age via DiscoveryProfile.age. Null boundaries do not filter.
        if (!ageWithinDiscoveryPreference(base.age, viewerMinAge, viewerMaxAge)) {
          continue;
        }

        final candidateInterests = _normalizeInterests(base.interests);
        final sharedCount = viewerInterests
            .where((i) => candidateInterests.contains(i))
            .length;

        results.add(DiscoveryProfile(
          id: base.id,
          name: base.name,
          dateOfBirth: base.dateOfBirth,
          photos: base.photos,
          bio: base.bio,
          interests: base.interests,
          languages: base.languages,
          gender: base.gender,
          location: base.location,
          verificationStatus: base.verificationStatus,
          profileVisibility: base.profileVisibility,
          latitude: base.latitude,
          longitude: base.longitude,
          liveLocationUpdatedAt: coords.updatedAt,
          distanceMeters: distance,
          createdAt: base.createdAt,
          occupation: base.occupation,
          displayName: base.displayName,
          availabilityStatus: base.availabilityStatus,
          sharedInterestsCount: sharedCount,
        ));
      }

      _applySort(results, sort);
      return results;
    } catch (_) {
      return const [];
    }
  }

  void _applySort(List<DiscoveryProfile> results, DiscoverySortMode sort) {
    switch (sort) {
      case DiscoverySortMode.closest:
        results.sort((a, b) => (a.distanceMeters ?? double.infinity)
            .compareTo(b.distanceMeters ?? double.infinity));
      case DiscoverySortMode.recentlyJoined:
        results.sort((a, b) {
          final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });
      case DiscoverySortMode.bestMatch:
        results.sort((a, b) {
          final sharedDiff = b.sharedInterestsCount.compareTo(a.sharedInterestsCount);
          if (sharedDiff != 0) return sharedDiff;
          final verifiedDiff = (b.verified ? 1 : 0)
              .compareTo(a.verified ? 1 : 0);
          if (verifiedDiff != 0) return verifiedDiff;
          return (a.distanceMeters ?? double.infinity)
              .compareTo(b.distanceMeters ?? double.infinity);
        });
      case DiscoverySortMode.mostActive:
        results.sort((a, b) => (a.distanceMeters ?? double.infinity)
            .compareTo(b.distanceMeters ?? double.infinity));
    }
  }

  Future<Map<String, _Coords>> _fetchLiveLocationsBatch(
      List<String> userIds) async {
    if (userIds.isEmpty) return const {};
    try {
      final data = await Supabase.instance.client
          .from('live_locations')
          .select()
          .inFilter('user_id', userIds);

      final Map<String, _Coords> map = {};
      for (final item in data) {
        final uid = item['user_id'] as String?;
        if (uid == null) continue;
        final lat = (item['latitude'] as num).toDouble();
        final lng = (item['longitude'] as num).toDouble();
        final updatedAt = DateTime.tryParse(
          item['updated_at'] as String? ?? '',
        );
        if (isValidCoordinate(lat, lng) &&
            updatedAt != null &&
            isLocationFresh(updatedAt)) {
          map[uid] = _Coords(lat: lat, lng: lng, updatedAt: updatedAt);
        }
      }
      return map;
    } catch (_) {
      return const {};
    }
  }

  _Coords? _resolveCoordsFromBatch(
      String userId, Map<String, dynamic> profileRow,
      Map<String, _Coords> liveLocations) {
    final live = liveLocations[userId];
    if (live != null) return live;

    final lat = (profileRow['latitude'] as num?)?.toDouble();
    final lng = (profileRow['longitude'] as num?)?.toDouble();
    if (isValidCoordinate(lat, lng)) {
      return _Coords(lat: lat!, lng: lng!, updatedAt: null);
    }
    return null;
  }

  Future<(double, double)?> _resolveViewerCoords(String userId) async {
    try {
      final liveLoc = await Supabase.instance.client
          .from('live_locations')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (liveLoc != null) {
        final lat = (liveLoc['latitude'] as num).toDouble();
        final lng = (liveLoc['longitude'] as num).toDouble();
        final updatedAt = DateTime.tryParse(
          liveLoc['updated_at'] as String? ?? '',
        );
        if (isValidCoordinate(lat, lng) && isLocationFresh(updatedAt)) {
          return (lat, lng);
        }
      }
    } catch (_) {
      // fallback to profile coordinates
    }

    final profileData = await Supabase.instance.client
        .from('profiles')
        .select('latitude, longitude')
        .eq('id', userId)
        .maybeSingle();

    if (profileData == null) return null;
    final lat = (profileData['latitude'] as num?)?.toDouble();
    final lng = (profileData['longitude'] as num?)?.toDouble();
    if (isValidCoordinate(lat, lng)) {
      return (lat!, lng!);
    }
    return null;
  }
}

class _Coords {
  const _Coords({
    required this.lat,
    required this.lng,
    this.updatedAt,
  });

  final double lat;
  final double lng;
  final DateTime? updatedAt;
}

Set<String> _normalizeInterests(List<String>? interests) {
  if (interests == null) return const {};
  return {
    for (final i in interests)
      i.trim().toLowerCase(),
  };
}

  Future<Set<String>> _loadConsumedProfileIds(String userId) async {
    try {
      final data = await Supabase.instance.client
          .from('connections')
          .select('requester_id, recipient_id')
          .or('requester_id.eq.$userId,recipient_id.eq.$userId')
          .inFilter('status', ['pending', 'accepted']);

      final consumed = <String>{};
      for (final row in data) {
        final requesterId = row['requester_id'] as String;
        final recipientId = row['recipient_id'] as String;
        final otherId = requesterId == userId ? recipientId : requesterId;
        consumed.add(otherId);
      }

      final blocked = await _loadBlockedProfileIds(userId);
      consumed.addAll(blocked);

      return consumed;
    } catch (_) {
      return const {};
    }
  }

  Future<Set<String>> _loadBlockedProfileIds(String userId) async {
    try {
      final data = await Supabase.instance.client
          .from('blocked_users')
          .select('blocked_user_id')
          .eq('blocker_user_id', userId);

      final blocked = <String>{};
      for (final row in data) {
        final blockedId = row['blocked_user_id'] as String?;
        if (blockedId != null) blocked.add(blockedId);
      }
      return blocked;
    } catch (_) {
      return const {};
    }
  }
