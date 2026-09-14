import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/vtop_providers.dart';
import '../theme/app_theme.dart';
import '../utils/vtop_helpers.dart';
import '../widgets/mesh_ambient_background.dart';
import 'grades_screen.dart';
import 'outings_screen.dart';
import 'mentor_screen.dart';
import 'biometric_screen.dart';
import 'payments_screen.dart';
import 'courses_screen.dart';
import 'assignments_screen.dart';
import 'vtop_webview_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final Function(int)? onNavigateTab;

  const DashboardScreen({super.key, this.onNavigateTab});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isNextClassesExpanded = false;

  // ─────────────────────────────────────────────
  // Professional minimalist dashboard palette
  // ─────────────────────────────────────────────
  static const Color _background = Color(0xFF0F1117);
  static const Color _surface = Color(0xFF171B24);
  static const Color _surfaceLight = Color(0xFF1C202A);
  static const Color _border = Color(0xFF2A2F3A);

  static const Color _accent = Color(0xFF8B8FD8);
  static const Color _accentSoft = Color(0xFFB7B9E8);

  static const Color _textPrimary = Color(0xFFF4F4F5);
  static const Color _textSecondary = Color(0xFF9CA3AF);
  static const Color _textMuted = Color(0xFF687080);

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  // Quick access items (Excludes Attendance, Timetable, Marks which are in bottom nav)
  static final _quickAccessItems = [
    _QuickItem(label: 'Grades & CGPA', icon: Icons.emoji_events_rounded, color: _accent, action: 'grades'),
    _QuickItem(label: 'Outings', icon: Icons.directions_walk_rounded, color: _accent, action: 'outings'),
    _QuickItem(label: 'Mentor Details', icon: Icons.supervisor_account_rounded, color: _accent, action: 'mentor'),
    _QuickItem(label: 'Biometric Logs', icon: Icons.fingerprint_rounded, color: _accent, action: 'biometric'),
    _QuickItem(label: 'Payments & Dues', icon: Icons.account_balance_wallet_rounded, color: _accent, action: 'payments'),
    _QuickItem(label: 'Courses Page', icon: Icons.menu_book_rounded, color: _accent, action: 'courses'),
    _QuickItem(label: 'Assignments', icon: Icons.assignment_rounded, color: _accent, action: 'assignments'),
    _QuickItem(label: 'Direct VTOP', icon: Icons.open_in_browser_rounded, color: _accent, action: 'direct_vtop'),
  ];

  Future<void> _handleQuickTap(_QuickItem item, Map<String, dynamic> data, AuthState authState) async {
    if (!mounted) return;

    Widget targetScreen;
    switch (item.action) {
      case 'grades':
        targetScreen = GradesScreen(initialData: data['grade_history'] as Map<String, dynamic>?);
        break;
      case 'outings':
        targetScreen = const OutingsScreen();
        break;
      case 'mentor':
        targetScreen = const MentorScreen();
        break;
      case 'biometric':
        targetScreen = const BiometricScreen();
        break;
      case 'payments':
        targetScreen = const PaymentsScreen();
        break;
      case 'courses':
        targetScreen = const CoursesScreen();
        break;
      case 'assignments':
        targetScreen = const AssignmentsScreen();
        break;
      case 'direct_vtop':
        targetScreen = const VtopWebViewScreen();
        break;
      default:
        return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => targetScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final allDataAsync = ref.watch(allDataProvider);

    return Scaffold(
      backgroundColor: _background,
      body: MeshAmbientBackground(
        child: SafeArea(
          child: allDataAsync.when(
            data: (data) {
              final profile = data['profile'] as Map<String, dynamic>? ?? {};
              final studentName = profile['student_name'] ?? authState.username ?? 'Student';
              final timetable = (data['timetable'] as Map<String, dynamic>?) ?? {};

              // Today's classes sorted chronologically
              final today = DateFormat('EEEE').format(DateTime.now());
              final rawTodayClasses = (timetable[today] as List<dynamic>?) ?? [];
              final todayClasses = VtopHelpers.sortTimetableList(rawTodayClasses);

              final classStatus = VtopHelpers.getLiveClassStatus(todayClasses);
              final activeClass = classStatus['activeClass'] as Map<String, dynamic>?;
              final nextClasses = classStatus['nextClasses'] as List<dynamic>? ?? [];

              return RefreshIndicator(
                onRefresh: () async => ref.refresh(allDataProvider.future),
                color: _accent,
                backgroundColor: _surface,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  children: [
                    // ─── Header ────────────────────────────────────────────────
                    _buildHeader(authState, studentName)
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: -0.12, end: 0, curve: Curves.easeOutCubic),
                    const SizedBox(height: 18),

                    // ─── Active Class / Free Banner ────────────────────────────
                    if (activeClass != null)
                      _buildActiveClassCard(activeClass)
                          .animate()
                          .fadeIn(duration: 450.ms, delay: 80.ms)
                          .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic)
                    else
                      _buildNoActiveClassCard(nextClasses)
                          .animate()
                          .fadeIn(duration: 450.ms, delay: 80.ms)
                          .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
                    const SizedBox(height: 14),

                    // ─── Upcoming Classes Dropdown ─────────────────────────────
                    if (nextClasses.isNotEmpty) ...[
                      _buildNextClassesDropdown(nextClasses)
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 120.ms),
                      const SizedBox(height: 16),
                    ],

                    // ─── Quick Access Grid ──────────────────────────────────────
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.grid_view_rounded, color: _accent, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Quick Access',
                          style: GoogleFonts.manrope(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 400.ms, delay: 140.ms),
                    const SizedBox(height: 12),

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _quickAccessItems.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.85,
                      ),
                      itemBuilder: (context, index) {
                        final item = _quickAccessItems[index];
                        return _buildQuickAccessTile(item, data, authState, index);
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
            loading: () => _buildSkeletonLoading(),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                    const SizedBox(height: 16),
                    Text('Failed to load dashboard',
                        style: GoogleFonts.manrope(fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(err.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref.refresh(allDataProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Shimmer Skeleton Loading ─────────────────────────────────────────────
  Widget _buildSkeletonLoading() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _surface,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 70, height: 10, decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 6),
                    Container(width: 130, height: 16, decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(6))),
                  ],
                ),
              ],
            ),
            Container(width: 80, height: 26, decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(8))),
          ],
        ),
        const SizedBox(height: 22),
        Container(
          height: 105,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
        ),
        const SizedBox(height: 24),
        Container(width: 110, height: 16, decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(6))),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 8,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, index) => Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
          ),
        ),
      ],
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08));
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(AuthState authState, String studentName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _accent.withValues(alpha: 0.95),
                    _accentSoft.withValues(alpha: 0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.12),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _surface,
                ),
                child: Image.asset(
                  'assets/images/konoha_logo.png',
                  width: 24,
                  height: 24,
                  color: _accentSoft,
                  colorBlendMode: BlendMode.srcIn,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.school_rounded,
                    color: _accentSoft,
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  studentName.split(' ').first,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (authState.availableSemesters.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: authState.activeSemesterId,
                dropdownColor: _surfaceLight,
                icon: const Icon(Icons.arrow_drop_down, color: _accent, size: 18),
                style: GoogleFonts.manrope(
                    fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w600),
                items: authState.availableSemesters.map((sem) {
                  return DropdownMenuItem<String>(
                    value: sem['id'],
                    child: Text(sem['name'] ?? sem['id'] ?? ''),
                  );
                }).toList(),
                onChanged: (newSemId) {
                  if (newSemId != null) {
                    final match = authState.availableSemesters.firstWhere((s) => s['id'] == newSemId);
                    ref.read(authProvider.notifier).changeSemester(newSemId, match['name'] ?? newSemId);
                    ref.invalidate(allDataProvider);
                  }
                },
              ),
            ),
          ),
      ],
    );
  }

  // ─── Quick Access Tile ────────────────────────────────────────────────────
  Widget _buildQuickAccessTile(_QuickItem item, Map<String, dynamic> data, AuthState authState, int index) {
    return GestureDetector(
      onTap: () => _handleQuickTap(item, data, authState),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Subtle top glass reflection highlight
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1.5,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        item.color.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _accent.withValues(alpha: 0.12),
                            blurRadius: 10,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Icon(item.icon, color: _accentSoft, size: 22),
                    ),
                    const SizedBox(height: 7),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        item.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: (40 * index).ms)
        .fadeIn(duration: 350.ms)
        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), curve: Curves.easeOutCubic);
  }

  // ─── Active Ongoing Class Card ────────────────────────────────────────────
  Widget _buildActiveClassCard(Map<String, dynamic> item) {
    final isLab = VtopHelpers.isLabCourse(
      courseType: item['course_type']?.toString(),
      courseSlot: item['slot']?.toString(),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _surfaceLight,
            _surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _accent.withValues(alpha: 0.70),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _accentSoft,
                        boxShadow: [
                          BoxShadow(
                            color: _accentSoft,
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.3, 1.3), duration: 800.ms),
                    const SizedBox(width: 7),
                    Text(
                      'LIVE NOW',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _accentSoft,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item['slot'] ?? '',
                        style: GoogleFonts.manrope(
                            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item['course_name'] ?? 'Class in Session',
                  style: GoogleFonts.manrope(
                      fontSize: 16.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 13, color: _accentSoft),
                    const SizedBox(width: 4),
                    Text(item['time'] ?? '',
                        style: GoogleFonts.manrope(fontSize: 11.5, color: Colors.white70)),
                    const SizedBox(width: 12),
                    Icon(Icons.room_rounded, size: 13, color: _accentSoft),
                    const SizedBox(width: 4),
                    Text(item['venue'] ?? 'TBA',
                        style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: _accentSoft)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Text(
              isLab ? 'LAB' : 'THEORY',
              style: GoogleFonts.manrope(
                  fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  // ─── No Active Class Banner ───────────────────────────────────────────────
  Widget _buildNoActiveClassCard(List<dynamic> nextClasses) {
    final nextClass = nextClasses.isNotEmpty ? nextClasses.first : null;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/images/naruto_running.gif',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.coffee_rounded, color: _accentSoft, size: 26),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'FREE TIME',
                      style: GoogleFonts.manrope(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: _accent,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  nextClass != null ? 'No Class Right Now' : 'All Classes Done! 🎉',
                  style: GoogleFonts.manrope(
                      fontSize: 15.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                if (nextClass != null) ...[
                  Text(
                    'Next: ${nextClass['course_name'] ?? 'Class'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                        fontSize: 12, fontWeight: FontWeight.w600, color: _accentSoft),
                  ),
                  Text(
                    'Starts at ${nextClass['time']?.toString().split('-').first.trim() ?? ''} • ${nextClass['venue'] ?? ''}',
                    style: GoogleFonts.manrope(fontSize: 11, color: _textSecondary),
                  ),
                ] else
                  Text('Enjoy your evening & stay ahead!',
                      style: GoogleFonts.manrope(fontSize: 11.5, color: _textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Upcoming Classes Dropdown ────────────────────────────────────────────
  Widget _buildNextClassesDropdown(List<dynamic> nextClasses) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isNextClassesExpanded = !_isNextClassesExpanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.playlist_play_rounded, color: _accent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Upcoming Classes Today',
                    style: GoogleFonts.manrope(
                        fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${nextClasses.length}',
                        style: GoogleFonts.manrope(
                            fontSize: 11, fontWeight: FontWeight.bold, color: _accentSoft)),
                  ),
                  const Spacer(),
                  Icon(
                    _isNextClassesExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: _textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_isNextClassesExpanded) ...[
            const Divider(color: Color(0xFF24344D), height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(10),
              itemCount: nextClasses.length,
              separatorBuilder: (context, index) => const SizedBox(height: 7),
              itemBuilder: (context, index) {
                final item = nextClasses[index];
                final isLab = VtopHelpers.isLabCourse(
                  courseType: item['course_type']?.toString(),
                  courseSlot: item['slot']?.toString(),
                );
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isLab
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : _accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(item['slot'] ?? '',
                            style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _accentSoft)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['course_name'] ?? 'Class',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                    fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                            Text(
                                '${item['time'] ?? ''} • ${item['venue'] ?? 'TBA'}',
                                style: GoogleFonts.manrope(
                                    fontSize: 11, color: _textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Quick Access Item Model ──────────────────────────────────────────────────
class _QuickItem {
  final String label;
  final IconData icon;
  final Color color;
  final String? action;

  const _QuickItem({
    required this.label,
    required this.icon,
    required this.color,
    this.action,
  });
}
