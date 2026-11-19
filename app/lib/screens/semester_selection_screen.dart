import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/main_nav_screen.dart';
import '../theme/app_theme.dart';

class SemesterSelectionScreen extends ConsumerStatefulWidget {
  final String registrationNumber;
  final String password;
  final List<Map<String, String>> initialSemesters;

  const SemesterSelectionScreen({
    super.key,
    required this.registrationNumber,
    required this.password,
    this.initialSemesters = const [],
  });

  @override
  ConsumerState<SemesterSelectionScreen> createState() =>
      _SemesterSelectionScreenState();
}

class _SemesterSelectionScreenState
    extends ConsumerState<SemesterSelectionScreen> {
  String? _selectedSemesterId;
  String? _selectedSemesterName;
  bool _isSubmitting = false;

  AppPalette get _palette => AppPalette.of(context);
  Color get _background => _palette.paper;
  Color get _surface => _palette.surface;
  Color get _ink => _palette.ink;
  Color get _muted => _palette.inkMuted;
  Color get _line => _palette.line;
  Color get _navy => _palette.navy;

  @override
  void initState() {
    super.initState();
    // Default to the first semester
    final authState = ref.read(authProvider);
    final semesters = widget.initialSemesters.isNotEmpty
        ? widget.initialSemesters
        : authState.availableSemesters;

    if (semesters.isNotEmpty) {
      _selectedSemesterId = semesters.first['id'];
      _selectedSemesterName = semesters.first['name'];
    }
  }

  Future<void> _handleEnterNexus() async {
    if (_selectedSemesterId == null || _selectedSemesterName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a semester to continue',
            style: GoogleFonts.dmSans(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(authProvider.notifier).selectSemesterAndEnter(
            username: widget.registrationNumber,
            password: widget.password,
            semesterId: _selectedSemesterId!,
            semesterName: _selectedSemesterName!,
          );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save semester: ${e.toString()}',
            style: GoogleFonts.dmSans(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final semesters = authState.availableSemesters.isNotEmpty
        ? authState.availableSemesters
        : widget.initialSemesters;

    // If state updated and we had no selection, select the first
    if (_selectedSemesterId == null && semesters.isNotEmpty) {
      _selectedSemesterId = semesters.first['id'];
      _selectedSemesterName = semesters.first['name'];
    }

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _line),
                        ),
                        child: Image.asset(
                          'assets/images/vitap_nexus_logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.school_rounded,
                            size: 20,
                            color: _navy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'VITAP NEXUS',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _line),
                    ),
                    child: IconButton(
                      icon: Icon(
                        isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: isDark ? Colors.amber : _navy,
                        size: 18,
                      ),
                      onPressed: () {
                        ref.read(themeModeProvider.notifier).toggleTheme();
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Header Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _navy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _navy.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      widget.registrationNumber.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Select Academic Semester',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose the active term to immediately load your timetable, attendance, and course marks.',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: _muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Semesters List
            Expanded(
              child: semesters.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: _navy,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Fetching your semesters from VTOP...',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      itemCount: semesters.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final semester = semesters[index];
                        final id = semester['id'] ?? '';
                        final name = semester['name'] ?? id;
                        final isSelected = _selectedSemesterId == id;

                        return InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedSemesterId = id;
                              _selectedSemesterName = name;
                            });
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _navy.withValues(alpha: 0.08)
                                  : _surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? _navy
                                    : _line.withValues(alpha: 0.8),
                                width: isSelected ? 2.0 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Radio Icon
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? _navy : _muted,
                                      width: isSelected ? 6.0 : 1.5,
                                    ),
                                    color: isSelected ? _surface : Colors.transparent,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Text info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.dmSans(
                                          fontSize: 15,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          color: _ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        id,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 12,
                                          color: _muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _navy,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'SELECTED',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: _palette.onNavy,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Bottom CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isSubmitting || semesters.isEmpty
                      ? null
                      : _handleEnterNexus,
                  style: FilledButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: _palette.onNavy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: _palette.onNavy,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Enter Nexus',
                              style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
