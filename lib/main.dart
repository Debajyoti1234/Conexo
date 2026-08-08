import 'package:flutter/material.dart';

import 'app/theme/app_theme.dart';
import 'core/supabase/supabase_client.dart';
import 'features/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseClientConfig.initialize();

  runApp(const ConexoApp());
}

class ConexoApp extends StatelessWidget {
  const ConexoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Conexo',
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
