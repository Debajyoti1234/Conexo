import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/theme/app_theme.dart';
import 'core/services/app_navigator.dart';
import 'core/services/fcm_token_service.dart';
import 'core/services/live_location_tracker.dart';
import 'core/services/push_notification_service.dart';
import 'core/supabase/auth_service.dart';
import 'core/supabase/supabase_client.dart';
import 'features/login_screen.dart';
import 'features/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ConexoApp());
}

class ConexoApp extends StatefulWidget {
  const ConexoApp({super.key});

  @override
  State<ConexoApp> createState() => ConexoAppState();
}

class ConexoAppState extends State<ConexoApp> with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSubscription;
  bool _authTrackingSetup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SupabaseClientConfig.ready.then((_) {
      if (mounted) _setupAuthTracking();
    });
  }

  Future<void> _initializePushNotifications() async {
    try {
      await PushNotificationService.initialize();
    } catch (e) {
      debugPrint('Push notification initialization failed: $e');
    }
  }

  /// Starts authenticated background services in a deterministic order.
  ///
  /// PushNotificationService.initialize() runs FIRST and is awaited: it ensures
  /// the Firebase DEFAULT app exists (FCM only), requests the notification
  /// permission, and starts FCM token registration. Only then do we fire the
  /// token safety-net (idempotent) and the location tracker. This guarantees
  /// Firebase is initialized before any FirebaseMessaging access (no
  /// [core/no-app]) and that the notification prompt is not dropped by a
  /// concurrent location prompt. FCM failure is non-fatal.
  Future<void> _startAuthenticatedServices() async {
    await _initializePushNotifications();
    FcmTokenService.start();
    LiveLocationTracker.start();
  }

  void _setupAuthTracking() {
    if (_authTrackingSetup) return;
    _authTrackingSetup = true;
    _authSubscription = AuthService.authStateChanges.listen(_onAuthStateChanged);
    if (AuthService.currentUser != null) {
      _startAuthenticatedServices();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    LiveLocationTracker.stop();
    FcmTokenService.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!SupabaseClientConfig.isInitialized) return;
    if (state == AppLifecycleState.resumed &&
        AuthService.currentUser != null) {
      LiveLocationTracker.start();
    }
  }

  void _onAuthStateChanged(AuthState state) {
    if (state.event == AuthChangeEvent.signedOut) {
      debugPrint('CONEXO_FCM_ACCOUNT_DIAG auth_user_changed=signedOut');
      LiveLocationTracker.stop();
      FcmTokenService.stop();
      AppNavigator.instance.key.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else if (state.event == AuthChangeEvent.signedIn &&
        AuthService.currentUser != null) {
      final id = AuthService.currentUser!.id;
      debugPrint('CONEXO_FCM_ACCOUNT_DIAG auth_user_changed='
          '${id.length >= 8 ? id.substring(id.length - 8) : id}');
      _startAuthenticatedServices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Conexo',
      theme: AppTheme.darkTheme,
      navigatorKey: AppNavigator.instance.key,
      home: const SplashScreen(),
    );
  }
}
