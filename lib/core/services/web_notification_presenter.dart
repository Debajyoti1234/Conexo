/// Facade for showing a foreground browser notification on Web.
///
/// Uses a conditional import so mobile/desktop builds get the no-op stub and
/// never reference `dart:html`, while the Web build gets the real
/// implementation. Background/closed web notifications are handled by
/// `web/firebase-messaging-sw.js`; this is only for the foreground (focused
/// tab) case, mirroring the Android "foreground local notification" behaviour.
library;

export 'web_notification_presenter_stub.dart'
    if (dart.library.html) 'web_notification_presenter_web.dart';
