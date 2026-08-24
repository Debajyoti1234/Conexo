import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';

class FcmTokenRepository {
  const FcmTokenRepository();

  Future<void> upsert({
    required String pushToken,
    required String platform,
    String? appVersion,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    await Supabase.instance.client.from('user_devices').upsert(
      {
        'user_id': user.id,
        'push_token': pushToken,
        'platform': platform,
        'app_version': appVersion,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'push_token',
    );
  }

  Future<void> deleteToken(String pushToken) async {
    await Supabase.instance.client
        .from('user_devices')
        .delete()
        .eq('push_token', pushToken);
  }

  Future<void> deleteAllForUser() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    await Supabase.instance.client
        .from('user_devices')
        .delete()
        .eq('user_id', user.id);
  }
}
