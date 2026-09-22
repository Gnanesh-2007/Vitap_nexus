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

class DashboardScreen extends ConsumerStatefulWidget {
  final Function(int)? onNavigateTab;

  const DashboardScreen({
    super.key,
    this.onNavigateTab,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isScheduleExpanded = false;

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
  static const Color _cream = Color(0xFFECE7DC);
  static const Color _green = Color(0xFF278B68);
  static const Color _line = Color(0xFFE2DED5);
  static const Color _soft = Color(0xFFF0EEE8);

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  // 4x2 Quick Access Items
  static const List<_QuickItem> _quickAccessItems = [
    _QuickItem(
      label: 'Biometric',
      icon: Icons.fingerprint_rounded,
      accent: _navy,
      action: 'biometric',
    ),
    _QuickItem(
      label: 'VTOP Portal',
      icon: Icons.language_rounded,
      accent: _navy,
      action: 'direct_vtop',
    ),
    _QuickItem(
      label: 'Exams',
      icon: Icons.event_note_rounded,
      accent: _orange,
      action: 'exams',
    ),
    _QuickItem(
      label: 'Calendar',
      icon: Icons.calendar_month_rounded,
      accent: _blue,
      action: 'calendar',
    ),
    _QuickItem(
      label: 'Outing',
      icon: Icons.directions_walk_rounded,
      accent: _green,
      action: 'outings',
    ),
    _QuickItem(
      label: 'Assignments',
      icon: Icons.assignment_outlined,
      accent: _orange,
      action: 'assignments',
    ),
    _QuickItem(
      label: 'Course Page',
      icon: Icons.menu_book_rounded,
      accent: _blue,
      action: 'courses',
    ),
    _QuickItem(
      label: 'More',
      icon: Icons.grid_view_rounded,
      accent: _navy,
      action: 'more',
    ),
  ];

  Future<void> _handleQuickTap(
    _QuickItem item,
    Map<String, dynamic> data,
    AuthState authState,
  ) async {
    if (!mounted) return;

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

    if (item.action == 'more') {
      _showMoreBottomSheet(data, authState);
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

  void _showMoreBottomSheet(
    Map<String, dynamic> data,
    AuthState authState,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final moreItems = [
          _QuickItem(
            label: 'Grades & CGPA',
            icon: Icons.bar_chart_rounded,
            accent: _blue,
            action: 'grades',
            subtitle: 'Academic record',
          ),
          _QuickItem(
            label: 'Faculty Mentor',
            icon: Icons.person_outline_rounded,
            accent: _green,
            action: 'mentor',
            subtitle: 'Contact info',
          ),
          _QuickItem(
            label: 'Fee Payments',
            icon: Icons.account_balance_wallet_outlined,
            accent: _orange,
            action: 'payments',
            subtitle: 'Dues & receipts',
          ),
          _QuickItem(
            label: 'Student Profile',
            icon: Icons.badge_outlined,
            accent: _navy,
            action: 'profile',
            subtitle: 'Credentials & info',
          ),
          _QuickItem(
            label: 'Full Timetable',
            icon: Icons.schedule_rounded,
            accent: _blue,
            action: 'calendar',
            subtitle: 'Weekly schedule',
          ),
          _QuickItem(
            label: 'Exam Schedule',
            icon: Icons.event_note_rounded,
            accent: _orange,
            action: 'exams',
            subtitle: 'CAT & FAT dates',
          ),
        ];

        return Container(
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    'Campus Services',
                    style: GoogleFonts.dmSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: _inkMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: moreItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.2,
                ),
                itemBuilder: (context, index) {
                  final item = moreItems[index];
                  return InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      if (item.action == 'profile') {
                        _navigateScreen(const ProfileScreen());
                      } else {
                        _handleQuickTap(item, data, authState);
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _paper,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _line),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: item.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(item.icon, color: item.accent, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                  ),
                                ),
                                if (item.subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    item.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: _inkMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCourseDetails(BuildContext context, Map<String, dynamic> item) {
    final isLab = VtopHelpers.isLabCourse(
      courseType: item['course_type']?.toString(),
      courseSlot: item['slot']?.toString(),
      courseTypeCode: item['course_type_code']?.toString(),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: _line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLab ? _orange.withValues(alpha: 0.12) : _blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    isLab ? 'LAB / PRACTICAL' : 'THEORY COURSE',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isLab ? _orange : _blue,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Spacer(),
                if (item['slot'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: _cream,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      'SLOT ${item['slot']}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _navy,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              item['course_name'] ?? item['course_title'] ?? 'Course Details',
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _ink,
                height: 1.2,
                letterSpacing: -0.4,
              ),
            ),
            if (item['course_code'] != null && item['course_code'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item['course_code'],
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _inkMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _paper,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _line),
              ),
              child: Column(
                children: [
                  _detailRow(Icons.access_time_rounded, 'Timing', item['time'] ?? 'N/A'),
                  const Divider(height: 18, color: _line),
                  _detailRow(Icons.location_on_outlined, 'Room / Venue', item['venue'] ?? item['room_no'] ?? 'TBA'),
                  if (item['faculty'] != null && item['faculty'].toString().isNotEmpty) ...[
                    const Divider(height: 18, color: _line),
                    _detailRow(Icons.person_outline_rounded, 'Faculty', item['faculty']),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 17, color: _navy),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _inkMuted,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ),
      ],
    );
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
        return 'HAPPENING NOW';
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

    final data = dashboardState.data ?? {};
    final profile = data['profile'] as Map<String, dynamic>? ?? {};
    final studentName = profile['student_name'] ?? authState.username ?? 'Student';

    final timetable = data['timetable'] as Map<String, dynamic>? ?? {};
    final today = DateFormat('EEEE').format(DateTime.now());
    final rawTodayClasses = timetable[today] as List<dynamic>? ?? [];
    final todayClasses = VtopHelpers.sortTimetableList(rawTodayClasses);

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    // Calculate remaining classes count
    final remainingCount = todayClasses.where((c) {
      final range = VtopHelpers.parseTimeRange(c['time']?.toString() ?? '');
      return range['end']! > currentMinutes;
    }).length;

    // Pick hero class: active class if any, or next upcoming class, or first class
    Map<String, dynamic>? heroClass;
    for (var c in todayClasses) {
      final range = VtopHelpers.parseTimeRange(c['time']?.toString() ?? '');
      if (currentMinutes >= range['start']! && currentMinutes <= range['end']!) {
        heroClass = c as Map<String, dynamic>;
        break;
      }
    }
    if (heroClass == null) {
      for (var c in todayClasses) {
        final range = VtopHelpers.parseTimeRange(c['time']?.toString() ?? '');
        if (currentMinutes < range['start']!) {
          heroClass = c as Map<String, dynamic>;
          break;
        }
      }
    }

    // Subsequent classes (classes other than hero class)
    final subsequentClasses = heroClass != null
        ? todayClasses.where((c) => c != heroClass).toList()
        : todayClasses;

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

              // Hero class card or Empty hero
              if (todayClasses.isNotEmpty && heroClass != null)
                _buildHeroClassCard(heroClass)
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

              // Subsequent classes stacked cards
              if (subsequentClasses.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildSubsequentClasses(subsequentClasses),
              ],

              const SizedBox(height: 28),

              // ======================================================
              // QUICK ACCESS SECTION (4x2 Grid from reference)
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
  // HERO CLASS CARD
  // ============================================================
  Widget _buildHeroClassCard(Map<String, dynamic> item) {
    final isLab = VtopHelpers.isLabCourse(
      courseType: item['course_type']?.toString(),
      courseSlot: item['slot']?.toString(),
      courseTypeCode: item['course_type_code']?.toString(),
    );

    final timeStr = item['time']?.toString() ?? '';
    final countdown = _getCountdownText(timeStr);
    final isLive = countdown == 'HAPPENING NOW';

    final courseCode = item['course_code']?.toString() ?? '';
    final courseSlot = item['slot']?.toString() ?? '';
    final courseName = item['course_name'] ?? item['course_title'] ?? 'Scheduled Class';
    final venue = item['venue'] ?? item['room_no'] ?? 'TBA';

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
      onTap: () => _showCourseDetails(context, item),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _line, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: _ink.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Code & Slot on Left | Status pill on Right
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
                    color: isLive
                        ? _green.withValues(alpha: 0.12)
                        : (countdown == 'COMPLETED'
                            ? _soft
                            : _orange.withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isLive
                          ? _green.withValues(alpha: 0.3)
                          : (countdown == 'COMPLETED'
                              ? _line
                              : _orange.withValues(alpha: 0.3)),
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
                        countdown,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: isLive
                              ? _green
                              : (countdown == 'COMPLETED' ? _inkMuted : _orange),
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: _ink,
                height: 1.22,
                letterSpacing: -0.4,
              ),
            ),

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
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY / FREE HERO STATE
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: _green,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All done for today',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'No more scheduled classes today. Enjoy your time!',
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
  // SUBSEQUENT CLASSES (COMPACT STACKED ROWS)
  // ============================================================
  Widget _buildSubsequentClasses(List<dynamic> classes) {
    final visibleClasses = _isScheduleExpanded ? classes : classes.take(3).toList();

    return Column(
      children: [
        ...visibleClasses.map((item) {
          final isLab = VtopHelpers.isLabCourse(
            courseType: item['course_type']?.toString(),
            courseSlot: item['slot']?.toString(),
            courseTypeCode: item['course_type_code']?.toString(),
          );

          final timeStr = item['time']?.toString() ?? '';
          final startTime = _formatStartTime(timeStr);
          final courseName = item['course_name'] ?? item['course_title'] ?? 'Class';
          final venue = item['venue'] ?? item['room_no'] ?? 'TBA';

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _showCourseDetails(context, item as Map<String, dynamic>),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _line),
                ),
                child: Row(
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
                      child: Text(
                        courseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Venue badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _soft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _line.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        venue,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isLab ? _orange : _navy,
                        ),
                      ),
                    ),
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
                        : 'SHOW ALL ${classes.length} REMAINING',
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
  // QUICK ACCESS 4x2 GRID (CIRCULAR BUTTONS FROM REFERENCE)
  // ============================================================
  Widget _buildQuickAccessGrid(Map<String, dynamic> data, AuthState authState) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _quickAccessItems.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) {
        final item = _quickAccessItems[index];

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
            .animate(delay: (25 * index).ms)
            .fadeIn(duration: 250.ms)
            .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
      },
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
}

// ============================================================
// QUICK ACTION MODEL
// ============================================================
class _QuickItem {
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final String? action;

  const _QuickItem({
    required this.label,
    this.subtitle,
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
