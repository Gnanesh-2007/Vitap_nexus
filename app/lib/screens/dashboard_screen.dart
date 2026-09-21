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
  // NEW DESIGN SYSTEM
  // Editorial Campus / Paper + Ink
  // ============================================================

  static const Color _paper = Color(0xFFF5F3EE);
  static const Color _paperBright = Color(0xFFFFFEFA);
  static const Color _ink = Color(0xFF17202A);
  static const Color _inkSoft = Color(0xFF56616D);
  static const Color _inkMuted = Color(0xFF8A929A);

  static const Color _navy = Color(0xFF172B4D);
  static const Color _blue = Color(0xFF2F6FED);
  static const Color _orange = Color(0xFFE76F3C);
  static const Color _cream = Color(0xFFECE7DC);
  static const Color _green = Color(0xFF23835B);

  static const Color _line = Color(0xFFDCD8D0);

  String _getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  static const List<_QuickItem> _quickAccessItems = [
    _QuickItem(
      label: 'Grades',
      subtitle: 'CGPA & marks',
      icon: Icons.bar_chart_rounded,
      accent: _blue,
      action: 'grades',
    ),
    _QuickItem(
      label: 'Outings',
      subtitle: 'Requests & status',
      icon: Icons.directions_walk_rounded,
      accent: _orange,
      action: 'outings',
    ),
    _QuickItem(
      label: 'Mentor',
      subtitle: 'Contact details',
      icon: Icons.person_outline_rounded,
      accent: _green,
      action: 'mentor',
    ),
    _QuickItem(
      label: 'Biometric',
      subtitle: 'Entry & exit logs',
      icon: Icons.fingerprint_rounded,
      accent: _navy,
      action: 'biometric',
    ),
    _QuickItem(
      label: 'Payments',
      subtitle: 'Dues & receipts',
      icon: Icons.account_balance_wallet_outlined,
      accent: _orange,
      action: 'payments',
    ),
    _QuickItem(
      label: 'Courses',
      subtitle: 'Course information',
      icon: Icons.menu_book_outlined,
      accent: _blue,
      action: 'courses',
    ),
    _QuickItem(
      label: 'Assignments',
      subtitle: 'Upcoming work',
      icon: Icons.assignment_outlined,
      accent: _green,
      action: 'assignments',
    ),
    _QuickItem(
      label: 'VTOP',
      subtitle: 'Open portal',
      icon: Icons.open_in_new_rounded,
      accent: _navy,
      action: 'direct_vtop',
    ),
  ];

  Future<void> _handleQuickTap(
    _QuickItem item,
    Map<String, dynamic> data,
    AuthState authState,
  ) async {
    if (!mounted) return;

    late Widget targetScreen;

    switch (item.action) {
      case 'grades':
        targetScreen = GradesScreen(
          initialData: data['grade_history'] as Map<String, dynamic>?,
        );
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
        pageBuilder: (_, animation, _) => targetScreen,
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

    final profile =
        data['profile'] as Map<String, dynamic>? ?? {};

    final studentName =
        profile['student_name'] ??
        authState.username ??
        'Student';

    final timetable =
        data['timetable'] as Map<String, dynamic>? ?? {};

    final today =
        DateFormat('EEEE').format(DateTime.now());

    final rawTodayClasses =
        timetable[today] as List<dynamic>? ?? [];

    final todayClasses =
        VtopHelpers.sortTimetableList(rawTodayClasses);

    final classStatus =
        VtopHelpers.getLiveClassStatus(todayClasses);

    final activeClass =
        classStatus['activeClass'] as Map<String, dynamic>?;

    final nextClasses =
        classStatus['nextClasses'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            40,
          ),
          children: [
            _buildHeader(
              authState,
              studentName,
            ),

            const SizedBox(height: 12),

            _buildDateStrip(),

              const SizedBox(height: 18),

              // ======================================================
              // HERO / CURRENT STATUS
              // ======================================================

              if (activeClass != null)
                _buildActiveClass(activeClass)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(
                      begin: 0.04,
                      end: 0,
                      curve: Curves.easeOutCubic,
                    )
              else
                _buildFreeState(nextClasses)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(
                      begin: 0.04,
                      end: 0,
                      curve: Curves.easeOutCubic,
                    ),

              const SizedBox(height: 28),

              // ======================================================
              // TODAY'S SCHEDULE
              // ======================================================

              _buildSectionTitle(
                title: 'TODAY',
                subtitle: '${todayClasses.length} classes',
              ),

              const SizedBox(height: 12),

              _buildScheduleTimeline(todayClasses),

              const SizedBox(height: 30),

              // ======================================================
              // QUICK ACCESS
              // ======================================================

              _buildSectionTitle(
                title: 'CAMPUS',
                subtitle: 'Quick access',
              ),

              const SizedBox(height: 12),

              _buildQuickActions(
                data,
                authState,
              ),

              const SizedBox(height: 30),

              _buildFooter(),
            ],
          ),
        ),
      );
    }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(
    AuthState authState,
    String studentName,
  ) {
    final firstName =
        studentName.split(' ').first;

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
            crossAxisAlignment:
                CrossAxisAlignment.start,
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
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ProfileScreen(),
              ),
            );
          },
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _paperBright,
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
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _ink,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Container(
            height: 1,
            color: _line,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          subtitle,
          style: GoogleFonts.dmSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: _inkMuted,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ACTIVE CLASS
  // ============================================================

  Widget _buildActiveClass(
    Map<String, dynamic> item,
  ) {
    final isLab = VtopHelpers.isLabCourse(
      courseType: item['course_type']?.toString(),
      courseSlot: item['slot']?.toString(),
    );

    return Container(
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -35,
            top: -35,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _orange.withValues(alpha: 0.14),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                          const BoxDecoration(
                        color: _green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'HAPPENING NOW',
                      style:
                          GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w800,
                        color: Colors.white
                            .withValues(alpha: .72),
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    _typeBadge(
                      isLab ? 'LAB' : 'THEORY',
                      dark: true,
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                Text(
                  item['course_name'] ??
                      'Class in Session',
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.08,
                    letterSpacing: -0.7,
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    _infoItem(
                      Icons.schedule_rounded,
                      item['time'] ?? '',
                      dark: true,
                    ),
                    const SizedBox(width: 18),
                    _infoItem(
                      Icons.location_on_outlined,
                      item['venue'] ?? 'TBA',
                      dark: true,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Container(
                  height: 1,
                  color: Colors.white
                      .withValues(alpha: .12),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Text(
                      item['slot'] ??
                          'CURRENT SLOT',
                      style:
                          GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w800,
                        color: _orange,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white54,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FREE STATE
  // ============================================================

  Widget _buildFreeState(
    List<dynamic> nextClasses,
  ) {
    final nextClass =
        nextClasses.isNotEmpty
            ? nextClasses.first
            : null;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _paperBright,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _line,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      _green.withValues(alpha: .10),
                  borderRadius:
                      BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration:
                          const BoxDecoration(
                        color: _green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'FREE NOW',
                      style:
                          GoogleFonts.spaceGrotesk(
                        fontSize: 9,
                        fontWeight:
                            FontWeight.w800,
                        color: _green,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.free_breakfast_outlined,
                color: _inkMuted,
                size: 22,
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            nextClass != null
                ? 'You have some breathing room.'
                : 'That’s a wrap for today.',
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _ink,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            nextClass != null
                ? 'Your next class is ${nextClass['course_name'] ?? 'up next'}.'
                : 'No more classes are scheduled today.',
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              height: 1.45,
              color: _inkSoft,
            ),
          ),

          if (nextClass != null) ...[
            const SizedBox(height: 18),
            Container(
              padding:
                  const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: _cream,
                borderRadius:
                    BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Text(
                    nextClass['time']
                            ?.toString()
                            .split('-')
                            .first
                            .trim() ??
                        '',
                    style:
                        GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 1,
                    height: 24,
                    color: _line,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      nextClass['course_name'] ??
                          'Next Class',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: _inkMuted,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // TIMELINE
  // ============================================================

  Widget _buildScheduleTimeline(
    List<dynamic> classes,
  ) {
    if (classes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _paperBright,
          borderRadius:
              BorderRadius.circular(20),
          border: Border.all(
            color: _line,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.event_available_rounded,
              color: _green,
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              'No classes scheduled today.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _inkSoft,
              ),
            ),
          ],
        ),
      );
    }

    final visibleClasses =
        _isScheduleExpanded
            ? classes
            : classes.take(4).toList();

    return Column(
      children: [
        ...visibleClasses
            .asMap()
            .entries
            .map(
              (entry) => _buildTimelineItem(
                entry.value,
                entry.key,
                visibleClasses.length,
              ),
            ),

        if (classes.length > 4)
          const SizedBox(height: 5),

        if (classes.length > 4)
          GestureDetector(
            onTap: () {
              setState(() {
                _isScheduleExpanded =
                    !_isScheduleExpanded;
              });
            },
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: _paperBright,
                borderRadius:
                    BorderRadius.circular(15),
                border: Border.all(
                  color: _line,
                ),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Text(
                    _isScheduleExpanded
                        ? 'SHOW LESS'
                        : 'SHOW ALL ${classes.length} CLASSES',
                    style:
                        GoogleFonts.spaceGrotesk(
                      fontSize: 9.5,
                      fontWeight:
                          FontWeight.w800,
                      color: _navy,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    _isScheduleExpanded
                        ? Icons
                            .keyboard_arrow_up_rounded
                        : Icons
                            .keyboard_arrow_down_rounded,
                    size: 17,
                    color: _navy,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTimelineItem(
    dynamic item,
    int index,
    int total,
  ) {
    final isLab = VtopHelpers.isLabCourse(
      courseType: item['course_type']?.toString(),
      courseSlot: item['slot']?.toString(),
    );

    final accent =
        isLab ? _orange : _blue;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 57,
            child: Column(
              children: [
                Text(
                  item['time']
                          ?.toString()
                          .split('-')
                          .first
                          .trim() ??
                      '--',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w800,
                    color: _inkSoft,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    width: 1,
                    color: index == total - 1
                        ? Colors.transparent
                        : _line,
                  ),
                ),
              ],
            ),
          ),

          Container(
            width: 9,
            margin:
                const EdgeInsets.only(
              top: 2,
              right: 12,
            ),
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              border: Border.all(
                color: _paper,
                width: 2,
              ),
            ),
          ),

          Expanded(
            child: Container(
              margin:
                  const EdgeInsets.only(
                bottom: 10,
              ),
              padding:
                  const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _paperBright,
                borderRadius:
                    BorderRadius.circular(17),
                border: Border.all(
                  color: _line,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              item['slot'] ?? '',
                              style:
                                  GoogleFonts.spaceGrotesk(
                                fontSize: 9,
                                fontWeight:
                                    FontWeight.w800,
                                color: accent,
                                letterSpacing:
                                    .8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _typeBadge(
                              isLab
                                  ? 'LAB'
                                  : 'THEORY',
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item['course_name'] ??
                              'Class',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons
                                  .location_on_outlined,
                              size: 13,
                              color: _inkMuted,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                item['venue'] ??
                                    'TBA',
                                maxLines: 1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    GoogleFonts.dmSans(
                                  fontSize: 10.5,
                                  fontWeight:
                                      FontWeight.w600,
                                  color:
                                      _inkMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _inkMuted,
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions(
    Map<String, dynamic> data,
    AuthState authState,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount: _quickAccessItems.length,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) {
        final item =
            _quickAccessItems[index];

        return _buildQuickAction(
          item,
          data,
          authState,
          index,
        );
      },
    );
  }

  Widget _buildQuickAction(
    _QuickItem item,
    Map<String, dynamic> data,
    AuthState authState,
    int index,
  ) {
    return GestureDetector(
      onTap: () => _handleQuickTap(
        item,
        data,
        authState,
      ),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _paperBright,
          borderRadius:
              BorderRadius.circular(18),
          border: Border.all(
            color: _line,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    item.accent.withValues(alpha: .10),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Icon(
                item.icon,
                color: item.accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      fontWeight:
                          FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 9.5,
                      fontWeight:
                          FontWeight.w500,
                      color: _inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_outward_rounded,
              size: 15,
              color: _inkMuted,
            ),
          ],
        ),
      ),
    )
        .animate(
          delay: (35 * index).ms,
        )
        .fadeIn(duration: 300.ms)
        .slideY(
          begin: .08,
          end: 0,
          curve: Curves.easeOutCubic,
        );
  }

  // ============================================================
  // SMALL COMPONENTS
  // ============================================================

  Widget _typeBadge(
    String text, {
    bool dark = false,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: .10)
            : _cream,
        borderRadius:
            BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 7.5,
          fontWeight: FontWeight.w800,
          color: dark
              ? Colors.white70
              : _inkSoft,
          letterSpacing: .8,
        ),
      ),
    );
  }

  Widget _infoItem(
    IconData icon,
    String text, {
    bool dark = false,
  }) {
    return Flexible(
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: dark
                ? Colors.white54
                : _inkMuted,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 10.5,
                fontWeight:
                    FontWeight.w600,
                color: dark
                    ? Colors.white70
                    : _inkSoft,
              ),
            ),
          ),
        ],
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
}

// ============================================================
// QUICK ACTION MODEL
// ============================================================

class _QuickItem {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String? action;

  const _QuickItem({
    required this.label,
    required this.subtitle,
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
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color:
                    _DashboardStateStatic.red
                        .withValues(alpha: .10),
                borderRadius:
                    BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.sync_problem_rounded,
                color:
                    _DashboardStateStatic.red,
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
                color:
                    _DashboardStateStatic.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                height: 1.45,
                color:
                    _DashboardStateStatic.muted,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _DashboardStateStatic.navy,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(
                Icons.refresh_rounded,
                size: 17,
              ),
              label: Text(
                'TRY AGAIN',
                style:
                    GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w800,
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

// ============================================================
// STATIC COLORS FOR STATELESS WIDGETS
// ============================================================

class _DashboardStateStatic {
  static const Color navy =
      Color(0xFF172B4D);

  static const Color ink =
      Color(0xFF17202A);

  static const Color muted =
      Color(0xFF8A929A);

  static const Color red =
      Color(0xFFD94B4B);
}

