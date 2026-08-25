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

    // Register/claim the token for the CURRENT authenticated user via a
    // SECURITY DEFINER RPC. This lets the same physical device move its
    // (globally unique) FCM token from a previously signed-in user to the
    // current one — a plain table upsert cannot, because RLS forbids updating
    // a row still owned by the other user. The RPC is strictly scoped to
    // auth.uid(), so a caller can only ever bind the token to itself.
    await Supabase.instance.client.rpc(
      'register_user_device',
      params: {
        'p_push_token': pushToken,
        'p_platform': platform,
        'p_app_version': appVersion,
      },
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
