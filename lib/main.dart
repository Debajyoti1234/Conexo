import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/theme/app_theme.dart';
import 'core/supabase/auth_service.dart';
import 'core/supabase/supabase_client.dart';
import 'features/login_screen.dart';
import 'features/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseClientConfig.initialize();
  await GoogleSignIn.instance.initialize(
    serverClientId: const String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
    ),
  );

  runApp(const ConexoApp());
}

class ConexoApp extends StatefulWidget {
  const ConexoApp({super.key});

  @override
  State<ConexoApp> createState() => _ConexoAppState();
}

class _ConexoAppState extends State<ConexoApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = AuthService.authStateChanges.listen(_onAuthStateChanged);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _onAuthStateChanged(AuthState state) {
    if (state.event == AuthChangeEvent.signedOut) {
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
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
