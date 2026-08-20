import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/theme/app_theme.dart';
import 'core/services/live_location_tracker.dart';
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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
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

  void _setupAuthTracking() {
    if (_authTrackingSetup) return;
    _authTrackingSetup = true;
    _authSubscription = AuthService.authStateChanges.listen(_onAuthStateChanged);
    if (AuthService.currentUser != null) {
      LiveLocationTracker.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    LiveLocationTracker.stop();
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
      LiveLocationTracker.stop();
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else if (state.event == AuthChangeEvent.signedIn &&
        AuthService.currentUser != null) {
      LiveLocationTracker.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Conexo',
      theme: AppTheme.darkTheme,
      navigatorKey: _navigatorKey,
      home: const SplashScreen(),
    );
  }
}
