import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class SupabaseClientConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static const String faceVerificationApiUrl = String.fromEnvironment(
    'FACE_VERIFICATION_API_URL',
  );

  static SupabaseClient get client => Supabase.instance.client;

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static final Future<void> ready = _readyCompleter.future;
  static final Completer<void> _readyCompleter = Completer<void>();

  static Future<void> initialize() async {
    if (_initialized) {
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
      return;
    }

    if (url.isEmpty || publishableKey.isEmpty) {
      throw StateError(
        'Supabase configuration is missing. '
        'Provide SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY '
        'using --dart-define.',
      );
    }

    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
    );

    _initialized = true;
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete();
    }
  }
}
