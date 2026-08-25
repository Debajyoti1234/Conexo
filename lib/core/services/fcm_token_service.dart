import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'fcm_token_repository.dart';
import 'firebase_initializer.dart';
import '../../core/supabase/auth_service.dart';

abstract final class FcmTokenService {
  static const FcmTokenRepository _repository = FcmTokenRepository();

  static String? _currentToken;
  static StreamSubscription<String>? _refreshSubscription;
  static bool _subscribed = false;

  static Future<void> start() async {
    if (kIsWeb) return;

    // FCM requires the Firebase DEFAULT app. Ensure it exists BEFORE touching
    // FirebaseMessaging, otherwise getToken() throws [core/no-app]. If Firebase
    // is unavailable we return so a later call can retry once it is ready.
    final firebaseReady = await FirebaseInitializer.ensureInitialized();
    if (!firebaseReady) {
      debugPrint('CONEXO_FCM_DIAG token_request_skipped=firebase_unavailable');
      return;
    }

    // Subscribe to token refreshes exactly once for the app's lifetime.
    if (!_subscribed) {
      _refreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => registerToken(token),
        onError: (e) => debugPrint('FcmTokenService token refresh error: $e'),
      );
      _subscribed = true;
    }

    // ALWAYS (re)assert the current token -> current user association. This is
    // intentionally NOT behind a one-time guard so it runs on every sign-in:
    // on a same-device account switch the FCM token is unchanged, and
    // registerToken() re-reads the authenticated user at write time, rebinding
    // the token to whoever just logged in.
    try {
      debugPrint('CONEXO_FCM_DIAG token_request_started');
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint(
          'CONEXO_FCM_DIAG token_obtained=${token != null ? 'YES' : 'NO'}');
      if (token != null) {
        debugPrint('CONEXO_FCM_DIAG token_length=${token.length} '
            'token_tail=${_tail(token, 10)}');
        await registerToken(token);
      }
    } catch (e) {
      debugPrint('CONEXO_FCM_DIAG token_request_failed=$e');
      debugPrint('FcmTokenService.start getToken failed: $e');
    }
  }

  static Future<void> registerToken(String token) async {
    _currentToken = token;

    // Bind against whoever is authenticated RIGHT NOW (read at write time to
    // avoid registering a refreshed/stale token to the previous account during
    // an account switch).
    final user = AuthService.currentUser;
    debugPrint('CONEXO_FCM_ACCOUNT_DIAG registration_user='
        '${user != null ? _tail(user.id, 8) : 'null'} '
        'token_tail=${_tail(token, 10)}');
    if (user == null) {
      debugPrint('CONEXO_FCM_ACCOUNT_DIAG registration_result=SKIPPED_no_user');
      return;
    }

    try {
      final String platform = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : 'android';

      String? appVersion;
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = info.version;
      } catch (_) {}

      await _repository.upsert(
        pushToken: token,
        platform: platform,
        appVersion: appVersion,
      );
      debugPrint('CONEXO_FCM_ACCOUNT_DIAG registration_result=SUCCESS');
      debugPrint('CONEXO_FCM_DIAG registration_result=SUCCESS');
    } catch (e) {
      debugPrint('CONEXO_FCM_ACCOUNT_DIAG registration_result=FAILURE error=$e');
      debugPrint('FcmTokenService.registerToken failed: $e');
    }
  }

  /// Removes this device's token association for the CURRENT user. Must be
  /// called BEFORE Supabase signs out, while the session is still valid, so the
  /// RLS-protected delete is authorized. Prevents the previous account from
  /// receiving notifications on a device that has switched users.
  static Future<void> stop() async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;
    _subscribed = false;

    if (_currentToken != null) {
      try {
        await _repository.deleteToken(_currentToken!);
      } catch (_) {}
      _currentToken = null;
    }
  }

  static String _tail(String value, int n) =>
      value.length >= n ? value.substring(value.length - n) : value;
}
