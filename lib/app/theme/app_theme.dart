import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xff0F1020),

    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xff7B61FF),
    ),

    fontFamily: 'Roboto',
  );
}