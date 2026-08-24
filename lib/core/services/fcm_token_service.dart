import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'fcm_token_repository.dart';
import '../../core/supabase/auth_service.dart';

abstract final class FcmTokenService {
  static const FcmTokenRepository _repository = FcmTokenRepository();

  static String? _currentToken;
  static StreamSubscription<String>? _refreshSubscription;
  static bool _started = false;

  static Future<void> start() async {
    if (_started) return;
    if (kIsWeb) return;
    _started = true;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await registerToken(token);
      }
    } catch (e) {
      debugPrint('FcmTokenService.start getToken failed: $e');
    }

    _refreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) => registerToken(token),
      onError: (e) => debugPrint('FcmTokenService token refresh error: $e'),
    );
  }

  static Future<void> registerToken(String token) async {
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
      _currentToken = token;
    } catch (e) {
      debugPrint('FcmTokenService.registerToken failed: $e');
    }
  }

  static Future<void> stop() async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;
    _started = false;

    if (_currentToken != null) {
      try {
        await _repository.deleteToken(_currentToken!);
      } catch (_) {}
      _currentToken = null;
    }
  }
}
