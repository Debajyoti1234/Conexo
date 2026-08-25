// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

/// Collects and logs the iOS/Web Push environment state so a single on-device
/// PWA session reveals exactly where setup stops. Logs short markers only —
/// never the full token. Web-only (guarded by the conditional import facade).
Future<void> logWebFcmDiagnostics() async {
  void log(String m) => debugPrint('CONEXO_IOS_WEB_FCM_DIAG $m');

  try {
    log('platform_detected=web is_web=true');

    // Standalone PWA vs Safari tab. iOS 16.4+ home-screen PWAs report the
    // 'standalone' display-mode; a plain Safari tab does not.
    var displayModeStandalone = false;
    try {
      displayModeStandalone =
          html.window.matchMedia('(display-mode: standalone)').matches;
    } catch (_) {}
    log('standalone_pwa=$displayModeStandalone '
        'display_mode_standalone=$displayModeStandalone');

    // Notification permission (browser-level).
    var permission = 'unknown';
    try {
      permission = html.Notification.permission ?? 'unknown';
    } catch (_) {}
    log('notification_permission=$permission');

    // Service worker registration/active/scope + Push API + subscription.
    final container = html.window.navigator.serviceWorker;
    if (container == null) {
      log('service_worker_registered=NO service_worker_active=NO '
          'push_manager_supported=false');
      return;
    }
    try {
      final registration =
          await container.ready.timeout(const Duration(seconds: 5));
      final pushManager = registration.pushManager;
      log('service_worker_registered=YES '
          'service_worker_active=${registration.active != null} '
          'service_worker_scope=${registration.scope ?? ''} '
          'push_manager_supported=${pushManager != null}');
      try {
        final subscription = await pushManager?.getSubscription();
        log('push_subscription_exists=${subscription != null}');
      } catch (e) {
        log('push_subscription_error=$e');
      }
    } catch (e) {
      log('service_worker_ready_error=$e');
    }
  } catch (e) {
    log('diagnostics_error=$e');
  }
}
