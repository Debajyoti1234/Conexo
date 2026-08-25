// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

/// Web implementation: show ONE foreground browser notification.
///
/// Prefers the ALREADY-REGISTERED FCM service worker's
/// `registration.showNotification(...)`, which is the reliable, spec-recommended
/// way to display notifications on the web (a bare `new Notification(...)` is
/// restricted/flaky on Chrome and unsupported on several browsers). Falls back
/// to `new Notification(...)` only if no service-worker registration is present.
///
/// Background/closed notifications are handled by the service worker itself, so
/// this foreground path never produces a duplicate.
Future<void> showWebNotification({
  required String title,
  required String body,
  String? tag,
}) async {
  try {
    if (html.Notification.permission != 'granted') {
      debugPrint('CONEXO_WEB_FCM_DIAG foreground_notify_skipped=permission');
      return;
    }

    final options = <String, dynamic>{
      'body': body,
      'icon': 'icons/Icon-192.png',
      'badge': 'icons/Icon-192.png',
    };
    if (tag != null && tag.isNotEmpty) options['tag'] = tag;

    final container = html.window.navigator.serviceWorker;
    if (container != null) {
      try {
        final registration = await container.ready
            .timeout(const Duration(seconds: 3));
        await registration.showNotification(title, options);
        debugPrint('CONEXO_WEB_FCM_DIAG foreground_notify_shown=sw');
        return;
      } catch (e) {
        debugPrint('CONEXO_WEB_FCM_DIAG foreground_sw_show_failed=$e');
        // Fall through to the direct Notification below.
      }
    }

    html.Notification(title, body: body, tag: tag, icon: 'icons/Icon-192.png');
    debugPrint('CONEXO_WEB_FCM_DIAG foreground_notify_shown=direct');
  } catch (e) {
    debugPrint('CONEXO_WEB_FCM_DIAG foreground_notify_error=$e');
  }
}
