import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AppPalette provides unified, responsive color tokens for both
/// Light Editorial and Dark Editorial (Zero-Neon) design systems.
class AppPalette {
  final Color paper;
  final Color surface;
  final Color soft;
  final Color line;
  final Color ink;
  final Color inkSoft;
  final Color inkMuted;
  final Color navy;
  final Color blue;
  final Color green;
  final Color orange;
  final Color red;
  final bool isDark;

  const AppPalette({
    required this.paper,
    required this.surface,
    required this.soft,
    required this.line,
    required this.ink,
    required this.inkSoft,
    required this.inkMuted,
    required this.navy,
    required this.blue,
    required this.green,
    required this.orange,
    required this.red,
    required this.isDark,
  });

  /// Light Editorial Palette (Warm paper + ivory + deep navy ink)
  static const light = AppPalette(
    paper: Color(0xFFF4F2ED),
    surface: Color(0xFFFFFEFB),
    soft: Color(0xFFF0EEE8),
    line: Color(0xFFE2DED5),
    ink: Color(0xFF17202A),
    inkSoft: Color(0xFF56616D),
    inkMuted: Color(0xFF8A929A),
    navy: Color(0xFF172B4D),
    blue: Color(0xFF356AE6),
    green: Color(0xFF278B68),
    orange: Color(0xFFE47543),
    red: Color(0xFFC84C43),
    isDark: false,
  );

  /// Dark Editorial Palette (Deep matte charcoal + slate + zero neon)
  static const dark = AppPalette(
    paper: Color(0xFF111418),
    surface: Color(0xFF1A1F26),
    soft: Color(0xFF222933),
    line: Color(0xFF2D3642),
    ink: Color(0xFFF1F5F9),
    inkSoft: Color(0xFF94A3B8),
    inkMuted: Color(0xFF64748B),
    navy: Color(0xFF93C5FD),
    blue: Color(0xFF3B82F6),
    green: Color(0xFF10B981),
    orange: Color(0xFFD97706),
    red: Color(0xFFEF4444),
    isDark: true,
  );

  /// Returns the current palette based on the active theme brightness
  static AppPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? dark : light;
  }

  // Convenient aliases
  Color get background => paper;
  Color get muted => inkMuted;
  Color get cream => soft;
  Color get success => green;
  Color get warning => orange;
  Color get danger => red;
}

class AppTheme {
  // ───────────────────────────────────────────────────────────────────────────
  // Backward compatibility static color getters (Defaulting to light tokens)
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

  // Clean flat gradients for compatibility
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primary],
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [surface, surface],
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [navy, navy],
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [primary, primary],
  );

  static const LinearGradient glassHighlight = LinearGradient(
    colors: [Colors.transparent, Colors.transparent],
  );

  static List<BoxShadow> get primaryGlow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: ink.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get cyanGlow => primaryGlow;

  // ───────────────────────────────────────────────────────────────────────────
  // LIGHT EDITORIAL THEME DATA
  // ───────────────────────────────────────────────────────────────────────────
  static final ThemeData lightTheme = _buildLightTheme();

  static ThemeData _buildLightTheme() {
    final base = ThemeData.light();
    final p = AppPalette.light;

    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: p.paper,
      primaryColor: p.blue,
      canvasColor: p.paper,
      colorScheme: ColorScheme.light(
        primary: p.blue,
        secondary: p.navy,
        surface: p.surface,
        error: p.red,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: p.ink,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).apply(
        bodyColor: p.ink,
        displayColor: p.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.paper,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: p.ink),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.line, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.line,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(
        color: p.ink,
        size: 22,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.blue, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DARK EDITORIAL THEME DATA (ZERO NEON)
  // ───────────────────────────────────────────────────────────────────────────
  static final ThemeData darkTheme = _buildDarkTheme();

  static ThemeData _buildDarkTheme() {
    final base = ThemeData.dark();
    final p = AppPalette.dark;

    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: p.paper,
      primaryColor: p.blue,
      canvasColor: p.paper,
      colorScheme: ColorScheme.dark(
        primary: p.blue,
        secondary: p.navy,
        surface: p.surface,
        error: p.red,
        onPrimary: Colors.white,
        onSecondary: const Color(0xFF0F172A),
        onSurface: p.ink,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).apply(
        bodyColor: p.ink,
        displayColor: p.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.paper,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: p.ink),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.line, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.line,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(
        color: p.ink,
        size: 22,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.blue, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }

  static ThemeData get appTheme => lightTheme;
}
