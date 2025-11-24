import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LightModeColors {
  static const primary = Color(0xFF0066FF); // Vibrant bright blue
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFD6E7FF);
  static const onPrimaryContainer = Color(0xFF001A41);

  static const secondary = Color(0xFF5E6B83);
  static const onSecondary = Color(0xFFFFFFFF);
  static const tertiary = Color(0xFF467C8A);
  static const onTertiary = Color(0xFFFFFFFF);

  static const error = Color(0xFFB3261E);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFF9DEDC);
  static const onErrorContainer = Color(0xFF410E0B);

  static const surface = Color(0xFFF9FAFB);
  static const onSurface = Color(0xFF1B1C1E);
  static const surfaceDim = Color(0xFFF3F4F6);
  static const outline = Color(0xFF9AA3B2);
}

class DarkModeColors {
  static const primary = Color(0xFF5C9FFF);
  static const onPrimary = Color(0xFF00174D);
  static const primaryContainer = Color(0xFF0052CC);
  static const onPrimaryContainer = Color(0xFFD6E7FF);

  static const secondary = Color(0xFFB3BCD0);
  static const onSecondary = Color(0xFF232833);
  static const tertiary = Color(0xFFA8D5E0);
  static const onTertiary = Color(0xFF0E2B33);

  static const error = Color(0xFFFFB4A9);
  static const onError = Color(0xFF680003);
  static const errorContainer = Color(0xFF8C1D18);
  static const onErrorContainer = Color(0xFFFFDAD4);

  static const surface = Color(0xFF0E1114);
  static const onSurface = Color(0xFFE6E8EA);
  static const surfaceDim = Color(0xFF14181B);
  static const outline = Color(0xFF6B7486);
}

/// App-wide gradients for emphasis and accents.
class AppGradients {
  static LinearGradient primaryLight = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      LightModeColors.primary,
      Color(0xFF2E86FF),
    ],
  );

  static LinearGradient primaryDark = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      DarkModeColors.primary,
      Color(0xFF6FB2FF),
    ],
  );

  static LinearGradient primaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? primaryDark : primaryLight;
}

class FontSizes {
  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 24.0;
  static const double headlineSmall = 22.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 18.0;
  static const double titleSmall = 16.0;
  static const double labelLarge = 16.0;
  static const double labelMedium = 14.0;
  static const double labelSmall = 12.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
}

ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: LightModeColors.primary,
    onPrimary: LightModeColors.onPrimary,
    primaryContainer: LightModeColors.primaryContainer,
    onPrimaryContainer: LightModeColors.onPrimaryContainer,
    secondary: LightModeColors.secondary,
    onSecondary: LightModeColors.onSecondary,
    tertiary: LightModeColors.tertiary,
    onTertiary: LightModeColors.onTertiary,
    error: LightModeColors.error,
    onError: LightModeColors.onError,
    errorContainer: LightModeColors.errorContainer,
    onErrorContainer: LightModeColors.onErrorContainer,
    surface: LightModeColors.surface,
    onSurface: LightModeColors.onSurface,
    outline: LightModeColors.outline,
    surfaceContainerHighest: LightModeColors.surfaceDim,
  ),
  brightness: Brightness.light,
  scaffoldBackgroundColor: LightModeColors.surface,
  splashFactory: NoSplash.splashFactory,
  highlightColor: Colors.transparent,
  hoverColor: LightModeColors.surfaceDim,
  pageTransitionsTheme: const PageTransitionsTheme(builders: {
    TargetPlatform.android: ZoomPageTransitionsBuilder(),
    TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
    TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
    TargetPlatform.windows: ZoomPageTransitionsBuilder(),
    TargetPlatform.linux: ZoomPageTransitionsBuilder(),
    TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
  }),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: LightModeColors.onSurface,
    elevation: 0,
    centerTitle: true,
  ),
  inputDecorationTheme: InputDecorationTheme(
    fillColor: LightModeColors.surfaceDim,
    filled: true,
    hintStyle: GoogleFonts.inter(color: LightModeColors.onSurface),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0x22000000)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: LightModeColors.primary.withValues(alpha: 0.6), width: 1.4),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: const Color(0x22000000).withValues(alpha: 0.2)),
    ),
  ),
  cardTheme: CardThemeData(
    color: LightModeColors.surface,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    backgroundColor: LightModeColors.surface,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: ButtonStyle(
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textStyle: WidgetStatePropertyAll(
        GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: FontSizes.labelLarge),
      ),
      foregroundColor: const WidgetStatePropertyAll(LightModeColors.onPrimary),
      backgroundColor: const WidgetStatePropertyAll(LightModeColors.primary),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: ButtonStyle(
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(color: LightModeColors.outline.withValues(alpha: states.contains(WidgetState.disabled) ? 0.3 : 0.6)),
      ),
      foregroundColor: const WidgetStatePropertyAll(LightModeColors.onSurface),
      textStyle: WidgetStatePropertyAll(
        GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: FontSizes.labelLarge),
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: const WidgetStatePropertyAll(LightModeColors.primary),
      textStyle: WidgetStatePropertyAll(GoogleFonts.inter(fontWeight: FontWeight.w600)),
    ),
  ),
  listTileTheme: ListTileThemeData(
    iconColor: LightModeColors.primary,
    textColor: LightModeColors.onSurface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    dense: false,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  ),
  textTheme: TextTheme(
    displayLarge: GoogleFonts.inter(fontSize: FontSizes.displayLarge),
    displayMedium: GoogleFonts.inter(fontSize: FontSizes.displayMedium),
    displaySmall: GoogleFonts.inter(fontSize: FontSizes.displaySmall, fontWeight: FontWeight.w600),
    headlineLarge: GoogleFonts.inter(fontSize: FontSizes.headlineLarge),
    headlineMedium: GoogleFonts.inter(fontSize: FontSizes.headlineMedium, fontWeight: FontWeight.w600),
    headlineSmall: GoogleFonts.inter(fontSize: FontSizes.headlineSmall, fontWeight: FontWeight.w700),
    titleLarge: GoogleFonts.inter(fontSize: FontSizes.titleLarge, fontWeight: FontWeight.w600),
    titleMedium: GoogleFonts.inter(fontSize: FontSizes.titleMedium, fontWeight: FontWeight.w600),
    titleSmall: GoogleFonts.inter(fontSize: FontSizes.titleSmall, fontWeight: FontWeight.w600),
    labelLarge: GoogleFonts.inter(fontSize: FontSizes.labelLarge, fontWeight: FontWeight.w700),
    labelMedium: GoogleFonts.inter(fontSize: FontSizes.labelMedium, fontWeight: FontWeight.w600),
    labelSmall: GoogleFonts.inter(fontSize: FontSizes.labelSmall, fontWeight: FontWeight.w600),
    bodyLarge: GoogleFonts.inter(fontSize: FontSizes.bodyLarge),
    bodyMedium: GoogleFonts.inter(fontSize: FontSizes.bodyMedium),
    bodySmall: GoogleFonts.inter(fontSize: FontSizes.bodySmall),
  ),
);

ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.dark(
    primary: DarkModeColors.primary,
    onPrimary: DarkModeColors.onPrimary,
    primaryContainer: DarkModeColors.primaryContainer,
    onPrimaryContainer: DarkModeColors.onPrimaryContainer,
    secondary: DarkModeColors.secondary,
    onSecondary: DarkModeColors.onSecondary,
    tertiary: DarkModeColors.tertiary,
    onTertiary: DarkModeColors.onTertiary,
    error: DarkModeColors.error,
    onError: DarkModeColors.onError,
    errorContainer: DarkModeColors.errorContainer,
    onErrorContainer: DarkModeColors.onErrorContainer,
    surface: DarkModeColors.surface,
    onSurface: DarkModeColors.onSurface,
    outline: DarkModeColors.outline,
    surfaceContainerHighest: DarkModeColors.surfaceDim,
  ),
  brightness: Brightness.dark,
  scaffoldBackgroundColor: DarkModeColors.surface,
  splashFactory: NoSplash.splashFactory,
  highlightColor: Colors.transparent,
  hoverColor: DarkModeColors.surfaceDim,
  pageTransitionsTheme: const PageTransitionsTheme(builders: {
    TargetPlatform.android: ZoomPageTransitionsBuilder(),
    TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
    TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
    TargetPlatform.windows: ZoomPageTransitionsBuilder(),
    TargetPlatform.linux: ZoomPageTransitionsBuilder(),
    TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
  }),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: DarkModeColors.onSurface,
    elevation: 0,
    centerTitle: true,
  ),
  inputDecorationTheme: InputDecorationTheme(
    fillColor: DarkModeColors.surfaceDim,
    filled: true,
    hintStyle: GoogleFonts.inter(color: DarkModeColors.onSurface),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0x22FFFFFF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: DarkModeColors.primary.withValues(alpha: 0.6), width: 1.4),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: const Color(0x22FFFFFF).withValues(alpha: 0.25)),
    ),
  ),
  cardTheme: CardThemeData(
    color: DarkModeColors.surface,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    backgroundColor: DarkModeColors.surface,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: ButtonStyle(
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textStyle: WidgetStatePropertyAll(
        GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: FontSizes.labelLarge),
      ),
      foregroundColor: const WidgetStatePropertyAll(DarkModeColors.onPrimary),
      backgroundColor: const WidgetStatePropertyAll(DarkModeColors.primary),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: ButtonStyle(
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(color: DarkModeColors.outline.withValues(alpha: states.contains(WidgetState.disabled) ? 0.28 : 0.55)),
      ),
      foregroundColor: const WidgetStatePropertyAll(DarkModeColors.onSurface),
      textStyle: WidgetStatePropertyAll(
        GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: FontSizes.labelLarge),
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: const WidgetStatePropertyAll(DarkModeColors.primary),
      textStyle: WidgetStatePropertyAll(GoogleFonts.inter(fontWeight: FontWeight.w600)),
    ),
  ),
  listTileTheme: ListTileThemeData(
    iconColor: DarkModeColors.primary,
    textColor: DarkModeColors.onSurface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    dense: false,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  ),
  textTheme: TextTheme(
    displayLarge: GoogleFonts.inter(fontSize: FontSizes.displayLarge),
    displayMedium: GoogleFonts.inter(fontSize: FontSizes.displayMedium),
    displaySmall: GoogleFonts.inter(fontSize: FontSizes.displaySmall, fontWeight: FontWeight.w600),
    headlineLarge: GoogleFonts.inter(fontSize: FontSizes.headlineLarge),
    headlineMedium: GoogleFonts.inter(fontSize: FontSizes.headlineMedium, fontWeight: FontWeight.w600),
    headlineSmall: GoogleFonts.inter(fontSize: FontSizes.headlineSmall, fontWeight: FontWeight.w700),
    titleLarge: GoogleFonts.inter(fontSize: FontSizes.titleLarge, fontWeight: FontWeight.w600),
    titleMedium: GoogleFonts.inter(fontSize: FontSizes.titleMedium, fontWeight: FontWeight.w600),
    titleSmall: GoogleFonts.inter(fontSize: FontSizes.titleSmall, fontWeight: FontWeight.w600),
    labelLarge: GoogleFonts.inter(fontSize: FontSizes.labelLarge, fontWeight: FontWeight.w700),
    labelMedium: GoogleFonts.inter(fontSize: FontSizes.labelMedium, fontWeight: FontWeight.w600),
    labelSmall: GoogleFonts.inter(fontSize: FontSizes.labelSmall, fontWeight: FontWeight.w600),
    bodyLarge: GoogleFonts.inter(fontSize: FontSizes.bodyLarge),
    bodyMedium: GoogleFonts.inter(fontSize: FontSizes.bodyMedium),
    bodySmall: GoogleFonts.inter(fontSize: FontSizes.bodySmall),
  ),
);
