import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Editorial, Hinge-inspired visual language for the Plans section only.
///
/// White canvas, near-black ink, warm neutral surfaces, a single restrained
/// plum accent, a serif display face for headlines and a clean sans for UI
/// copy. Presentation only — no behaviour lives here.
abstract final class PlansPalette {
  static const Color canvas = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1B1B1F);
  static const Color inkSoft = Color(0xFF5C5C66);
  static const Color inkMuted = Color(0xFF8A8A94);
  static const Color surface = Color(0xFFF5F4F2);
  static const Color line = Color(0xFFE6E4E1);
  static const Color accent = Color(0xFF6A3FBF);
}

/// Serif display face used for section headlines and plan titles.
TextStyle plansDisplay({
  double fontSize = 28,
  FontWeight fontWeight = FontWeight.w500,
  Color color = PlansPalette.ink,
  double letterSpacing = -0.4,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'Fraunces',
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

/// Clean sans face used for body copy, labels and chips.
TextStyle plansBody({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.w500,
  Color color = PlansPalette.ink,
  double letterSpacing = 0,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'Inter',
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

/// Light theme scoped to the Plans discovery screen so unstyled text and
/// Material defaults render in ink on white instead of the app-wide dark
/// theme. Applied via a local [Theme] widget — pushed routes are unaffected.
ThemeData plansLightTheme(BuildContext context) {
  // Dark mode: use the Conexo dark theme instead of forcing a light canvas.
  if (Theme.of(context).brightness == Brightness.dark) {
    return AppTheme.darkTheme;
  }
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: PlansPalette.canvas,
    colorScheme: ColorScheme.fromSeed(
      brightness: Brightness.light,
      seedColor: PlansPalette.accent,
      surface: PlansPalette.canvas,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'Inter',
      bodyColor: PlansPalette.ink,
      displayColor: PlansPalette.ink,
    ),
    iconTheme: const IconThemeData(color: PlansPalette.ink),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: PlansPalette.ink,
      selectionHandleColor: PlansPalette.ink,
    ),
  );
}
