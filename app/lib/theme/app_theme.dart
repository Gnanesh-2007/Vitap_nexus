import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Brand Colors (Obsidian Cyberpunk / Sleek Dark Luxe) ──────────────────────
  static const Color background = Color(0xFF07090E);      // Deep space obsidian
  static const Color surface = Color(0xFF0E1424);         // Midnight glass surface
  static const Color surfaceLight = Color(0xFF182238);    // Elevated interactive card
  static const Color surfaceElevated = Color(0xFF1F2D48); // Focused/active element
  static const Color cardBorder = Color(0xFF243452);      // Crisp neon-tinted border
  static const Color cardBorderLight = Color(0x2E818CF8); // Subtle indigo glow border

  // ─── Accents ─────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF6366F1);         // Vibrant Cyber Indigo
  static const Color primaryAccent = Color(0xFF818CF8);   // Luminous Periwinkle
  static const Color cyanAccent = Color(0xFF06B6D4);      // Electric Cyan
  static const Color emeraldAccent = Color(0xFF10B981);   // Neon Mint
  static const Color amberAccent = Color(0xFFF59E0B);     // Sunset Gold
  static const Color roseAccent = Color(0xFFF43F5E);      // Radiant Rose
  static const Color purpleAccent = Color(0xFFA855F7);    // Cyber Violet
  
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // ─── Gradients ───────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF121A2D), Color(0xFF0B101C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF241C5A), Color(0xFF0C1322)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF818CF8), Color(0xFF22D3EE)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient glassHighlight = LinearGradient(
    colors: [Color(0x33FFFFFF), Color(0x05FFFFFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Shadows ─────────────────────────────────────────────────────────────────
  static List<BoxShadow> get primaryGlow => [
    BoxShadow(
      color: primary.withValues(alpha: 0.35),
      blurRadius: 20,
      spreadRadius: -2,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.45),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get cyanGlow => [
    BoxShadow(
      color: cyanAccent.withValues(alpha: 0.3),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  // ─── Theme Data ──────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: cyanAccent,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSurface: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        hintStyle: const TextStyle(color: Color(0xFF64748B)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
