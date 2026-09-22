import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../providers/vtop_providers.dart';
import '../utils/vtop_helpers.dart';
import 'grades_screen.dart';
import 'outings_screen.dart';
import 'mentor_screen.dart';
import 'biometric_screen.dart';
import 'payments_screen.dart';
import 'courses_screen.dart';
import 'assignments_screen.dart';
import 'vtop_webview_screen.dart';
import 'profile_screen.dart';
import 'exam_schedule.dart';
import 'timetable_screen.dart';
import 'attendance_screen.dart';
import 'marks_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final Function(int)? onNavigateTab;

  const DashboardScreen({
    super.key,
    this.onNavigateTab,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  bool _isQuickAccessExpanded = false;
  bool _isScheduleExpanded = false;
  bool _isCompletedExpanded = false;
  final Set<String> _expandedClassIds = {};
  Timer? _tickerTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Periodically update class timers and progress bars in real-time
    _tickerTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dash = ref.read(dashboardProvider);
      if (!dash.hasData) {
        ref.read(dashboardProvider.notifier).reloadForCurrentUser();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Immediately re-render when app is brought back from recents or resumed
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ============================================================
  // EDITORIAL CAMPUS THEME
  // ============================================================
  static const Color _paper = Color(0xFFF4F2ED);
  static const Color _surface = Color(0xFFFFFEFB);
  static const Color _ink = Color(0xFF17202A);
  static const Color _inkSoft = Color(0xFF56616D);
  static const Color _inkMuted = Color(0xFF8A929A);

  static const Color _navy = Color(0xFF172B4D);
  static const Color _blue = Color(0xFF356AE6);
  static const Color _orange = Color(0xFFE47543);
  static const Color _green = Color(0xFF278B68);
  static const Color _line = Color(0xFFE2DED5);
  static const Color _soft = Color(0xFFF0EEE8);

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  // Non-duplicate Quick Access items
  List<_QuickItem> _getQuickAccessItems() {
    final baseItems = [
      const _QuickItem(
        label: 'Biometric',
        icon: Icons.fingerprint_rounded,
        accent: _navy,
        action: 'biometric',
      ),
      const _QuickItem(
        label: 'VTOP Portal',
        icon: Icons.language_rounded,
        accent: _navy,
        action: 'direct_vtop',
      ),
      const _QuickItem(
        label: 'Exams',
        icon: Icons.event_note_rounded,
        accent: _orange,
        action: 'exams',
      ),
      const _QuickItem(
        label: 'Calendar',
        icon: Icons.calendar_month_rounded,
        accent: _blue,
        action: 'calendar',
      ),
      const _QuickItem(
        label: 'Outing',
        icon: Icons.directions_walk_rounded,
        accent: _green,
        action: 'outings',
      ),
      const _QuickItem(
        label: 'Assignments',
        icon: Icons.assignment_outlined,
        accent: _orange,
        action: 'assignments',
      ),
      const _QuickItem(
        label: 'Course Page',
        icon: Icons.menu_book_rounded,
        accent: _blue,
        action: 'courses',
      ),
    ];

    if (!_isQuickAccessExpanded) {
      return [
        ...baseItems,
        const _QuickItem(
          label: 'More',
          icon: Icons.grid_view_rounded,
          accent: _navy,
          action: 'toggle_more',
        ),
      ];
    } else {
      // Inline expanded items - strictly NO DUPLICATES!
      return [
        ...baseItems,
        const _QuickItem(
          label: 'Grades',
          icon: Icons.bar_chart_rounded,
          accent: _blue,
          action: 'grades',
        ),
        const _QuickItem(
          label: 'Mentor',
          icon: Icons.person_outline_rounded,
          accent: _green,
          action: 'mentor',
        ),
        const _QuickItem(
          label: 'Payments',
          icon: Icons.account_balance_wallet_outlined,
          accent: _orange,
          action: 'payments',
        ),
        const _QuickItem(
          label: 'Profile',
          icon: Icons.badge_outlined,
          accent: _navy,
          action: 'profile',
        ),
        const _QuickItem(
          label: 'Attendance',
          icon: Icons.pie_chart_rounded,
          accent: _orange,
          action: 'attendance',
        ),
        const _QuickItem(
          label: 'Marks',
          icon: Icons.assignment_turned_in_rounded,
          accent: _green,
          action: 'marks',
        ),
        const _QuickItem(
          label: 'Less',
          icon: Icons.keyboard_arrow_up_rounded,
          accent: _navy,
          action: 'toggle_more',
        ),
      ];
    }
  }

  Future<void> _handleQuickTap(
    _QuickItem item,
    Map<String, dynamic> data,
    AuthState authState,
  ) async {
    if (!mounted) return;

    if (item.action == 'toggle_more') {
      setState(() {
        _isQuickAccessExpanded = !_isQuickAccessExpanded;
      });
      return;
    }

    if (item.action == 'calendar') {
      if (widget.onNavigateTab != null) {
        widget.onNavigateTab!(2);
      } else {
        _navigateScreen(const TimetableScreen());
      }
      return;
    }

    if (item.action == 'exams') {
      if (widget.onNavigateTab != null) {
        widget.onNavigateTab!(4);
      } else {
        _navigateScreen(const ExamScheduleScreen());
      }
      return;
    }

    if (item.action == 'attendance') {
      if (widget.onNavigateTab != null) {
        widget.onNavigateTab!(1);
      } else {
        _navigateScreen(const AttendanceScreen());
      }
      return;
    }

    if (item.action == 'marks') {
      if (widget.onNavigateTab != null) {
        widget.onNavigateTab!(3);
      } else {
        _navigateScreen(const MarksScreen());
      }
      return;
    }

    if (item.action == 'profile') {
      _navigateScreen(const ProfileScreen());
      return;
    }

    late Widget targetScreen;

    switch (item.action) {
      case 'biometric':
        targetScreen = const BiometricScreen();
        break;

      case 'direct_vtop':
        targetScreen = const VtopWebViewScreen();
        break;

      case 'outings':
        targetScreen = const OutingsScreen();
        break;

      case 'assignments':
        targetScreen = const AssignmentsScreen();
        break;

      case 'courses':
        targetScreen = const CoursesScreen();
        break;

      case 'grades':
        targetScreen = GradesScreen(
          initialData: data['grade_history'] as Map<String, dynamic>?,
        );
        break;

      case 'mentor':
        targetScreen = const MentorScreen();
        break;

      case 'payments':
        targetScreen = const PaymentsScreen();
        break;

      default:
        return;
    }

    _navigateScreen(targetScreen);
  }

  void _navigateScreen(Widget screen) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, _) => screen,
        transitionsBuilder: (_, animation, _, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _toggleClassExpanded(String classId) {
    setState(() {
      if (_expandedClassIds.contains(classId)) {
        _expandedClassIds.remove(classId);
      } else {
        _expandedClassIds.add(classId);
      }
    });
  }

  String _getClassId(Map<String, dynamic> item) {
    final code = item['course_code'] ?? '';
    final slot = item['slot'] ?? '';
    final time = item['time'] ?? '';
    final name = item['course_name'] ?? item['course_title'] ?? '';
    return '$code-$slot-$time-$name';
  }

  double _calculateLiveProgress(String timeStr) {
    try {
      final range = VtopHelpers.parseTimeRange(timeStr);
      final startMin = range['start']!;
      final endMin = range['end']!;
      if (endMin <= startMin) return 0.0;

      final now = DateTime.now();
      final currentMin = now.hour * 60 + now.minute;

      if (currentMin < startMin) return 0.0;
      if (currentMin >= endMin) return 1.0;

      return (currentMin - startMin) / (endMin - startMin);
    } catch (_) {
      return 0.0;
    }
  }

  String _getCountdownText(String timeStr) {
    if (timeStr.isEmpty) return 'SCHEDULED';
    try {
      final range = VtopHelpers.parseTimeRange(timeStr);
      final startMin = range['start']!;
      final endMin = range['end']!;

      final now = DateTime.now();
      final currentMin = now.hour * 60 + now.minute;

      if (currentMin >= startMin && currentMin <= endMin) {
        final remaining = endMin - currentMin;
        return '$remaining MINS LEFT';
      } else if (currentMin < startMin) {
        final diff = startMin - currentMin;
        final h = diff ~/ 60;
        final m = diff % 60;
        if (h > 0) {
          return 'IN ${h}H ${m}M';
        } else {
          return 'IN ${m}M';
        }
      } else {
        return 'COMPLETED';
      }
    } catch (_) {
      return 'SCHEDULED';
    }
  }

  String _formatStartTime(String timeStr) {
    if (timeStr.isEmpty) return '--';
    final part = timeStr.split('-').first.trim();
    return part;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final dashboardState = ref.watch(dashboardProvider);

    if (!dashboardState.hasData && dashboardState.error != null) {
      return Scaffold(
        backgroundColor: _paper,
        body: SafeArea(
          child: _ErrorView(
            message: dashboardState.error!,
            onRetry: () {
              ref.read(dashboardProvider.notifier).refresh();
            },
          ),
        ),
      );
    }

    if (!dashboardState.hasData) {
      if (dashboardState.error != null) {
        return Scaffold(
          backgroundColor: _paper,
          body: SafeArea(
            child: _ErrorView(
              message: dashboardState.error!,
              onRetry: () {
                ref.read(dashboardProvider.notifier).refresh();
              },
            ),
          ),
        );
      }
      return Scaffold(
        backgroundColor: _paper,
        body: SafeArea(
          child: _buildDashboardSkeleton(authState),
        ),
      );
    }

    final data = dashboardState.data ?? {};
    final profile = data['profile'] as Map<String, dynamic>? ?? {};
    final studentName = profile['student_name'] ?? authState.username ?? 'Student';

    final timetable = data['timetable'] as Map<String, dynamic>? ?? {};
    final today = DateFormat('EEEE').format(DateTime.now());
    final rawTodayClasses = timetable[today] as List<dynamic>? ?? [];
    final todayClasses = VtopHelpers.sortTimetableList(rawTodayClasses);

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    // Segment classes into: Live, Upcoming, Completed
    Map<String, dynamic>? liveClass;
    final List<Map<String, dynamic>> upcomingClasses = [];
    final List<Map<String, dynamic>> completedClasses = [];

    for (var c in todayClasses) {
      final map = c as Map<String, dynamic>;
      final range = VtopHelpers.parseTimeRange(map['time']?.toString() ?? '');
      final start = range['start']!;
      final end = range['end']!;

      if (currentMinutes >= start && currentMinutes <= end) {
        liveClass = map;
      } else if (currentMinutes < start) {
        upcomingClasses.add(map);
      } else {
        completedClasses.add(map);
      }
    }

    // Determine hero class:
    // If live class exists -> liveClass
    // Else if upcoming classes exist -> upcomingClasses.first
    // Else if all completed -> null (show all finished)
    Map<String, dynamic>? heroClass = liveClass;
    if (heroClass == null && upcomingClasses.isNotEmpty) {
      heroClass = upcomingClasses.first;
    }

    // Subsequent upcoming classes to show below Hero
    final subsequentUpcoming = (heroClass != null && upcomingClasses.contains(heroClass))
        ? upcomingClasses.where((c) => c != heroClass).toList()
        : upcomingClasses;

    final remainingCount = (liveClass != null ? 1 : 0) + upcomingClasses.length;

    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: RefreshIndicator(
          color: _navy,
          backgroundColor: _surface,
          onRefresh: () async {
            await ref.read(dashboardProvider.notifier).refresh();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
            children: [
              // 1. Header & Profile
              _buildHeader(authState, studentName),

              const SizedBox(height: 12),

              // 2. Date Strip
              _buildDateStrip(),

              const SizedBox(height: 24),

              // ======================================================
              // TODAY'S TIMETABLE / SCHEDULE SECTION
              // Modeled from reference with Today header + X left badge
              // ======================================================
              _buildTodayHeader(remainingCount, todayClasses.length),

              const SizedBox(height: 14),

              // Hero class card (Live progress bar or Next upcoming countdown)
              if (heroClass != null)
                _buildHeroClassCard(heroClass, isLive: heroClass == liveClass)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(
                      begin: 0.04,
                      end: 0,
                      curve: Curves.easeOutCubic,
                    )
              else if (todayClasses.isNotEmpty && completedClasses.length == todayClasses.length)
                _buildAllCompletedHero()
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(
                      begin: 0.04,
                      end: 0,
                      curve: Curves.easeOutCubic,
                    )
              else
                _buildNoClassesHero()
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(
                      begin: 0.04,
                      end: 0,
                      curve: Curves.easeOutCubic,
                    ),

              // Subsequent upcoming classes stacked cards
              if (subsequentUpcoming.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildUpcomingClassesList(subsequentUpcoming),
              ],

              // Completed Classes Section (moves completed classes here!)
              if (completedClasses.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildCompletedClassesSection(completedClasses),
              ],

              const SizedBox(height: 28),

              // ======================================================
              // QUICK ACCESS SECTION (Expands inline right there!)
              // ======================================================
              _buildQuickAccessHeader(),

              const SizedBox(height: 16),

              _buildQuickAccessGrid(data, authState),

              const SizedBox(height: 32),

              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildHeader(AuthState authState, String studentName) {
    final firstName = studentName.split(' ').first;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo block
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _navy,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Image.asset(
              'assets/images/konoha_logo.png',
              color: Colors.white,
              errorBuilder: (_, _, _) {
                return const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 27,
                );
              },
            ),
          ),
        ),

        const SizedBox(width: 13),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _inkMuted,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                firstName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Profile icon
        GestureDetector(
          onTap: () {
            _navigateScreen(const ProfileScreen());
          },
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: _navy,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DATE STRIP
  // ============================================================
  Widget _buildDateStrip() {
    final now = DateTime.now();

    return Row(
      children: [
        Text(
          DateFormat('EEE').format(now).toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _orange,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 9),
        Container(
          width: 1,
          height: 13,
          color: _line,
        ),
        const SizedBox(width: 9),
        Text(
          DateFormat('d MMMM yyyy').format(now),
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _inkSoft,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TODAY SCHEDULE HEADER
  // ============================================================
  Widget _buildTodayHeader(int remainingCount, int totalClasses) {
    String badgeText;
    if (totalClasses == 0) {
      badgeText = 'No classes';
    } else if (remainingCount > 0) {
      badgeText = '$remainingCount left';
    } else {
      badgeText = 'All done';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Today',
          style: GoogleFonts.dmSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _ink,
            letterSpacing: -0.6,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _line),
          ),
          child: Text(
            badgeText,
            style: GoogleFonts.dmSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: remainingCount > 0 ? _navy : _green,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HERO CLASS CARD WITH LIVE PROGRESS BAR OR COUNTDOWN
  // ============================================================
  Widget _buildHeroClassCard(Map<String, dynamic> item, {required bool isLive}) {
    final classId = _getClassId(item);
    final isExpanded = _expandedClassIds.contains(classId);

    final isLab = VtopHelpers.isLabCourse(
      courseType: item['course_type']?.toString(),
      courseSlot: item['slot']?.toString(),
      courseTypeCode: item['course_type_code']?.toString(),
    );

    final timeStr = item['time']?.toString() ?? '';
    final countdown = _getCountdownText(timeStr);
    final progress = _calculateLiveProgress(timeStr);

    final courseCode = item['course_code']?.toString() ?? '';
    final courseSlot = item['slot']?.toString() ?? '';
    final courseName = item['course_name'] ?? item['course_title'] ?? 'Scheduled Class';
    final venue = item['venue'] ?? item['room_no'] ?? 'TBA';
    final faculty = item['faculty']?.toString() ?? '';

    String topMeta = '';
    if (courseCode.isNotEmpty) {
      topMeta = '$courseCode • ${isLab ? "LAB" : "TH"}';
      if (courseSlot.isNotEmpty) topMeta += ' - $courseSlot';
    } else if (courseSlot.isNotEmpty) {
      topMeta = 'SLOT $courseSlot • ${isLab ? "LAB" : "TH"}';
    } else {
      topMeta = isLab ? 'LAB COURSE' : 'THEORY COURSE';
    }

    return InkWell(
      onTap: () => _toggleClassExpanded(classId),
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isLive ? _green.withValues(alpha: 0.4) : _line,
            width: isLive ? 1.4 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isLive ? _green.withValues(alpha: 0.06) : _ink.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Code & Slot on Left | Status / Countdown pill on Right
            Row(
              children: [
                Expanded(
                  child: Text(
                    topMeta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isLab ? _orange : _navy,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: isLive ? _green.withValues(alpha: 0.12) : _orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isLive ? _green.withValues(alpha: 0.3) : _orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLive) ...[
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                            color: _green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      Text(
                        isLive ? 'LIVE NOW • $countdown' : countdown,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: isLive ? _green : _orange,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Course Name
            Text(
              courseName,
              maxLines: isExpanded ? 4 : 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: _ink,
                height: 1.22,
                letterSpacing: -0.4,
              ),
            ),

            // ========================================================
            // LIVE CLASS PROGRESS BAR (Completes according to time)
            // ========================================================
            if (isLive) ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CLASS PROGRESS',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: _green,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}% COMPLETED',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: _green,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Container(
                          height: 6,
                          width: double.infinity,
                          color: _green.withValues(alpha: 0.15),
                        ),
                        FractionallySizedBox(
                          widthFactor: progress.clamp(0.01, 1.0),
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: _green,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Location & Time Row
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 14,
                  color: _orange,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    venue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _inkSoft,
                    ),
                  ),
                ),
                if (timeStr.isNotEmpty) ...[
                  Text(
                    '  •  ',
                    style: TextStyle(
                      color: _inkMuted.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    Icons.access_time_filled_rounded,
                    size: 13,
                    color: _navy,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      timeStr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: _inkMuted,
                ),
              ],
            ),

            // Inline Expanded Details
            if (isExpanded) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _paper,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _line),
                ),
                child: Column(
                  children: [
                    _inlineDetailRow(Icons.access_time_rounded, 'Class Time', timeStr),
                    const Divider(height: 14, color: _line),
                    _inlineDetailRow(Icons.location_on_outlined, 'Room / Venue', venue),
                    if (faculty.isNotEmpty) ...[
                      const Divider(height: 14, color: _line),
                      _inlineDetailRow(Icons.person_outline_rounded, 'Faculty', faculty),
                    ],
                    if (courseCode.isNotEmpty) ...[
                      const Divider(height: 14, color: _line),
                      _inlineDetailRow(Icons.tag_rounded, 'Course Code', courseCode),
                    ],
                    if (courseSlot.isNotEmpty) ...[
                      const Divider(height: 14, color: _line),
                      _inlineDetailRow(Icons.grid_view_rounded, 'Slot', courseSlot),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ALL COMPLETED HERO STATE
  // ============================================================
  Widget _buildAllCompletedHero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: _green,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All classes done for today',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'All scheduled lectures finished. Great job today!',
                  style: GoogleFonts.dmSans(
                    fontSize: 11.5,
                    color: _inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY HERO STATE (NO CLASSES TODAY)
  // ============================================================
  Widget _buildNoClassesHero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.free_breakfast_outlined,
              color: _blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No classes scheduled today',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Enjoy your free day or prepare for upcoming assessments!',
                  style: GoogleFonts.dmSans(
                    fontSize: 11.5,
                    color: _inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // UPCOMING CLASSES LIST WITH INLINE EXPANSION & COUNTDOWN
  // ============================================================
  Widget _buildUpcomingClassesList(List<Map<String, dynamic>> classes) {
    final visibleClasses = _isScheduleExpanded ? classes : classes.take(3).toList();

    return Column(
      children: [
        ...visibleClasses.map((item) {
          final classId = _getClassId(item);
          final isExpanded = _expandedClassIds.contains(classId);

          final isLab = VtopHelpers.isLabCourse(
            courseType: item['course_type']?.toString(),
            courseSlot: item['slot']?.toString(),
            courseTypeCode: item['course_type_code']?.toString(),
          );

          final timeStr = item['time']?.toString() ?? '';
          final startTime = _formatStartTime(timeStr);
          final countdown = _getCountdownText(timeStr);
          final courseName = item['course_name'] ?? item['course_title'] ?? 'Class';
          final venue = item['venue'] ?? item['room_no'] ?? 'TBA';
          final faculty = item['faculty']?.toString() ?? '';
          final courseCode = item['course_code']?.toString() ?? '';
          final courseSlot = item['slot']?.toString() ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _toggleClassExpanded(classId),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Start Time (Fixed width)
                        SizedBox(
                          width: 68,
                          child: Text(
                            startTime,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _navy,
                            ),
                          ),
                        ),

                        Container(
                          width: 1,
                          height: 18,
                          color: _line,
                        ),

                        const SizedBox(width: 12),

                        // Course Name
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                courseName,
                                maxLines: isExpanded ? 3 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                              if (isExpanded && courseCode.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  courseCode,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: _inkMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Countdown Pill (e.g. IN 2H 15M)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: _orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            countdown,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: _orange,
                            ),
                          ),
                        ),

                        const SizedBox(width: 6),

                        // Venue badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: _soft,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _line.withValues(alpha: 0.6)),
                          ),
                          child: Text(
                            venue,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isLab ? _orange : _navy,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Inline Details when tapped
                    if (isExpanded) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _paper,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _line),
                        ),
                        child: Column(
                          children: [
                            _inlineDetailRow(Icons.access_time_rounded, 'Class Timing', timeStr),
                            const Divider(height: 12, color: _line),
                            _inlineDetailRow(Icons.location_on_outlined, 'Room / Venue', venue),
                            if (faculty.isNotEmpty) ...[
                              const Divider(height: 12, color: _line),
                              _inlineDetailRow(Icons.person_outline_rounded, 'Faculty', faculty),
                            ],
                            if (courseSlot.isNotEmpty) ...[
                              const Divider(height: 12, color: _line),
                              _inlineDetailRow(Icons.grid_view_rounded, 'Slot', courseSlot),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),

        if (classes.length > 3) ...[
          const SizedBox(height: 2),
          GestureDetector(
            onTap: () {
              setState(() {
                _isScheduleExpanded = !_isScheduleExpanded;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isScheduleExpanded
                        ? 'SHOW LESS'
                        : 'SHOW ALL ${classes.length} UPCOMING',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    _isScheduleExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: _navy,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // COMPLETED CLASSES SECTION (Shows finished classes here)
  // ============================================================
  Widget _buildCompletedClassesSection(List<Map<String, dynamic>> completedClasses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isCompletedExpanded = !_isCompletedExpanded;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: _green,
                ),
                const SizedBox(width: 6),
                Text(
                  'Completed Classes (${completedClasses.length})',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _inkSoft,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Icon(
                  _isCompletedExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: _inkMuted,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (_isCompletedExpanded) ...[
          ...completedClasses.map((item) {
            final classId = _getClassId(item);
            final isExpanded = _expandedClassIds.contains(classId);
            final timeStr = item['time']?.toString() ?? '';
            final startTime = _formatStartTime(timeStr);
            final courseName = item['course_name'] ?? item['course_title'] ?? 'Class';
            final venue = item['venue'] ?? item['room_no'] ?? 'TBA';
            final faculty = item['faculty']?.toString() ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _toggleClassExpanded(classId),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: _paper,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: _green,
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 60,
                            child: Text(
                              startTime,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: _inkMuted,
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 16,
                            color: _line,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              courseName,
                              maxLines: isExpanded ? 3 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _inkSoft,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: _line),
                            ),
                            child: Text(
                              venue,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isExpanded) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _line),
                          ),
                          child: Column(
                            children: [
                              _inlineDetailRow(Icons.access_time_rounded, 'Class Time', timeStr),
                              const Divider(height: 10, color: _line),
                              _inlineDetailRow(Icons.location_on_outlined, 'Room', venue),
                              if (faculty.isNotEmpty) ...[
                                const Divider(height: 10, color: _line),
                                _inlineDetailRow(Icons.person_outline_rounded, 'Faculty', faculty),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _inlineDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: _navy),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _inkMuted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            maxLines: 3,
            softWrap: true,
            textAlign: TextAlign.end,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // QUICK ACCESS HEADER
  // ============================================================
  Widget _buildQuickAccessHeader() {
    return Row(
      children: [
        Text(
          'Quick Access',
          style: GoogleFonts.dmSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _ink,
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // QUICK ACCESS 4xN GRID (Expands inline smoothly right there!)
  // ============================================================
  Widget _buildQuickAccessGrid(Map<String, dynamic> data, AuthState authState) {
    final items = _getQuickAccessItems();

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 16,
          childAspectRatio: 0.78,
        ),
        itemBuilder: (context, index) {
          final item = items[index];

          return InkWell(
            onTap: () => _handleQuickTap(item, data, authState),
            borderRadius: BorderRadius.circular(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Circular icon button
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _surface,
                    border: Border.all(color: _line, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: _ink.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      item.icon,
                      color: item.accent,
                      size: 23,
                    ),
                  ),
                ),

                const SizedBox(height: 7),

                // Title label
                Flexible(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
              ],
            ),
          )
              .animate(delay: (20 * (index % 4)).ms)
              .fadeIn(duration: 220.ms)
              .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
        },
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Text(
        'VIT-AP  •  VTOP NEXUS',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: _inkMuted,
          letterSpacing: 1.8,
        ),
      ),
    );
  }

  Widget _buildDashboardSkeleton(AuthState authState) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
      children: [
        // 1. Header with Name Skeleton
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 26,
                        height: 26,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
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
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: _inkMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (authState.username ?? 'STUDENT').toUpperCase(),
                      style: GoogleFonts.dmSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _line),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        _buildDateStrip(),
        const SizedBox(height: 24),

        // Skeleton Today Schedule Card
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _line),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 140,
                          height: 14,
                          decoration: BoxDecoration(
                            color: _soft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 200,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _soft,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(duration: 1200.ms, color: Colors.white70),

        const SizedBox(height: 28),
        _buildQuickAccessHeader(),
        const SizedBox(height: 16),

        // Skeleton Quick Access Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 12,
            mainAxisExtent: 86,
          ),
          itemCount: 8,
          itemBuilder: (context, index) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _surface,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 44,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            );
          },
        )
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(duration: 1200.ms, color: Colors.white70),
      ],
    );
  }
}

// ============================================================
// QUICK ACTION MODEL
// ============================================================
class _QuickItem {
  final String label;
  final IconData icon;
  final Color accent;
  final String? action;

  const _QuickItem({
    required this.label,
    required this.icon,
    required this.accent,
    this.action,
  });
}

// ============================================================
// ERROR SCREEN
// ============================================================
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xFFD94B4B).withValues(alpha: .10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.sync_problem_rounded,
                color: Color(0xFFD94B4B),
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Couldn’t update dashboard',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF17202A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                height: 1.45,
                color: const Color(0xFF8A929A),
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF172B4D),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(
                Icons.refresh_rounded,
                size: 17,
              ),
              label: Text(
                'TRY AGAIN',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
