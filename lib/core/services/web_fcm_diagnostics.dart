/// Facade for iOS/Web FCM environment diagnostics.
///
/// Conditional import: mobile/desktop get the no-op stub (never references
/// dart:html), the Web build gets the real collector. Used to pinpoint exactly
/// where iOS Web/PWA push setup stops (standalone mode, SW registration/active,
/// PushManager subscription, permission).
library;

export 'web_fcm_diagnostics_stub.dart'
    if (dart.library.html) 'web_fcm_diagnostics_web.dart';
