import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Idempotent initializer for the Firebase DEFAULT app.
///
/// Firebase is used by Conexo for Cloud Messaging (FCM) ONLY — Supabase remains
/// the primary backend for auth, data, storage and the notification pipeline.
///
/// This guard guarantees `Firebase.initializeApp()` runs exactly once before
/// any `FirebaseMessaging` access, fixing the `[core/no-app]` error that
/// occurred when `getToken()` executed before initialization. It is safe to
/// call from multiple entry points and concurrently (callers share the same
/// in-flight future). Firebase failure is non-fatal: FCM simply becomes
/// unavailable and the rest of the app keeps working.
abstract final class FirebaseInitializer {
  static bool _initialized = false;
  static Future<bool>? _pending;

  static bool get isInitialized => _initialized;

  /// Ensures the default Firebase app exists. Returns true when Firebase is
  /// ready, false when initialization failed (FCM disabled, app continues).
  static Future<bool> ensureInitialized() async {
    if (_initialized) return true;
    return _pending ??= _initialize();
  }

  static Future<bool> _initialize() async {
    try {
      debugPrint('CONEXO_FCM_DIAG firebase_initialize_started');
      await Firebase.initializeApp();
      _initialized = true;
      debugPrint('CONEXO_FCM_DIAG firebase_initialized=YES');
      return true;
    } catch (e) {
      debugPrint('CONEXO_FCM_DIAG firebase_initialized=NO error=$e');
      // Clear the cached future so a later call can retry.
      _pending = null;
      return false;
    }
  }
}
