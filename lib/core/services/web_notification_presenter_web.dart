// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Web implementation: show ONE foreground browser notification.
///
/// Only fires when the browser has already granted notification permission.
/// Deliberately minimal (title + body) and uses [tag] so repeat notifications
/// for the same conversation collapse instead of stacking. Background/closed
/// notifications are handled by the service worker, so this path is only used
/// while the tab is focused — avoiding duplicate notifications.
Future<void> showWebNotification({
  required String title,
  required String body,
  String? tag,
}) async {
  try {
    if (html.Notification.permission != 'granted') return;
    html.Notification(
      title,
      body: body,
      tag: tag,
      icon: 'icons/Icon-192.png',
    );
  } catch (_) {
    // Notifications API unavailable/unsupported — ignore.
  }
}
