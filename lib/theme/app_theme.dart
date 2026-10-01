import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const maroon50 = Color(0xFFFFF5F5);
  static const maroon100 = Color(0xFFFFE3E3);
  static const maroon200 = Color(0xFFFFC6C6);
  static const maroon300 = Color(0xFFFF9999);
  static const maroon400 = Color(0xFFE96868);
  static const maroon500 = Color(0xFFB83A3A);
  static const maroon600 = Color(0xFF991F1F);
  static const maroon700 = Color(0xFF800000);
  static const maroon800 = Color(0xFF650000);
  static const maroon900 = Color(0xFF430000);

  static const gold300 = Color(0xFFFFE98A);
  static const gold500 = Color(0xFFFFCC00);
  static const gold700 = Color(0xFFB38F00);

  static const ink900 = Color(0xFF1B1A1A);
  static const ink700 = Color(0xFF484444);
  static const ink500 = Color(0xFF716B6B);
  static const neutral100 = Color(0xFFF6F3F2);
  static const neutral200 = Color(0xFFE9E4E2);
  static const neutral800 = Color(0xFF2A2727);
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}

class AppRadius {
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const pill = 999.0;
}

class AppShadows {
  static const soft = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];
}

/// Central theme for BORROW LOG.
///
/// Brand palette matches the University of Mindanao seal:
///   Maroon  #800000  – primary
///   Gold    #FFCC00  – accent
///   Pearl   #FAF9F6  – background
///   White            – surfaces
///
/// This file is the single source of truth for styling. Screens should
/// avoid hard-coded colors, radii, or fonts so the look stays consistent.
class AppTheme {
  // ---------------------------------------------------------
  // BRAND COLORS
  // ---------------------------------------------------------

  static const Color maroon = AppColors.maroon700;
  static const Color maroonDark = AppColors.maroon900;
  static const Color gold = AppColors.gold500;
  static const Color goldDark = AppColors.gold700;
  static const Color pearl = Color(0xFFFBF8F7);
  static const Color surface = Colors.white;

  // Status colors (used by StatusChip in Phase 2)
  static const Color statusPending = Color(0xFFF59E0B); // amber
  static const Color statusApproved = Color(0xFF16A34A); // green
  static const Color statusRejected = Color(0xFFDC2626); // red
  static const Color statusBorrowed = Color(0xFF2563EB); // blue
  static const Color statusReturned = Color(0xFF6B7280); // grey
  static const Color statusOverdue = Color(0xFFEA580C); // deep orange

  // ---------------------------------------------------------
  // SPACING SCALE
  // ---------------------------------------------------------

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double spaceXxl = 32;

  // ---------------------------------------------------------
  // RADII
  // ---------------------------------------------------------

  static const double radiusSm = AppRadius.sm;
  static const double radiusMd = AppRadius.md;
  static const double radiusLg = AppRadius.lg;

  // ---------------------------------------------------------
  // LIGHT THEME
  // ---------------------------------------------------------

  static ThemeData lightTheme = _buildLight();
  static ThemeData darkTheme = _buildDark();

  static ThemeData _buildDark() {
    final base = ThemeData.dark(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.maroon500,
      brightness: Brightness.dark,
      primary: AppColors.maroon300,
      onPrimary: AppColors.maroon900,
      secondary: AppColors.gold300,
      onSecondary: AppColors.maroon900,
      surface: AppColors.neutral800,
      onSurface: Colors.white,
      error: const Color(0xFFFFB4AB),
    );
    final textTheme = _buildTextTheme(dark: true);
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF171515),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF201C1C),
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.neutral800,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: _inputTheme(
        fill: AppColors.neutral800,
        border: const Color(0xFF514A4A),
        focused: AppColors.maroon300,
        label: Colors.white70,
      ),
      elevatedButtonTheme: _elevatedButtonTheme(textTheme, AppColors.maroon500),
      outlinedButtonTheme: _outlinedButtonTheme(AppColors.maroon300),
    );
  }

  static ThemeData _buildLight() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: maroon,
      primary: maroon,
      onPrimary: Colors.white,
      secondary: gold,
      onSecondary: maroon,
      surface: surface,
      onSurface: const Color(0xFF1F1F1F),
      error: statusRejected,
      onError: Colors.white,
    );

    final textTheme = _buildTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: pearl,
      textTheme: textTheme,

      // ---------------- AppBar ----------------
      appBarTheme: AppBarTheme(
        backgroundColor: maroon,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
      ),

      // ---------------- Cards ----------------
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // ---------------- Inputs ----------------
      inputDecorationTheme: _inputTheme(
        fill: surface,
        border: AppColors.neutral200,
        focused: maroon,
        label: AppColors.ink700,
      ),

      // ---------------- Buttons ----------------
      elevatedButtonTheme: _elevatedButtonTheme(textTheme, maroon),
      outlinedButtonTheme: _outlinedButtonTheme(maroon),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: maroon,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: spaceMd),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ---------------- Chips ----------------
      chipTheme: ChipThemeData(
        backgroundColor: pearl,
        selectedColor: maroon,
        disabledColor: const Color(0xFFE0E0E0),
        labelStyle: textTheme.labelMedium ?? const TextStyle(fontSize: 13),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: Colors.white,
        ),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: spaceMd,
          vertical: spaceSm,
        ),
      ),

      // ---------------- Dialogs ----------------
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: const Color(0xFF1F1F1F),
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: textTheme.bodyMedium,
      ),

      // ---------------- SnackBars ----------------
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2B2B2B),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        insetPadding: const EdgeInsets.all(spaceLg),
        elevation: 4,
      ),

      // ---------------- NavigationBar (bottom tabs) ----------------
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: gold.withValues(alpha: 0.35),
        elevation: 3,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium ?? const TextStyle(fontSize: 13),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: maroon);
          }
          return const IconThemeData(color: Color(0xFF6B6B6B));
        }),
      ),

      // ---------------- TabBar ----------------
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: gold,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        unselectedLabelStyle: textTheme.titleSmall?.copyWith(
          color: Colors.white70,
        ),
      ),

      // ---------------- Dividers ----------------
      dividerTheme: DividerThemeData(
        color: Colors.black.withValues(alpha: 0.08),
        thickness: 1,
        space: spaceXl,
      ),

      // ---------------- Progress ----------------
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: maroon,
        linearTrackColor: Color(0xFFEDEDED),
      ),

      // ---------------- Page transitions (<300 ms) ----------------
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ---------------------------------------------------------
  // TYPOGRAPHY  (Poppins via google_fonts)
  // ---------------------------------------------------------

  static InputDecorationTheme _inputTheme({
    required Color fill,
    required Color border,
    required Color focused,
    required Color label,
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spaceLg,
        vertical: spaceLg,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: focused, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: statusRejected),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: statusRejected, width: 1.8),
      ),
      labelStyle: TextStyle(color: label),
      floatingLabelStyle: TextStyle(color: focused),
      hintStyle: TextStyle(color: label.withValues(alpha: 0.65)),
      errorStyle: const TextStyle(color: statusRejected),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(
      TextTheme textTheme, Color background) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.neutral200,
        disabledForegroundColor: AppColors.ink500,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: spaceXl),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(Color foreground) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: spaceXl),
        side: BorderSide(color: foreground, width: 1.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme({bool dark = false}) {
    // Base Poppins theme with sensible defaults.
    final base = GoogleFonts.poppinsTextTheme();
    final primary = dark ? Colors.white : AppColors.ink900;
    final body = dark ? const Color(0xFFE8E2E2) : const Color(0xFF2B2727);
    final muted = dark ? const Color(0xFFBDB2B2) : AppColors.ink500;

    return base.copyWith(
      // Display / headline — page titles
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primary,
      ),

      // Headlines — section titles
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primary,
      ),

      // Titles — card headers, list items
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1F1F1F),
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1F1F1F),
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1F1F1F),
      ),

      // Body — regular content (min 14 px)
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        color: body,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        color: body,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 13,
        color: muted,
      ),

      // Labels — buttons, chips, badges
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: muted,
      ),
    );
  }
}