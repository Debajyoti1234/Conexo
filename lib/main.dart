import 'package:flutter/material.dart';

import 'app/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ConexoApp());
}

class ConexoApp extends StatelessWidget {
  const ConexoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Conexo',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}