import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Conexo design tokens.
///
/// Light ("Day") is the default: a cool lilac-tinted paper with deep aubergine
/// ink. "Night Mode" keeps the original Conexo navy + violet identity.
/// The brand gradient (violet → magenta → cyan, lifted from the C-smile logo)
/// is reserved for signature moments — the Spark arc, primary CTAs, match
/// celebrations — so it always feels special.
@immutable
class ConexoColors extends ThemeExtension<ConexoColors> {
  const ConexoColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkSoft,
    required this.inkMute,
    required this.line,
    required this.violet,
    required this.magenta,
    required this.cyan,
    required this.success,
    required this.danger,
    required this.shadow,
    required this.isNight,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color ink;
  final Color inkSoft;
  final Color inkMute;
  final Color line;
  final Color violet;
  final Color magenta;
  final Color cyan;
  final Color success;
  final Color danger;
  final Color shadow;
  final bool isNight;

  static const day = ConexoColors(
    bg: Color(0xFFF8F6FE),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEFEBFB),
    ink: Color(0xFF1A1433),
    inkSoft: Color(0xFF4A4468),
    inkMute: Color(0xFF8D88A8),
    line: Color(0xFFE4DFF3),
    violet: Color(0xFF7C3AED),
    magenta: Color(0xFFE8459B),
    cyan: Color(0xFF1FB8E0),
    success: Color(0xFF18A874),
    danger: Color(0xFFE5484D),
    shadow: Color(0xFF3B2A7A),
    isNight: false,
  );

  static const night = ConexoColors(
    bg: Color(0xFF0B1020),
    surface: Color(0xFF151B2E),
    surfaceAlt: Color(0xFF1C2440),
    ink: Color(0xFFF3F1FF),
    inkSoft: Color(0xFFB8C1DA),
    inkMute: Color(0xFF7A84A3),
    line: Color(0xFF28324B),
    violet: Color(0xFF9D7BFF),
    magenta: Color(0xFFFF5FAF),
    cyan: Color(0xFF3FD8F5),
    success: Color(0xFF47D7A5),
    danger: Color(0xFFFF6B6B),
    shadow: Color(0xFF000000),
    isNight: true,
  );

  LinearGradient get brand => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, magenta, cyan],
    stops: const [0, .55, 1],
  );

  LinearGradient get warm => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, magenta],
  );

  List<BoxShadow> get softShadow => [
    BoxShadow(
      color: shadow.withValues(alpha: isNight ? .40 : .07),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  @override
  ConexoColors copyWith() => this;

  @override
  ConexoColors lerp(ConexoColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return ConexoColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      ink: l(ink, other.ink),
      inkSoft: l(inkSoft, other.inkSoft),
      inkMute: l(inkMute, other.inkMute),
      line: l(line, other.line),
      violet: l(violet, other.violet),
      magenta: l(magenta, other.magenta),
      cyan: l(cyan, other.cyan),
      success: l(success, other.success),
      danger: l(danger, other.danger),
      shadow: l(shadow, other.shadow),
      isNight: t < .5 ? isNight : other.isNight,
    );
  }
}

extension ConexoContext on BuildContext {
  ConexoColors get cx => Theme.of(this).extension<ConexoColors>()!;
}

/// Type scale. Bricolage Grotesque carries personality in display sizes only;
/// Plus Jakarta Sans (the existing Conexo face) handles everything readable.
abstract final class ConexoType {
  static TextStyle display(Color c, {double size = 40}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        height: 1.02,
        fontWeight: FontWeight.w700,
        letterSpacing: -size * .035,
        color: c,
      );

  static TextStyle title(Color c, {double size = 22}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        height: 1.15,
        fontWeight: FontWeight.w600,
        letterSpacing: -size * .02,
        color: c,
      );

  static TextStyle body(Color c, {double size = 15, FontWeight w = FontWeight.w500}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        height: 1.45,
        fontWeight: w,
        color: c,
      );

  static TextStyle label(Color c, {double size = 12}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: .2,
        color: c,
      );
}

abstract final class ConexoTheme {
  static ThemeData build(ConexoColors c) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: c.isNight ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: c.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.violet,
        brightness: c.isNight ? Brightness.dark : Brightness.light,
        primary: c.violet,
        surface: c.surface,
        error: c.danger,
      ),
      extensions: [c],
      splashFactory: InkSparkle.splashFactory,
    );
    return base.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
        bodyColor: c.ink,
        displayColor: c.ink,
      ),
      iconTheme: IconThemeData(color: c.ink),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        headerBackgroundColor: c.surface,
        headerForegroundColor: c.ink,
        headerHelpStyle: ConexoType.label(c.inkSoft, size: 13),
        headerHeadlineStyle: ConexoType.display(c.ink, size: 32),
        dividerColor: c.line,
        weekdayStyle: ConexoType.label(c.inkMute),
        dayStyle: ConexoType.body(c.ink, size: 14, w: FontWeight.w600),
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : c.ink,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.violet : null,
        ),
        todayForegroundColor: WidgetStatePropertyAll(c.violet),
        todayBorder: BorderSide(color: c.violet),
        yearStyle: ConexoType.body(c.ink, size: 14, w: FontWeight.w600),
        yearForegroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : c.ink,
        ),
        yearBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.violet : null,
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: c.violet,
          textStyle: ConexoType.label(c.violet, size: 15),
        ),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: c.inkSoft,
          textStyle: ConexoType.label(c.inkSoft, size: 15),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : c.inkMute,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.transparent : c.line,
        ),
      ),
      dividerColor: c.line,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.isNight ? c.surfaceAlt : c.ink,
        contentTextStyle: ConexoType.body(
          c.isNight ? c.ink : Colors.white,
          size: 14,
          w: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
