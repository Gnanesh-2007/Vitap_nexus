import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ───────────────────────────────────────────────────────────────────────────
  // Editorial Academic Theme
  // Warm paper surfaces + navy ink + restrained blue/orange/green accents.
  // ───────────────────────────────────────────────────────────────────────────

  static const Color background = Color(0xFFF4F2ED);
  static const Color surface = Color(0xFFFFFEFB);
  static const Color surfaceLight = Color(0xFFF8F7F3);
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  static const Color ink = Color(0xFF17202A);
  static const Color navy = Color(0xFF172B4D);
  static const Color muted = Color(0xFF6E7681);
  static const Color mutedLight = Color(0xFF98A0AA);

  static const Color cardBorder = Color(0xFFE2DED5);
  static const Color cardBorderLight = Color(0xFFEAE7E0);

  static const Color primary = Color(0xFF356AE6);
  static const Color primaryAccent = Color(0xFF356AE6);
  static const Color cyanAccent = Color(0xFF356AE6);

  static const Color emeraldAccent = Color(0xFF278B68);
  static const Color amberAccent = Color(0xFFE47543);
  static const Color roseAccent = Color(0xFFC84C43);
  static const Color purpleAccent = Color(0xFF172B4D);

  static const Color success = Color(0xFF278B68);
  static const Color warning = Color(0xFFE47543);
  static const Color error = Color(0xFFC84C43);

  // Kept for compatibility with existing screens.
  // Both stops intentionally use the same color so old gradient references
  // do not reintroduce the previous neon/gradient visual language.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [surface, surface],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [navy, navy],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [primary, primary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient glassHighlight = LinearGradient(
    colors: [Colors.transparent, Colors.transparent],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static List<BoxShadow> get primaryGlow => [
    BoxShadow(
      color: primary.withValues(alpha: 0.10),
      blurRadius: 10,
      spreadRadius: -2,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: ink.withValues(alpha: 0.08),
      blurRadius: 12,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get cyanGlow => [
    BoxShadow(
      color: primary.withValues(alpha: 0.08),
      blurRadius: 10,
      spreadRadius: -2,
      offset: const Offset(0, 3),
    ),
  ];

  static ThemeData get appTheme {
    final base = ThemeData.light();

    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      canvasColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: navy,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: ink,
        onError: Colors.white,
      ),

      textTheme: GoogleFonts.dmSansTextTheme(
        base.textTheme,
      ).apply(
        bodyColor: ink,
        displayColor: ink,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: ink),
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(
            color: cardBorder,
            width: 1,
          ),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: cardBorder,
        thickness: 1,
        space: 1,
      ),

      iconTheme: const IconThemeData(
        color: ink,
        size: 22,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: cardBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: cardBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: error,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: error,
            width: 1.5,
          ),
        ),
        hintStyle: const TextStyle(
          color: mutedLight,
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          color: muted,
          fontSize: 14,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: cardBorder,
          disabledForegroundColor: mutedLight,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          side: const BorderSide(
            color: cardBorder,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 2,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: cardBorderLight,
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: cardBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return mutedLight;
        }),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return mutedLight;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return cardBorder;
        }),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: navy,
        contentTextStyle: GoogleFonts.dmSans(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        indicatorColor: const Color(0xFFE8EEF9),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary);
          }
          return const IconThemeData(color: muted);
        }),
      ),

      listTileTheme: const ListTileThemeData(
        textColor: ink,
        iconColor: muted,
        tileColor: Colors.transparent,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  // Kept as the existing getter so main.dart does not need to change.
  // Despite the legacy name, it now returns the new light editorial theme.
  static ThemeData get darkTheme => appTheme;

  static ThemeData get lightTheme => appTheme;
}
