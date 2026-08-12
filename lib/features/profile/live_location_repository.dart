import 'package:supabase_flutter/supabase_flutter.dart';

import 'live_location_data.dart';
import '../../core/supabase/auth_service.dart';

class LiveLocationRepository {
  const LiveLocationRepository();

  Future<void> upsert({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    final user = AuthService.currentUser;
    if (user == null || user.id != userId) return;

    await Supabase.instance.client
        .from('live_locations')
        .upsert({
          'user_id': userId,
          'latitude': latitude,
          'longitude': longitude,
          'updated_at': DateTime.now().toIso8601String(),
        });
  }

  Future<List<LiveLocation>> fetchAll() async {
    final user = AuthService.currentUser;
    if (user == null) return const [];

    final data = await Supabase.instance.client
        .from('live_locations')
        .select()
        .order('updated_at', ascending: false);

    return [
      for (final item in data) LiveLocation.fromJson(item),
    ];
  }
}
