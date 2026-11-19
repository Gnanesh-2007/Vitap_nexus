import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// All 7 Material 3 dynamic seed themes matching the reference app:
/// Blue, Sakura, Forest, Lemonade, Vapour Wave, Nightfall, Cocoa.
enum NexusSeedTheme {
  blue('Blue', Colors.blue),
  sakura('Sakura', Color.fromARGB(255, 252, 180, 241)),
  forest('Forest', Color(0xFFB2C5B3)),
  lime('Lemonade', Color.fromARGB(255, 251, 236, 106)),
  vapourWave('Vapour Wave', Color(0xFF1fc3ff)),
  nightfall('Nightfall', Color(0xFF0262A5)),
  cocoa('Cocoa', Color.fromARGB(255, 255, 202, 184));

  const NexusSeedTheme(this.displayName, this.seedColor);

  final String displayName;
  final Color seedColor;

  static NexusSeedTheme fromName(String? name) {
    if (name == null) return NexusSeedTheme.blue;
    return NexusSeedTheme.values.firstWhere(
      (theme) => theme.name == name,
      orElse: () => NexusSeedTheme.blue,
    );
  }
}

/// Circular 3-quadrant Material 3 theme preview indicator (matches reference app's CircularThemeIndicator)
class CircularThemeIndicator extends StatelessWidget {
  final NexusSeedTheme theme;
  final bool isDarkMode;
  final bool isSelected;
  final VoidCallback onTap;

  const CircularThemeIndicator({
    super.key,
    required this.theme,
    required this.isDarkMode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: theme.seedColor,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      brightness: isDarkMode ? Brightness.dark : Brightness.light,
    );

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 3,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
                child: ClipOval(
                  child: Column(
                    children: [
                      // Top half - PrimaryContainer color
                      Expanded(
                        child: Container(
                          color: colorScheme.primaryContainer,
                        ),
                      ),
                      // Bottom half split vertically
                      Expanded(
                        child: Row(
                          children: [
                            // Bottom left - SurfaceContainer color
                            Expanded(
                              child: Container(
                                color: colorScheme.surfaceContainer,
                              ),
                            ),
                            // Bottom right - Primary color
                            Expanded(
                              child: Container(
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            theme.displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// AppPalette provides unified, responsive color tokens that dynamically adapt
/// to the active Material 3 seed theme, Dark Mode, and AMOLED Mode.
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

  /// Default Light Palette
  static const light = AppPalette(
    paper: Color(0xFFF8F9FC),
    surface: Color(0xFFFFFFFF),
    soft: Color(0xFFEEF1F7),
    line: Color(0xFFE0E5EE),
    ink: Color(0xFF17202A),
    inkSoft: Color(0xFF47525E),
    inkMuted: Color(0xFF68737E),
    navy: Color(0xFF1E56A0),
    blue: Color(0xFF2563EB),
    green: Color(0xFF278B68),
    orange: Color(0xFFE47543),
    red: Color(0xFFC84C43),
    isDark: false,
  );

  /// Default Dark Palette
  static const dark = AppPalette(
    paper: Color(0xFF0E131B),
    surface: Color(0xFF171E29),
    soft: Color(0xFF202938),
    line: Color(0xFF2A3649),
    ink: Color(0xFFF8FAFC),
    inkSoft: Color(0xFFB4C3D6),
    inkMuted: Color(0xFF8496AE),
    navy: Color(0xFF93C5FD),
    blue: Color(0xFF60A5FA),
    green: Color(0xFF10B981),
    orange: Color(0xFFFB923C),
    red: Color(0xFFEF4444),
    isDark: true,
  );

  /// Dynamically derives the palette from the active Theme's ColorScheme and AMOLED mode
  static AppPalette of(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isAmoled = isDark && theme.scaffoldBackgroundColor == Colors.black;
    return AppPalette(
      paper: isAmoled ? Colors.black : cs.surface,
      surface: isAmoled
          ? const Color(0xFF121212)
          : (isDark ? cs.surfaceContainer : cs.surfaceContainerLow),
      soft: isAmoled ? const Color(0xFF1C1C1E) : cs.surfaceContainerHigh,
      line: cs.outlineVariant.withValues(alpha: isDark ? 0.45 : 0.65),
      ink: cs.onSurface,
      inkSoft: cs.onSurfaceVariant,
      inkMuted: cs.outline,
      navy: cs.primary,
      blue: cs.primary,
      green: isDark ? const Color(0xFF10B981) : const Color(0xFF278B68),
      orange: isDark ? const Color(0xFFFB923C) : const Color(0xFFE47543),
      red: cs.error,
      isDark: isDark,
    );
  }

  // Convenient aliases
  Color get background => paper;
  Color get muted => inkMuted;
  Color get cream => soft;
  Color get success => green;
  Color get warning => orange;
  Color get danger => red;
  Color get info => blue;
  Color get onNavy => isDark ? const Color(0xFF0F172A) : Colors.white;
  Color get heroBg => isDark ? surface : navy;
  Color get buttonBg => blue;

  // Surface Hierarchy
  Color get surfaceSubtle => soft;
  Color get surfaceElevated => surface;

  // Academic status colors
  Color get attendanceSafe => green;
  Color get attendanceWarning => orange;
  Color get attendanceCritical => red;

  Color attendanceColor(double percentage) {
    if (percentage >= 85.0) return green;
    if (percentage >= 75.0) return blue;
    if (percentage >= 65.0) return orange;
    return red;
  }

  // Shadows
  List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];

  // Motion Presets
  static const Duration fastDuration = Duration(milliseconds: 140);
  static const Duration normalDuration = Duration(milliseconds: 220);
  static const Duration smoothDuration = Duration(milliseconds: 360);
  static const Curve springCurve = Curves.easeOutCubic;
  static const Curve bounceCurve = Curves.elasticOut;
}

class AppTheme {
  // ───────────────────────────────────────────────────────────────────────────
  // Backward compatibility static color getters
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

  /// Bricolage Grotesque for headings, DM Sans for everything you read.
  static TextTheme _nexusTextTheme(TextTheme base, Color color) {
    final body = GoogleFonts.dmSansTextTheme(base).apply(bodyColor: color, displayColor: color);
    TextStyle? head(TextStyle? s) => GoogleFonts.bricolageGrotesque(textStyle: s, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: color);
    return body.copyWith(
      displayLarge: head(body.displayLarge),
      displayMedium: head(body.displayMedium),
      displaySmall: head(body.displaySmall),
      headlineLarge: head(body.headlineLarge),
      headlineMedium: head(body.headlineMedium),
      headlineSmall: head(body.headlineSmall),
      titleLarge: head(body.titleLarge),
    );
  }

  /// Builds a complete Material 3 ThemeData from a [NexusSeedTheme], [isDarkMode], and [isAmoled]
  static ThemeData getThemeData({
    required NexusSeedTheme seedTheme,
    required bool isDarkMode,
    bool isAmoled = false,
  }) {
    final brightness = isDarkMode ? Brightness.dark : Brightness.light;
    final cs = ColorScheme.fromSeed(
      seedColor: seedTheme.seedColor,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      brightness: brightness,
    );

    final base = isDarkMode ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
    final scaffoldBg = (isDarkMode && isAmoled) ? Colors.black : cs.surface;
    final cardBg = (isDarkMode && isAmoled)
        ? const Color(0xFF121212)
        : (isDarkMode ? cs.surfaceContainer : cs.surfaceContainerLow);

    return base.copyWith(
      brightness: brightness,
      colorScheme: cs,
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: scaffoldBg,
      primaryColor: cs.primary,
      textTheme: _nexusTextTheme(base.textTheme, cs.onSurface),
      appBarTheme: AppBarTheme(
        titleTextStyle: GoogleFonts.bricolageGrotesque(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: cs.onSurface,
          letterSpacing: -0.5,
        ),
        backgroundColor: scaffoldBg,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: cs.onSurface),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: isDarkMode ? 0.35 : 0.5),
            width: 1,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withValues(alpha: isDarkMode ? 0.45 : 0.65),
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(
        color: cs.onSurface,
        size: 22,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: cardBg,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
      ),
    );
  }

  static final ThemeData lightTheme = getThemeData(
    seedTheme: NexusSeedTheme.blue,
    isDarkMode: false,
  );

  static final ThemeData darkTheme = getThemeData(
    seedTheme: NexusSeedTheme.blue,
    isDarkMode: true,
  );

  static ThemeData get appTheme => lightTheme;
}
