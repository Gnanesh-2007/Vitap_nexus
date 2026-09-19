import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/vtop_providers.dart';
import '../utils/vtop_helpers.dart';
import '../widgets/last_synced_badge.dart';
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
  // Deep Cyberpunk Luxury Theme Palette
  // ─────────────────────────────────────────────
  static const Color _background = Color(0xFF090A0F);
  static const Color _cardBg = Color(0xFF12151E);
  static const Color _cardBgLight = Color(0xFF1A1E2B);
  static const Color _cardBorder = Color(0xFF262B3A);

  static const Color _accentPrimary = Color(0xFF6366F1); // Vivid Indigo
  static const Color _accentSecondary = Color(0xFFA855F7); // Neon Purple
  static const Color _accentCyan = Color(0xFF06B6D4); // Bright Cyan

  static const Color _textPrimary = Color(0xFFF8FAFC);
  static const Color _textSecondary = Color(0xFF94A3B8);
  static const Color _textMuted = Color(0xFF64748B);

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 🌅';
    if (hour < 17) return 'Good Afternoon ☀️';
    return 'Good Evening 🌙';
  }

  static final _quickAccessItems = [
    _QuickItem(label: 'Grades & CGPA', icon: Icons.emoji_events_rounded, gradient: [_accentPrimary, _accentSecondary], action: 'grades'),
    _QuickItem(label: 'Outings', icon: Icons.directions_walk_rounded, gradient: [Color(0xFF3B82F6), Color(0xFF1D4ED8)], action: 'outings'),
    _QuickItem(label: 'Mentor Details', icon: Icons.supervisor_account_rounded, gradient: [Color(0xFF10B981), Color(0xFF047857)], action: 'mentor'),
    _QuickItem(label: 'Biometric Logs', icon: Icons.fingerprint_rounded, gradient: [Color(0xFFF59E0B), Color(0xFFD97706)], action: 'biometric'),
    _QuickItem(label: 'Payments & Dues', icon: Icons.account_balance_wallet_rounded, gradient: [Color(0xFFEC4899), Color(0xFFBE185D)], action: 'payments'),
    _QuickItem(label: 'Courses Page', icon: Icons.menu_book_rounded, gradient: [_accentCyan, Color(0xFF0284C7)], action: 'courses'),
    _QuickItem(label: 'Assignments', icon: Icons.assignment_rounded, gradient: [Color(0xFF8B5CF6), Color(0xFF6D28D9)], action: 'assignments'),
    _QuickItem(label: 'Direct VTOP', icon: Icons.open_in_browser_rounded, gradient: [Color(0xFF64748B), Color(0xFF334155)], action: 'direct_vtop'),
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
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final dashboardState = ref.watch(dashboardProvider);

    if (!dashboardState.hasData && dashboardState.isLoading) {
      return Scaffold(
        backgroundColor: _background,
        body: MeshAmbientBackground(
          child: SafeArea(child: _buildShimmerSkeleton()),
        ),
      );
    }

    if (!dashboardState.hasData && dashboardState.error != null) {
      return Scaffold(
        backgroundColor: _background,
        body: MeshAmbientBackground(
          child: SafeArea(
            child: _buildErrorState(dashboardState.error!),
          ),
        ),
      );
    }

    final data = dashboardState.data ?? {};
    final profile = data['profile'] as Map<String, dynamic>? ?? {};
    final studentName = profile['student_name'] ?? authState.username ?? 'Student';
    final timetable = (data['timetable'] as Map<String, dynamic>?) ?? {};

    final today = DateFormat('EEEE').format(DateTime.now());
    final rawTodayClasses = (timetable[today] as List<dynamic>?) ?? [];
    final todayClasses = VtopHelpers.sortTimetableList(rawTodayClasses);

    final classStatus = VtopHelpers.getLiveClassStatus(todayClasses);
    final activeClass = classStatus['activeClass'] as Map<String, dynamic>?;
    final nextClasses = classStatus['nextClasses'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: _background,
      body: MeshAmbientBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => ref.read(dashboardProvider.notifier).refresh(),
            color: _accentPrimary,
            backgroundColor: _cardBg,
            child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    // ─── Header Section ──────────────────────────────────────────────
                    _buildTopHeader(authState, studentName)
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: -0.1, end: 0, curve: Curves.easeOutCubic),
                    LastSyncedBadge(
                      lastSynced: dashboardState.lastSynced,
                      isRefreshing: dashboardState.isSyncing,
                      onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
                      padding: const EdgeInsets.only(top: 6, bottom: 8),
                    ),
                    const SizedBox(height: 12),

                    // ─── Live Class Status Card ──────────────────────────────────────
                    if (activeClass != null)
                      _buildLiveClassCard(activeClass)
                          .animate()
                          .fadeIn(duration: 450.ms, delay: 60.ms)
                          .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic)
                    else
                      _buildFreeStateCard(nextClasses)
                          .animate()
                          .fadeIn(duration: 450.ms, delay: 60.ms)
                          .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
                    const SizedBox(height: 16),

                    // ─── Upcoming Classes Expandable ──────────────────────────────────
                    if (nextClasses.isNotEmpty) ...[
                      _buildUpcomingClassesAccordion(nextClasses)
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 100.ms),
                      const SizedBox(height: 22),
                    ],

                    // ─── Section Header ───────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              decoration: BoxDecoration(
                                color: _accentPrimary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Quick Actions',
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _textPrimary,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${_quickAccessItems.length} Apps',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _textMuted,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 400.ms, delay: 120.ms),
                    const SizedBox(height: 14),

                    // ─── Quick Access Grid ─────────────────────────────────────────────
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _quickAccessItems.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                      itemBuilder: (context, index) {
                        final item = _quickAccessItems[index];
                        return _buildQuickAccessCard(item, data, authState, index);
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
  }

  // ─── Header Bar (Fixed Overflow Issue) ──────────────────────────────────────
  Widget _buildTopHeader(AuthState authState, String studentName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_accentPrimary, _accentSecondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _accentPrimary.withOpacity(0.35),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _cardBg,
                  ),
                  child: Image.asset(
                    'assets/images/konoha_logo.png',
                    width: 26,
                    height: 26,
                    color: Colors.white,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: _textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      studentName.split(' ').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (authState.availableSemesters.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxWidth: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: authState.activeSemesterId,
                isExpanded: true,
                dropdownColor: _cardBgLight,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _accentPrimary, size: 20),
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  color: _textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                items: authState.availableSemesters.map((sem) {
                  return DropdownMenuItem<String>(
                    value: sem['id'],
                    child: Text(
                      sem['name'] ?? sem['id'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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

  // ─── Live Ongoing Class Card ──────────────────────────────────────────────
  Widget _buildLiveClassCard(Map<String, dynamic> item) {
    final isLab = VtopHelpers.isLabCourse(
      courseType: item['course_type']?.toString(),
      courseSlot: item['slot']?.toString(),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            _accentPrimary.withOpacity(0.18),
            _cardBg,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _accentPrimary.withOpacity(0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _accentPrimary.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF10B981),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF10B981),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.4, 1.4), duration: 800.ms),
                      const SizedBox(width: 8),
                      Text(
                        'ONGOING CLASS',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF10B981),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLab
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : _accentPrimary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isLab ? const Color(0xFF10B981) : _accentPrimary,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      isLab ? 'LAB' : 'THEORY',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isLab ? const Color(0xFF10B981) : _accentPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item['course_name'] ?? 'Class in Session',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _cardBgLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item['slot'] ?? 'Slot N/A',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.schedule_rounded, size: 14, color: _textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    item['time'] ?? '',
                    style: GoogleFonts.manrope(fontSize: 12, color: _textSecondary),
                  ),
                  const Spacer(),
                  const Icon(Icons.location_on_rounded, size: 14, color: _accentCyan),
                  const SizedBox(width: 4),
                  Text(
                    item['venue'] ?? 'TBA',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _accentCyan,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Free Schedule State Card ─────────────────────────────────────────────
  Widget _buildFreeStateCard(List<dynamic> nextClasses) {
    final nextClass = nextClasses.isNotEmpty ? nextClasses.first : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _cardBgLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cardBorder),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/naruto_running.gif',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.coffee_rounded, color: _accentPrimary, size: 28),
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
                      'STATUS: FREE',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF10B981),
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  nextClass != null ? 'No Live Class Right Now' : 'Done For Today! 🎉',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                if (nextClass != null) ...[
                  Text(
                    'Next: ${nextClass['course_name'] ?? 'Class'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _accentPrimary,
                    ),
                  ),
                  Text(
                    '${nextClass['time']?.toString().split('-').first.trim() ?? ''} • ${nextClass['venue'] ?? ''}',
                    style: GoogleFonts.manrope(fontSize: 11, color: _textMuted),
                  ),
                ] else
                  Text(
                    'Relax or catch up on your assignments.',
                    style: GoogleFonts.manrope(fontSize: 11.5, color: _textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Expandable Upcoming List ──────────────────────────────────────────────
  Widget _buildUpcomingClassesAccordion(List<dynamic> nextClasses) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isNextClassesExpanded = !_isNextClassesExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.event_note_rounded, color: _accentPrimary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Remaining Schedule',
                    style: GoogleFonts.manrope(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _accentPrimary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${nextClasses.length}',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _accentPrimary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isNextClassesExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: _textSecondary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          if (_isNextClassesExpanded) ...[
            const Divider(color: _cardBorder, height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: nextClasses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = nextClasses[index];
                final isLab = VtopHelpers.isLabCourse(
                  courseType: item['course_type']?.toString(),
                  courseSlot: item['slot']?.toString(),
                );
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _cardBgLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isLab
                              ? const Color(0xFF10B981).withOpacity(0.12)
                              : _accentPrimary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item['slot'] ?? '',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isLab ? const Color(0xFF10B981) : _accentPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['course_name'] ?? 'Class',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
                              ),
                            ),
                            Text(
                              '${item['time'] ?? ''} • ${item['venue'] ?? 'TBA'}',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: _textSecondary,
                              ),
                            ),
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

  // ─── Quick Access Card ───────────────────────────────────────────────────
  Widget _buildQuickAccessCard(_QuickItem item, Map<String, dynamic> data, AuthState authState, int index) {
    return GestureDetector(
      onTap: () => _handleQuickTap(item, data, authState),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: item.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: item.gradient.first.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(item.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 8),
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
                    color: _textPrimary,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: (30 * index).ms)
        .fadeIn(duration: 300.ms)
        .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1), curve: Curves.easeOutCubic);
  }

  // ─── Shimmer Skeleton ────────────────────────────────────────────────────
  Widget _buildShimmerSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(width: 140, height: 40, decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12))),
            Container(width: 80, height: 32, decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12))),
          ],
        ),
        const SizedBox(height: 24),
        Container(height: 110, decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(20))),
        const SizedBox(height: 24),
        Container(width: 100, height: 20, decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(6))),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 8,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (_, __) => Container(
            decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ],
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1000.ms, color: Colors.white10);
  }

  // ─── Error State ─────────────────────────────────────────────────────────
  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 52, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text('Could not update Dashboard',
                style: GoogleFonts.manrope(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _textMuted, fontSize: 12)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: Text('Retry', style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickItem {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final String? action;

  const _QuickItem({
    required this.label,
    required this.icon,
    required this.gradient,
    this.action,
  });
}