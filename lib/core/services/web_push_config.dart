/// Web-only Firebase configuration for Cloud Messaging (FCM).
///
/// Firebase is used by Conexo for FCM notification TRANSPORT ONLY. The values
/// below are the *public* Firebase Web app configuration plus the *public*
/// Web Push (VAPID) key. These are safe to ship in a web client and are NOT
/// secrets. No service-account private key or Supabase service-role key is
/// ever referenced here.
///
/// Provide the three Console-only values via
/// `--dart-define-from-file=tool/supabase_vercel.json` (and supabase_dev.json):
///
///   "WEB_FIREBASE_API_KEY": "AIza...",              // Web app API key
///   "WEB_FIREBASE_APP_ID": "1:733658775964:web:...",// Web app appId
///   "WEB_FCM_VAPID_KEY": "B......"                   // Web Push certificate (public)
///
/// The remaining values are derivable from the existing project and are
/// pre-filled as defaults (still overridable via dart-define). Until the three
/// Console values are supplied, [isConfigured] is false and all web-FCM code
/// stays a safe no-op — the rest of Conexo Web keeps working.
library;

import 'package:firebase_core/firebase_core.dart';

abstract final class WebPushConfig {
  static const String apiKey =
      String.fromEnvironment('WEB_FIREBASE_API_KEY', defaultValue: '');

  static const String appId =
      String.fromEnvironment('WEB_FIREBASE_APP_ID', defaultValue: '');

  static const String vapidKey =
      String.fromEnvironment('WEB_FCM_VAPID_KEY', defaultValue: '');

  // Derivable from the existing Firebase project (conexoapp-8eeb2).
  static const String messagingSenderId = String.fromEnvironment(
    'WEB_FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '733658775964',
  );

  static const String projectId = String.fromEnvironment(
    'WEB_FIREBASE_PROJECT_ID',
    defaultValue: 'conexoapp-8eeb2',
  );

  static const String authDomain = String.fromEnvironment(
    'WEB_FIREBASE_AUTH_DOMAIN',
    defaultValue: 'conexoapp-8eeb2.firebaseapp.com',
  );

  static const String storageBucket = String.fromEnvironment(
    'WEB_FIREBASE_STORAGE_BUCKET',
    defaultValue: 'conexoapp-8eeb2.firebasestorage.app',
  );

  /// Web FCM can only run once the Console-provided public values are present.
  static bool get isConfigured =>
      apiKey.isNotEmpty && appId.isNotEmpty && vapidKey.isNotEmpty;

  static FirebaseOptions get options => FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain,
        storageBucket: storageBucket,
      );
}
