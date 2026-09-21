import 'package:flutter/material.dart';

/// App-wide editorial palette: white canvas, near-black ink, warm neutral
/// surfaces and a single restrained plum accent. Presentation only.
abstract final class AppPalette {
  static const Color canvas = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1B1B1F);
  static const Color inkSoft = Color(0xFF5C5C66);
  static const Color inkMuted = Color(0xFF8A8A94);
  static const Color surface = Color(0xFFF5F4F2);
  static const Color line = Color(0xFFE6E4E1);
  static const Color accent = Color(0xFF6A3FBF);
}

/// Dark mode palette — preserves current Conexo purple/black identity.
abstract final class DarkPalette {
  static const Color scaffold = Color(0xFF0B1020);
  static const Color surface = Color(0xFF151B2E);
  static const Color surfaceElevated = Color(0xFF171F35);
  static const Color border = Color(0xFF29324A);
  static const Color primary = Color(0xFF8B5CF6);
  static const Color primaryLight = Color(0xFF9D82FF);
  static const Color onSurface = Color(0xFFEAEEF9);
  static const Color onSurfaceVariant = Color(0xFFB9C3DC);
  static const Color onSurfaceMuted = Color(0xFFAEB9D6);
  static const Color error = Color(0xFFE36D9D);
}

/// Bundled font families (see pubspec.yaml → fonts).
abstract final class AppFonts {
  /// Serif display face for headlines (light mode).
  static const String display = 'Fraunces';

  /// Clean sans for body copy and UI labels (light mode).
  static const String body = 'Inter';
}

/// Brightness-resolved accessors over the existing [AppPalette] (light) and
/// [DarkPalette] (dark) tokens. Presentation-layer convenience only — this is
/// not a second theme system, it simply picks the correct existing token for
/// the active [Brightness].
extension ConexoThemeColors on BuildContext {
  bool get isLightTheme => Theme.of(this).brightness == Brightness.light;

  /// Deepest page/canvas background.
  Color get cxCanvas => isLightTheme ? AppPalette.canvas : DarkPalette.scaffold;

  /// Elevated surface (cards, tiles, inputs).
  Color get cxSurface =>
      isLightTheme ? AppPalette.surface : DarkPalette.surfaceElevated;

  /// Glass/card surface (slightly deeper than [cxSurface] in dark).
  Color get cxGlass =>
      isLightTheme ? AppPalette.surface : const Color(0xFF182039);

  /// Primary text / primary icon.
  Color get cxInk => isLightTheme ? AppPalette.ink : DarkPalette.onSurface;

  /// Secondary text / secondary icon.
  Color get cxSoft =>
      isLightTheme ? AppPalette.inkSoft : DarkPalette.onSurfaceVariant;

  /// Muted text / muted icon.
  Color get cxMuted =>
      isLightTheme ? AppPalette.inkMuted : DarkPalette.onSurfaceMuted;

  /// Primary accent (light ink / dark violet).
  Color get cxAccent =>
      isLightTheme ? AppPalette.ink : DarkPalette.primary;

  /// Soft accent (light ink / dark light-violet).
  Color get cxAccentSoft =>
      isLightTheme ? AppPalette.ink : const Color(0xFFB7A5FF);

  /// Hairline border / divider.
  Color get cxLine => isLightTheme ? AppPalette.line : DarkPalette.border;

  /// Success / verified.
  Color get cxSuccess =>
      isLightTheme ? const Color(0xFF1F9D6B) : const Color(0xFF47D7A5);

  /// Destructive.
  Color get cxDanger =>
      isLightTheme ? const Color(0xFFD9485F) : DarkPalette.error;
}

class AppTheme {
  /// Light theme: Friend ZIP visual language (white canvas, ink, Fraunces/Inter).
  static final ThemeData lightTheme = _buildLightTheme();

  /// Dark theme: Current Conexo purple/black visual identity (Plus Jakarta Sans).
  static final ThemeData darkTheme = _buildDarkTheme();

  static ThemeData _buildLightTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppFonts.body,
    );

    const ink = AppPalette.ink;
    TextStyle display(double size, {double spacing = -0.5, double? height}) =>
        TextStyle(
          fontFamily: AppFonts.display,
          fontSize: size,
          fontWeight: FontWeight.w500,
          letterSpacing: spacing,
          height: height,
          color: ink,
        );
    TextStyle body(double size, {FontWeight weight = FontWeight.w400, Color color = ink}) =>
        TextStyle(
          fontFamily: AppFonts.body,
          fontSize: size,
          fontWeight: weight,
          color: color,
        );

    final textTheme = TextTheme(
      displayLarge: display(56, spacing: -1.2),
      displayMedium: display(44, spacing: -1),
      displaySmall: display(36, spacing: -0.8),
      headlineLarge: display(32, spacing: -0.7),
      headlineMedium: display(28, spacing: -0.6),
      headlineSmall: display(24, spacing: -0.4),
      titleLarge: body(20, weight: FontWeight.w600),
      titleMedium: body(16, weight: FontWeight.w600),
      titleSmall: body(14, weight: FontWeight.w600),
      bodyLarge: body(16),
      bodyMedium: body(14),
      bodySmall: body(12, color: AppPalette.inkSoft),
      labelLarge: body(14, weight: FontWeight.w600),
      labelMedium: body(12, weight: FontWeight.w500),
      labelSmall: body(11, weight: FontWeight.w500, color: AppPalette.inkMuted),
    );

    final scheme = ColorScheme.fromSeed(
      brightness: Brightness.light,
      seedColor: AppPalette.accent,
      surface: AppPalette.canvas,
    ).copyWith(
      primary: ink,
      onPrimary: Colors.white,
      secondary: AppPalette.accent,
      onSurface: ink,
      onSurfaceVariant: AppPalette.inkSoft,
      outline: AppPalette.line,
      outlineVariant: AppPalette.line,
      surfaceContainerHighest: AppPalette.surface,
      surfaceContainerHigh: AppPalette.surface,
      surfaceContainer: AppPalette.surface,
      surfaceContainerLow: AppPalette.surface,
      surfaceContainerLowest: AppPalette.canvas,
    );

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: c, width: w),
        );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppPalette.canvas,
      canvasColor: AppPalette.canvas,
      cardColor: AppPalette.canvas,
      dividerColor: AppPalette.line,
      hintColor: AppPalette.inkMuted,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: const IconThemeData(color: ink),
      primaryIconTheme: const IconThemeData(color: ink),
      appBarTheme: AppBarTheme(
        backgroundColor: AppPalette.canvas,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: display(24, spacing: -0.4),
        iconTheme: const IconThemeData(color: ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.surface,
        hintStyle: body(14, color: AppPalette.inkMuted),
        labelStyle: body(14, color: AppPalette.inkSoft),
        border: border(AppPalette.line),
        enabledBorder: border(AppPalette.line),
        focusedBorder: border(ink, 1.4),
        errorBorder: border(const Color(0xFFD9485F)),
        focusedErrorBorder: border(const Color(0xFFD9485F), 1.4),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: ink,
        selectionHandleColor: ink,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          textStyle: body(15, weight: FontWeight.w600, color: Colors.white),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: body(15, weight: FontWeight.w600, color: Colors.white),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: ink, width: 1.2),
          textStyle: body(15, weight: FontWeight.w600),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          textStyle: body(14, weight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppPalette.surface,
        selectedColor: ink,
        side: const BorderSide(color: AppPalette.line),
        labelStyle: body(13, weight: FontWeight.w500),
        shape: const StadiumBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.canvas,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: display(24, spacing: -0.4),
        contentTextStyle: body(14, color: AppPalette.inkSoft),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppPalette.canvas,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppPalette.canvas,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: body(14, color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: ink),
      dividerTheme: const DividerThemeData(color: AppPalette.line, thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : AppPalette.inkMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? ink : AppPalette.surface,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? ink : AppPalette.line,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? ink : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: AppPalette.inkMuted, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? ink : AppPalette.inkMuted,
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: ink,
        thumbColor: ink,
        inactiveTrackColor: AppPalette.line,
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
        labelColor: ink,
        unselectedLabelColor: AppPalette.inkMuted,
        indicatorColor: ink,
        dividerColor: AppPalette.line,
      ),
      listTileTheme: const ListTileThemeData(iconColor: ink, textColor: ink),
      popupMenuTheme: PopupMenuThemeData(
        color: AppPalette.canvas,
        surfaceTintColor: Colors.transparent,
        textStyle: body(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppPalette.canvas,
        selectedItemColor: ink,
        unselectedItemColor: AppPalette.inkMuted,
      ),
    );
  }

  static ThemeData _buildDarkTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'PlusJakartaSans',
    );

    const surface = DarkPalette.surface;
    const surfaceElevated = DarkPalette.surfaceElevated;
    const border = DarkPalette.border;
    const primary = DarkPalette.primary;
    const primaryLight = DarkPalette.primaryLight;
    const onSurface = DarkPalette.onSurface;
    const onSurfaceVariant = DarkPalette.onSurfaceVariant;
    const onSurfaceMuted = DarkPalette.onSurfaceMuted;
    const error = DarkPalette.error;

    return base.copyWith(
      scaffoldBackgroundColor: DarkPalette.scaffold,
      canvasColor: DarkPalette.scaffold,
      cardColor: surface,
      dividerColor: border,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: primary,
        surface: surface,
      ).copyWith(
        primary: primary,
        onPrimary: Colors.white,
        secondary: primary,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: border,
        outlineVariant: border,
        surfaceContainerHighest: surfaceElevated,
        surfaceContainerHigh: surfaceElevated,
        surfaceContainer: surfaceElevated,
        surfaceContainerLow: surfaceElevated,
        surfaceContainerLowest: surface,
        error: error,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
      iconTheme: IconThemeData(color: onSurfaceVariant),
      primaryIconTheme: IconThemeData(color: onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        hintStyle: base.textTheme.bodyMedium?.copyWith(color: onSurfaceMuted),
        labelStyle: base.textTheme.bodyMedium?.copyWith(color: onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryLight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: error, width: 1.5),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionHandleColor: primary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          textStyle: base.textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: base.textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: border),
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryLight,
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceElevated,
        selectedColor: primary.withValues(alpha: 0.2),
        side: BorderSide(color: border),
        labelStyle: base.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        shape: const StadiumBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(color: onSurfaceVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(color: onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : onSurfaceMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary.withValues(alpha: 0.4) : border,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : border,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(Colors.white),
        side: BorderSide(color: onSurfaceMuted, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : onSurfaceMuted,
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: primary,
        thumbColor: primary,
        inactiveTrackColor: border,
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
        labelColor: primaryLight,
        unselectedLabelColor: onSurfaceMuted,
        indicatorColor: primary,
        dividerColor: border,
      ),
      listTileTheme: ListTileThemeData(iconColor: onSurfaceVariant, textColor: onSurface),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        textStyle: base.textTheme.bodyMedium?.copyWith(color: onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primaryLight,
        unselectedItemColor: onSurfaceMuted,
      ),
    );
  }
}