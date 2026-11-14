import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../providers/vtop_providers.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/attendance_calculator.dart';
import '../utils/vtop_helpers.dart';
import 'grades_screen.dart';
import 'marks_screen.dart';
import 'outings_screen.dart';
import 'mentor_screen.dart';
import 'biometric_screen.dart';
import 'payments_screen.dart';
import 'courses_screen.dart';
import 'assignments_screen.dart';
import 'vtop_webview_screen.dart';
import 'profile_screen.dart';
import 'exam_schedule.dart';
import 'faculty_screen.dart';
import 'cgpa_calculator_screen.dart';
import 'academic_calendar_screen.dart';
import '../widgets/command_palette_modal.dart';
import '../widgets/motion/nexus_motion.dart';
import '../widgets/motion/nexus_illustrations.dart';

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
  bool _isCompletedExpanded = false;
  bool _isQuickAccessExpanded = false;
  bool _isNextDayPreviewOpen = false;
  String? _manualKey;
  String? _lastDefaultKey;
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
  // EDITORIAL CAMPUS THEME (Zero-Neon, Dynamic Dark/Light Slate)
  // ============================================================
  AppPalette get _palette => AppPalette.of(context);
  Color get _paper => _palette.paper;
  Color get _surface => _palette.surface;
  Color get _ink => _palette.ink;
  Color get _inkSoft => _palette.inkSoft;
  Color get _inkMuted => _palette.inkMuted;

  Color get _navy => _palette.navy;
  Color get _blue => _palette.blue;
  Color get _orange => _palette.orange;
  Color get _green => _palette.green;
  Color get _line => _palette.line;
  Color get _soft => _palette.soft;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  // Quick Access items with Assignments and spacious 4-column layout
  List<_QuickItem> _getQuickAccessItems() {
    return [
      _QuickItem(
        label: 'Exams',
        icon: Icons.event_note_rounded,
        accent: _orange,
        action: 'exams',
      ),
      _QuickItem(
        label: 'Course Page',
        icon: Icons.auto_stories_rounded,
        accent: _blue,
        action: 'courses',
      ),
      _QuickItem(
        label: 'Assignments',
        icon: Icons.assignment_turned_in_rounded,
        accent: _orange,
        action: 'assignments',
      ),
      _QuickItem(
        label: 'Faculty',
        icon: Icons.badge_outlined,
        accent: _navy,
        action: 'faculty',
      ),
      _QuickItem(
        label: 'Profile',
        icon: Icons.person_rounded,
        accent: _navy,
        action: 'profile',
      ),
      _QuickItem(
        label: 'Calendar',
        icon: Icons.calendar_month_rounded,
        accent: _blue,
        action: 'calendar',
      ),
      _QuickItem(
        label: 'CGPA Plan',
        icon: Icons.calculate_rounded,
        accent: _green,
        action: 'cgpa_planner',
      ),
      _QuickItem(
        label: 'Mentor',
        icon: Icons.school_outlined,
        accent: _green,
        action: 'mentor',
      ),
      _QuickItem(
        label: 'Biometric',
        icon: Icons.fingerprint_rounded,
        accent: _blue,
        action: 'biometric',
      ),
      _QuickItem(
        label: 'Outing',
        icon: Icons.directions_walk_rounded,
        accent: _orange,
        action: 'outings',
      ),
      _QuickItem(
        label: 'Grades',
        icon: Icons.bar_chart_rounded,
        accent: _navy,
        action: 'grades',
      ),
      _QuickItem(
        label: 'Payments',
        icon: Icons.account_balance_wallet_outlined,
        accent: _green,
        action: 'payments',
      ),
      _QuickItem(
        label: 'VTOP Portal',
        icon: Icons.language_rounded,
        accent: _navy,
        action: 'direct_vtop',
      ),
    ];
  }

  Future<void> _handleQuickTap(
    _QuickItem item,
    Map<String, dynamic> data,
    AuthState authState,
  ) async {
    if (!mounted) return;

    if (item.action == '__toggle_more__') {
      setState(() => _isQuickAccessExpanded = true);
      return;
    }

    if (item.action == '__toggle_less__') {
      setState(() => _isQuickAccessExpanded = false);
      return;
    }

    if (item.action == 'calendar') {
      _navigateScreen(const AcademicCalendarScreen());
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

    if (item.action == 'profile') {
      _navigateScreen(const ProfileScreen());
      return;
    }

    late Widget targetScreen;

    switch (item.action) {
      case 'faculty':
        targetScreen = const FacultyScreen();
        break;

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

      case 'cgpa_planner':
        targetScreen = const CgpaCalculatorScreen();
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final dashboardState = ref.watch(dashboardProvider);
    final profileAsync = ref.watch(profileProvider);
    final timetableAsync = ref.watch(timetableProvider);
    final attendanceAsync = ref.watch(attendanceProvider);
    final marksAsync = ref.watch(marksProvider);

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

    final memTimetable = StorageService.getMemoryCache('timetable');
    final memAttendance = StorageService.getMemoryCache('attendance');
    final memProfile = StorageService.getMemoryCache('profile');
    final hasOfflineCache = memTimetable != null || memAttendance != null || memProfile != null || (timetableAsync.valueOrNull != null && timetableAsync.valueOrNull!.isNotEmpty);

    if (!dashboardState.hasData && !hasOfflineCache) {
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
    final profile = (profileAsync.valueOrNull != null && profileAsync.valueOrNull!.isNotEmpty)
        ? profileAsync.valueOrNull!
        : (data['profile'] as Map<String, dynamic>? ??
           (StorageService.getMemoryCache('profile') as Map<String, dynamic>? ?? {}));
    final rawStudentName = profile['student_name']?.toString() ??
                           profile['name']?.toString() ??
                           authState.username ??
                           'Student';
    final callingName = VtopHelpers.extractCallingName(rawStudentName, authState.username);

    final timetable = (timetableAsync.valueOrNull != null && timetableAsync.valueOrNull!.isNotEmpty)
        ? timetableAsync.valueOrNull!
        : ((data['timetable'] as Map<String, dynamic>?) ??
           (StorageService.getMemoryCache('timetable') as Map<String, dynamic>? ?? {}));
    final List<dynamic> attendanceList =
        (attendanceAsync.valueOrNull != null && attendanceAsync.valueOrNull!.isNotEmpty)
            ? attendanceAsync.valueOrNull!
            : ((data['attendance'] as List<dynamic>?) ??
               (StorageService.getMemoryCache('attendance') as List<dynamic>? ?? const <dynamic>[]));
    final List<dynamic> marksList =
        (marksAsync.valueOrNull != null && marksAsync.valueOrNull!.isNotEmpty)
            ? marksAsync.valueOrNull!
            : ((data['marks'] as List<dynamic>?) ??
               (StorageService.getMemoryCache('marks') as List<dynamic>? ?? const <dynamic>[]));
    final now = DateTime.now();
    final bool hasTimetable = timetable.isNotEmpty;
    final List<ClassOccurrence> todayOccurrences = hasTimetable
        ? VtopHelpers.classesOn(timetable, now)
        : const <ClassOccurrence>[];
    final int remainingCount = todayOccurrences
        .where((c) => c.phaseAt(now) != ClassPhase.completed)
        .length;
    final bool hasLive = todayOccurrences
        .any((c) => c.phaseAt(now) == ClassPhase.ongoing);

    final base64Pfp = profile['base64_pfp']?.toString() ??
        profile['photo']?.toString() ??
        profile['picture']?.toString() ??
        profile['profile_image']?.toString();
    final mentor = profile['mentor_details'] as Map<String, dynamic>?;
    final mentorPfp = mentor?['base64_pfp']?.toString();
    final safeBase64Pfp = (base64Pfp != null && mentorPfp != null && base64Pfp == mentorPfp)
        ? null
        : base64Pfp;

    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: RefreshIndicator(
          color: _blue,
          backgroundColor: _surface,
          onRefresh: () async {
            try {
              await ref.read(dashboardProvider.notifier).syncAll(isUserInitiated: true);
              ref.invalidate(profileProvider);
              ref.invalidate(timetableProvider);
              ref.invalidate(attendanceProvider);
              ref.invalidate(marksProvider);
              ref.invalidate(gradesProvider);
              ref.invalidate(examScheduleProvider);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Could not reach VTOP. Showing cached data.',
                      style: GoogleFonts.dmSans(color: Colors.white, fontSize: 12),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
            children: [
              // 1. Header & Profile
              _buildHeader(authState, callingName, safeBase64Pfp),

              const SizedBox(height: 12),

              // 2. Date Strip
              _buildDateStrip(),

              const SizedBox(height: 20),

              // ======================================================
              // TODAY'S TIMETABLE / SCHEDULE SECTION
              // Matches TodayScheduleStack + TodayClassCountBadge
              // ======================================================
              _buildTodayHeader(
                remainingCount,
                todayOccurrences.length,
                hasTimetable: hasTimetable,
                hasLive: hasLive,
              ),

              const SizedBox(height: 12),

              _buildTodayScheduleStack(
                now,
                todayOccurrences,
                timetable: timetable,
                attendanceList: attendanceList,
                marksList: marksList,
                hasTimetable: hasTimetable,
                isTimetableSyncing:
                    timetableAsync.isLoading || dashboardState.isSyncing,
              )
                  .animate()
                  .fadeIn(duration: 380.ms)
                  .slideY(
                    begin: 0.03,
                    end: 0,
                    curve: Curves.easeOutCubic,
                  ),

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
  Widget _buildHeader(AuthState authState, String studentName, String? base64Pfp) {
    final firstName = studentName.split(' ').first;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo block (untinted with clean rounded corners)
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _line),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.asset(
              'assets/images/vitap_nexus_logo.png',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) {
                return Icon(
                  Icons.school_rounded,
                  color: _navy,
                  size: 26,
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

        // Universal Campus Command Search Button
        Semantics(
          button: true,
          label: 'Open Campus Command Search and Quick Launcher',
          child: Tooltip(
            message: 'Search Destinations (Ctrl+K)',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  HapticFeedback.selectionClick();
                  NexusCommandPaletteModal.show(context);
                },
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _line),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.search_rounded,
                      color: _ink,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Profile icon / Avatar
        _NexusDashboardAvatar(
          base64Pfp: base64Pfp,
          surface: _surface,
          line: _line,
          navy: _navy,
          onTap: () {
            _navigateScreen(const ProfileScreen());
          },
        ),
      ],
    );
  }

  // ============================================================
  // DATE STRIP + LIVE SYNC PILL
  // ============================================================
  Widget _buildDateStrip() {
    final now = DateTime.now();
    final dashState = ref.watch(dashboardProvider);
    final isSyncing = dashState.isSyncing;
    final lastSynced = dashState.lastSynced ?? StorageService.getMemoryTimestamp('all_data');

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
        Expanded(
          child: Text(
            DateFormat('d MMMM yyyy').format(now),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _inkSoft,
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: isSyncing
              ? null
              : () async {
                  HapticFeedback.selectionClick();
                  final messenger = ScaffoldMessenger.of(context);
                  await ref.read(dashboardProvider.notifier).syncAll(isUserInitiated: true);
                  if (!mounted) return;
                  final after = ref.read(dashboardProvider);
                  if (after.syncStatus == SyncStatus.success) {
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: _green,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                        content: Text(
                          'All data synced with VTOP!',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }
                },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSyncing ? _blue.withValues(alpha: 0.12) : _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSyncing ? _blue.withValues(alpha: 0.35) : _line,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSyncing)
                  SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      valueColor: AlwaysStoppedAnimation<Color>(_blue),
                    ),
                  )
                else
                  Icon(
                    Icons.sync_rounded,
                    size: 13,
                    color: _navy,
                  ),
                const SizedBox(width: 5),
                Text(
                  isSyncing
                      ? 'SYNCING...'
                      : (lastSynced != null
                          ? 'SYNC • ${StorageService.formatLastSynced(lastSynced).toUpperCase()}'
                          : 'SYNC NOW'),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: isSyncing ? _blue : _inkSoft,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }



  // ============================================================
  // TODAY SCHEDULE HEADER (Matches TodayClassCountBadge)
  // ============================================================
  Widget _buildTodayHeader(
    int remainingCount,
    int totalClasses, {
    required bool hasTimetable,
    bool hasLive = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
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
            if (hasLive) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimeRadarWave(color: _green, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: _green,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        if (hasTimetable && totalClasses > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _line),
            ),
            child: Text(
              remainingCount == 0 ? 'Done' : '$remainingCount left',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _inkSoft,
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // ACADEMIC INTELLIGENCE HELPERS (Cross-reference Course Data)
  // ============================================================
  Map<String, dynamic>? _matchCourseAttendance(
    ClassOccurrence occurrence,
    List<dynamic> attendanceList,
  ) {
    final code = occurrence.courseCode.trim().toUpperCase();
    if (code.isEmpty || attendanceList.isEmpty) return null;
    final occIsLab = VtopHelpers.isLabCourse(
      courseType: occurrence.courseType,
      courseSlot: occurrence.slot,
    );

    Map<String, dynamic>? fallback;
    for (final raw in attendanceList) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final itemCode = (item['course_code'] ?? '').toString().trim().toUpperCase();
      if (itemCode != code) continue;
      fallback ??= item;
      final itemIsLab = VtopHelpers.isLabCourse(
        courseType: item['course_type']?.toString(),
        courseSlot: item['course_slot']?.toString(),
        courseTypeCode: item['course_type_code']?.toString(),
      );
      if (itemIsLab == occIsLab) {
        return item;
      }
    }
    return fallback;
  }

  Map<String, dynamic>? _matchCourseMarks(
    ClassOccurrence occurrence,
    List<dynamic> marksList,
  ) {
    final code = occurrence.courseCode.trim().toUpperCase();
    if (code.isEmpty || marksList.isEmpty) return null;
    final occIsLab = VtopHelpers.isLabCourse(
      courseType: occurrence.courseType,
      courseSlot: occurrence.slot,
    );

    Map<String, dynamic>? fallback;
    for (final raw in marksList) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final itemCode = (item['course_code'] ?? '').toString().trim().toUpperCase();
      if (itemCode != code) continue;
      fallback ??= item;
      final itemIsLab = VtopHelpers.isLabCourse(
        courseType: item['course_type']?.toString(),
        courseSlot: item['slot']?.toString(),
      );
      if (itemIsLab == occIsLab) {
        return item;
      }
    }
    return fallback;
  }

  ({DateTime date, List<ClassOccurrence> classes})? _findNextScheduledDay(
    Map<String, dynamic> timetable,
    DateTime fromDate,
  ) {
    if (timetable.isEmpty) return null;
    for (int offset = 1; offset <= 7; offset++) {
      final candidate = fromDate.add(Duration(days: offset));
      final classes = VtopHelpers.classesOn(timetable, candidate);
      if (classes.isNotEmpty) {
        return (date: candidate, classes: classes);
      }
    }
    return null;
  }

  // ============================================================
  // TODAY SCHEDULE STACK (Matches TodayScheduleStack + Intelligence)
  // ============================================================
  Widget _buildTodayScheduleStack(
    DateTime now,
    List<ClassOccurrence> today, {
    required Map<String, dynamic> timetable,
    required List<dynamic> attendanceList,
    required List<dynamic> marksList,
    required bool hasTimetable,
    required bool isTimetableSyncing,
  }) {
    if (!hasTimetable) {
      return _buildNoTimetableCard(isTimetableSyncing);
    }

    final nextDayInfo = _findNextScheduledDay(timetable, now);

    if (today.isEmpty) {
      return _buildNoMoreClassesCard(
        primaryText: 'No classes today',
        secondaryText: 'Seems like a day off 😪',
        nextDayInfo: nextDayInfo,
        attendanceList: attendanceList,
        marksList: marksList,
        now: now,
      );
    }

    final List<ClassOccurrence> completed = today
        .where((c) => c.phaseAt(now) == ClassPhase.completed)
        .toList();
    final List<ClassOccurrence> remaining = today
        .where((c) => c.phaseAt(now) != ClassPhase.completed)
        .toList();

    if (remaining.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCompletedClassesGroup(
            completed: completed,
            attendanceList: attendanceList,
            marksList: marksList,
            now: now,
            suffix: 'done today',
          ),
          const SizedBox(height: 8),
          _buildNoMoreClassesCard(
            primaryText: 'No more classes for the day',
            secondaryText: 'Time to rest 😪',
            nextDayInfo: nextDayInfo,
            attendanceList: attendanceList,
            marksList: marksList,
            now: now,
          ),
        ],
      );
    }

    // The open card is the class in progress, or the next one to start.
    final ClassOccurrence defaultOpen = remaining.firstWhere(
      (c) => c.phaseAt(now) == ClassPhase.ongoing,
      orElse: () => remaining.first,
    );
    if (_lastDefaultKey != defaultOpen.key) {
      _lastDefaultKey = defaultOpen.key;
      _manualKey = null;
    }

    final bool manualStillScheduled = remaining.any(
      (c) => c.key == _manualKey,
    );
    final String openKey = manualStillScheduled ? _manualKey! : defaultOpen.key;

    final stackChildren = <Widget>[
      if (completed.isNotEmpty)
        _buildCompletedClassesGroup(
          completed: completed,
          attendanceList: attendanceList,
          marksList: marksList,
          now: now,
          suffix: 'done earlier',
        ),
      for (final ClassOccurrence occurrence in remaining)
        KeyedSubtree(
          key: ValueKey<String>(occurrence.key),
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 380),
            alignment: Alignment.topCenter,
            sizeCurve: Curves.easeInOutQuint,
            firstCurve: Curves.easeInOutQuint,
            secondCurve: Curves.easeInOutQuint,
            crossFadeState: occurrence.key == openKey
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: _buildExpandedClassCard(
              occurrence,
              now,
              attendanceList: attendanceList,
              marksList: marksList,
            ),
            secondChild: _buildCollapsedClassStrip(
              occurrence,
              now,
              attendanceList: attendanceList,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _manualKey = occurrence.key);
              },
            ),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < stackChildren.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == stackChildren.length - 1 ? 0 : 8,
            ),
            child: stackChildren[i],
          ),
      ],
    );
  }

  // ============================================================
  // EXPANDED CLASS CARD (Matches ExpandedClassCard + Subtle Intelligence)
  // ============================================================
  Widget _buildExpandedClassCard(
    ClassOccurrence occurrence,
    DateTime now, {
    required List<dynamic> attendanceList,
    required List<dynamic> marksList,
  }) {
    final ClassPhase phase = occurrence.phaseAt(now);
    final bool isOngoing = phase == ClassPhase.ongoing;

    final Color background = isOngoing
        ? (_palette.isDark
            ? const Color(0xFF172554)
            : const Color(0xFFE0ECFF))
        : _surface;
    final Color foreground = isOngoing
        ? (_palette.isDark
            ? const Color(0xFFEFF6FF)
            : const Color(0xFF0F172A))
        : _ink;
    final Color muted = isOngoing
        ? foreground.withValues(alpha: 0.72)
        : _inkSoft;
    final Color borderColor = isOngoing
        ? _blue.withValues(alpha: 0.35)
        : _line;

    final String overline = <String>[
      occurrence.courseCode,
      occurrence.courseType,
      if (occurrence.slot.isNotEmpty) occurrence.slot,
    ].where((s) => s.trim().isNotEmpty).join(' · ');

    final String venue = occurrence.venue;
    final String time = VtopHelpers.formatTimeRange(
      occurrence.startTime,
      occurrence.endTime,
    );
    final List<String> metaParts = <String>[
      if (venue.isNotEmpty) venue,
      if (time.isNotEmpty) time,
    ];

    final double? progress = occurrence.progressAt(now);
    final Duration? remaining = occurrence.remainingAt(now);

    final attMatch = _matchCourseAttendance(occurrence, attendanceList);
    Widget? attendancePill;
    if (attMatch != null) {
      final int attended =
          int.tryParse((attMatch['attended_classes'] ?? '0').toString()) ?? 0;
      final int total =
          int.tryParse((attMatch['total_classes'] ?? '0').toString()) ?? 0;
      if (total > 0) {
        final double pct = double.tryParse(
              (attMatch['attendance_percentage'] ?? '')
                  .toString()
                  .replaceAll('%', '')
                  .trim(),
            ) ??
            ((attended / total) * 100);
        final bunkStats = AttendanceCalculator.calculateBunkStats(
          attended,
          total,
          target: 75.0,
        );
        final bool canBunk = bunkStats['canBunk'] == true;
        final int count = (bunkStats['count'] as int?) ?? 0;
        final Color tone = pct >= 80
            ? _green
            : (pct >= 75 ? _blue : _orange);
        final String bufferText = canBunk
            ? (count > 0 ? 'Safe · +$count buffer' : 'At 75% boundary')
            : 'Attend next $count for 75%';

        attendancePill = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isOngoing
                ? foreground.withValues(alpha: 0.1)
                : tone.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isOngoing
                  ? foreground.withValues(alpha: 0.18)
                  : tone.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: tone,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${pct.toStringAsFixed(0)}%  ·  $bufferText',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isOngoing ? foreground : tone,
                ),
              ),
            ],
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor, width: isOngoing ? 1.4 : 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            HapticFeedback.selectionClick();
            _showClassDetailBottomSheet(
              occurrence,
              attendanceList: attendanceList,
              marksList: marksList,
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        overline.isEmpty ? 'CLASS' : overline.toUpperCase(),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11.5,
                          color: muted,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildStatusPill(occurrence, now),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  occurrence.courseName.isEmpty
                      ? 'Class'
                      : occurrence.courseName,
                  style: GoogleFonts.dmSans(
                    fontSize: 21,
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (metaParts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 16, color: muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          metaParts.join('  ·  '),
                          style: GoogleFonts.dmSans(
                            fontSize: 13.5,
                            color: muted,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (attendancePill != null) ...[
                  const SizedBox(height: 12),
                  attendancePill,
                ],
                if (isOngoing) ...[
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      tween: Tween<double>(begin: 0, end: progress ?? 0),
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: progress == null ? null : value,
                        minHeight: 6,
                        backgroundColor: foreground.withValues(alpha: 0.18),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _palette.isDark ? _blue : _navy,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          remaining == null
                              ? 'In progress'
                              : '${VtopHelpers.formatShortDuration(remaining)} left',
                          style: GoogleFonts.dmSans(
                            fontSize: 13.5,
                            color: foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        'ends ${VtopHelpers.formatTo12Hour(occurrence.endTime)}',
                        style: GoogleFonts.dmSans(
                          fontSize: 12.5,
                          color: muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(ClassOccurrence occurrence, DateTime now) {
    final ClassPhase phase = occurrence.phaseAt(now);
    late final String label;
    late final Color bg;
    late final Color fg;

    switch (phase) {
      case ClassPhase.ongoing:
        label = 'NOW';
        bg = _blue;
        fg = Colors.white;
        break;
      case ClassPhase.completed:
        label = 'DONE';
        bg = _soft;
        fg = _inkSoft;
        break;
      case ClassPhase.upcoming:
        final until = occurrence.startsInAt(now);
        label = until == null
            ? 'SCHEDULED'
            : 'IN ${VtopHelpers.formatShortDuration(until).toUpperCase()}';
        bg = _palette.isDark
            ? _blue.withValues(alpha: 0.18)
            : _navy.withValues(alpha: 0.1);
        fg = _palette.isDark ? _blue : _navy;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 10.5,
          color: fg,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  // ============================================================
  // COLLAPSED CLASS STRIP (Matches CollapsedClassStrip + Subtle Attendance)
  // ============================================================
  Widget _buildCollapsedClassStrip(
    ClassOccurrence occurrence,
    DateTime now, {
    required List<dynamic> attendanceList,
    required VoidCallback onTap,
    bool dimmed = false,
  }) {
    final ClassPhase phase = occurrence.phaseAt(now);
    final bool isOngoing = phase == ClassPhase.ongoing;
    final bool isCompleted = phase == ClassPhase.completed;
    final String venue = occurrence.venue;

    final attMatch = _matchCourseAttendance(occurrence, attendanceList);
    double? attPct;
    if (attMatch != null) {
      final int attended =
          int.tryParse((attMatch['attended_classes'] ?? '0').toString()) ?? 0;
      final int total =
          int.tryParse((attMatch['total_classes'] ?? '0').toString()) ?? 0;
      if (total > 0) {
        attPct = double.tryParse(
              (attMatch['attendance_percentage'] ?? '')
                  .toString()
                  .replaceAll('%', '')
                  .trim(),
            ) ??
            ((attended / total) * 100);
      }
    }

    final Widget strip = Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              onTap: onTap,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              horizontalTitleGap: 8,
              minLeadingWidth: 74,
              leading: SizedBox(
                width: 74,
                child: Text(
                  VtopHelpers.formatTo12Hour(occurrence.startTime),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12.5,
                    color: isOngoing ? _blue : _inkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              title: Text(
                occurrence.courseName.isEmpty ? 'Class' : occurrence.courseName,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: dimmed ? _inkSoft : _ink,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: isCompleted
                  ? Icon(Icons.check_rounded, size: 18, color: _inkSoft)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (attPct != null && !dimmed) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (attPct >= 75 ? _green : _orange)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${attPct.toStringAsFixed(0)}%',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: attPct >= 75 ? _green : _orange,
                              ),
                            ),
                          ),
                          if (venue.isNotEmpty) const SizedBox(width: 8),
                        ],
                        if (venue.isNotEmpty)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 82),
                            child: Text(
                              venue,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 11.5,
                                color: _inkSoft,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                      ],
                    ),
            ),
            if (isOngoing)
              LinearProgressIndicator(
                value: occurrence.progressAt(now),
                minHeight: 3,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(_blue),
              ),
          ],
        ),
      ),
    );

    return dimmed ? Opacity(opacity: 0.62, child: strip) : strip;
  }

  // ============================================================
  // COMPLETED CLASSES GROUP (Matches CompletedClassesGroup)
  // ============================================================
  Widget _buildCompletedClassesGroup({
    required List<ClassOccurrence> completed,
    required List<dynamic> attendanceList,
    required List<dynamic> marksList,
    required DateTime now,
    String suffix = 'done earlier',
  }) {
    final int count = completed.length;

    return AnimatedSize(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubicEmphasized,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isCompletedExpanded = !_isCompletedExpanded);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: _inkSoft,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$count $suffix',
                          style: GoogleFonts.dmSans(
                            fontSize: 13.5,
                            color: _inkSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _isCompletedExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: _inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isCompletedExpanded)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final ClassOccurrence occurrence in completed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildCollapsedClassStrip(
                        occurrence,
                        now,
                        attendanceList: attendanceList,
                        dimmed: true,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _showClassDetailBottomSheet(
                            occurrence,
                            attendanceList: attendanceList,
                            marksList: marksList,
                          );
                        },
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
  // PLACEHOLDERS (NoTimetableCard & NoMoreClassesCard + Next Day Preview)
  // ============================================================
  Widget _buildNoTimetableCard(bool isLoading) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NexusIllustration(kind: NexusIllo.rest, size: 132),
          const SizedBox(height: 4),
          Text(
            'No timetable yet',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              color: _ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sync it to see your day here',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: _inkSoft,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: _soft,
              foregroundColor: _navy,
            ),
            onPressed: isLoading
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    refreshTimetable(ref);
                  },
            icon: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_navy),
                    ),
                  )
                : const Icon(Icons.sync_rounded, size: 18),
            label: Text(
              isLoading ? 'Syncing…' : 'Sync timetable',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMoreClassesCard({
    String primaryText = 'No more classes for the day',
    String secondaryText = 'Time to rest 😪',
    ({DateTime date, List<ClassOccurrence> classes})? nextDayInfo,
    required List<dynamic> attendanceList,
    required List<dynamic> marksList,
    required DateTime now,
  }) {
    final bool hasNextDay =
        nextDayInfo != null && nextDayInfo.classes.isNotEmpty;
    final String nextDayLabel = hasNextDay
        ? (nextDayInfo.date.difference(DateTime(now.year, now.month, now.day)).inDays == 1
            ? 'Tomorrow (${DateFormat('EEE').format(nextDayInfo.date)})'
            : DateFormat('EEEE').format(nextDayInfo.date))
        : '';
    final ClassOccurrence? firstNext =
        hasNextDay ? nextDayInfo.classes.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const NexusIllustration(kind: NexusIllo.rest, size: 132),
              Text(
                primaryText,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  color: _ink,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                secondaryText,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: _inkSoft,
                ),
                textAlign: TextAlign.center,
              ),
              if (hasNextDay && firstNext != null) ...[
                const SizedBox(height: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isNextDayPreviewOpen = !_isNextDayPreviewOpen;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _line),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.upcoming_rounded,
                          size: 16,
                          color: _blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$nextDayLabel · ${nextDayInfo.classes.length} classes · Starts ${VtopHelpers.formatTo12Hour(firstNext.startTime)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isNextDayPreviewOpen ? 'Hide' : 'Preview',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _blue,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          _isNextDayPreviewOpen
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: _blue,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (hasNextDay && _isNextDayPreviewOpen)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final occ in nextDayInfo.classes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildCollapsedClassStrip(
                      occ,
                      nextDayInfo.date,
                      attendanceList: attendanceList,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _showClassDetailBottomSheet(
                          occ,
                          attendanceList: attendanceList,
                          marksList: marksList,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // ============================================================
  // CLASS DETAIL BOTTOM SHEET (With Live Academic Dossier)
  // ============================================================
  void _showClassDetailBottomSheet(
    ClassOccurrence occurrence, {
    required List<dynamic> attendanceList,
    required List<dynamic> marksList,
  }) {
    final DateTime now = DateTime.now();
    final ClassPhase phase = occurrence.phaseAt(now);

    String phaseLabel;
    switch (phase) {
      case ClassPhase.ongoing:
        final left = occurrence.remainingAt(now);
        phaseLabel = left == null
            ? 'Happening now'
            : '${VtopHelpers.formatShortDuration(left)} left';
        break;
      case ClassPhase.completed:
        phaseLabel = 'Completed';
        break;
      case ClassPhase.upcoming:
        final until = occurrence.startsInAt(now);
        phaseLabel = until == null
            ? 'Scheduled'
            : 'Starts in ${VtopHelpers.formatShortDuration(until)}';
        break;
    }

    final attMatch = _matchCourseAttendance(occurrence, attendanceList);
    final marksMatch = _matchCourseMarks(occurrence, marksList);

    double? attPct;
    int attCount = 0;
    int attTotal = 0;
    String? attBufferLabel;
    bool attCanBunk = true;

    if (attMatch != null) {
      attCount =
          int.tryParse((attMatch['attended_classes'] ?? '0').toString()) ?? 0;
      attTotal =
          int.tryParse((attMatch['total_classes'] ?? '0').toString()) ?? 0;
      if (attTotal > 0) {
        attPct = double.tryParse(
              (attMatch['attendance_percentage'] ?? '')
                  .toString()
                  .replaceAll('%', '')
                  .trim(),
            ) ??
            ((attCount / attTotal) * 100);
        final bunk = AttendanceCalculator.calculateBunkStats(
          attCount,
          attTotal,
          target: 75.0,
        );
        attCanBunk = bunk['canBunk'] == true;
        final c = (bunk['count'] as int?) ?? 0;
        attBufferLabel = attCanBunk
            ? (c > 0 ? 'Can skip $c' : 'On 75% edge')
            : 'Attend next $c';
      }
    }

    double gainedWt = 0;
    double testedWt = 0;
    if (marksMatch != null) {
      final details = (marksMatch['details'] as List<dynamic>?) ?? const [];
      for (final d in details) {
        if (d is! Map) continue;
        gainedWt +=
            double.tryParse((d['weightage_mark'] ?? '0').toString()) ?? 0;
        testedWt += double.tryParse((d['weightage'] ?? '0').toString()) ?? 0;
      }
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  occurrence.courseName.isEmpty
                      ? 'Class'
                      : occurrence.courseName,
                  style: GoogleFonts.dmSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildDetailSheetChip(phaseLabel),
                    if (occurrence.courseType.isNotEmpty)
                      _buildDetailSheetChip(occurrence.courseType),
                    if (occurrence.slot.isNotEmpty)
                      _buildDetailSheetChip('Slot ${occurrence.slot}'),
                  ],
                ),
                if (attPct != null || testedWt > 0) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _line),
                    ),
                    child: Row(
                      children: [
                        if (attPct != null)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ATTENDANCE',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: _inkMuted,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '${attPct.toStringAsFixed(1)}%',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: attPct >= 75 ? _green : _orange,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '($attCount/$attTotal)',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 12,
                                        color: _inkSoft,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (attBufferLabel != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    attBufferLabel,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: attCanBunk ? _green : _orange,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        if (attPct != null && testedWt > 0)
                          Container(
                            width: 1,
                            height: 44,
                            margin: const EdgeInsets.symmetric(horizontal: 14),
                            color: _line,
                          ),
                        if (testedWt > 0)
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: marksMatch == null
                                  ? null
                                  : () {
                                      Navigator.of(sheetCtx).pop();
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => MarkDetailPage(
                                            course: marksMatch,
                                          ),
                                        ),
                                      );
                                    },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'MARKS SCORED',
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: _inkMuted,
                                          letterSpacing: 0.7,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.open_in_new_rounded,
                                        size: 11,
                                        color: _blue,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${gainedWt.toStringAsFixed(1)} / ${testedWt.toStringAsFixed(0)} wt',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: _ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Lost ${(testedWt - gainedWt).clamp(0, 100).toStringAsFixed(1)} wt so far',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: _inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _buildDetailSheetRow(
                  icon: Icons.schedule_rounded,
                  label: 'Time',
                  value: VtopHelpers.formatTimeRange(
                    occurrence.startTime,
                    occurrence.endTime,
                  ),
                ),
                _buildDetailSheetRow(
                  icon: Icons.place_outlined,
                  label: 'Venue',
                  value: occurrence.venue,
                ),
                _buildDetailSheetRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Faculty',
                  value: occurrence.faculty,
                ),
                _buildDetailSheetRow(
                  icon: Icons.tag_rounded,
                  label: 'Course code',
                  value: occurrence.courseCode,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailSheetChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _line),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          color: _inkSoft,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDetailSheetRow({
    required IconData icon,
    required String label,
    required String? value,
  }) {
    final String text = (value ?? '').trim().isEmpty ? '—' : value!.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: _inkSoft),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: _inkMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color: _ink,
                    fontWeight: FontWeight.w600,
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
  // QUICK ACCESS HEADER
  // ============================================================
  Widget _buildQuickAccessHeader() {
    final total = _getQuickAccessItems().length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Quick Access',
          style: GoogleFonts.dmSans(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: _ink,
            letterSpacing: -0.5,
          ),
        ),
        InkWell(
          onTap: () {
            setState(() {
              _isQuickAccessExpanded = !_isQuickAccessExpanded;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isQuickAccessExpanded ? 'SHOW LESS' : 'VIEW ALL ($total)',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: _isQuickAccessExpanded ? _blue : _inkMuted,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  _isQuickAccessExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 13,
                  color: _isQuickAccessExpanded ? _blue : _inkMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // QUICK ACCESS CIRCULAR 4-COLUMN GRID (2 ROWS DEFAULT + EXPAND/LESS)
  // ============================================================
  Widget _buildQuickAccessGrid(Map<String, dynamic> data, AuthState authState) {
    final allItems = _getQuickAccessItems();

    // When collapsed, show exactly 2 rows (7 services + 1 "More" action circle)
    // When expanded, show all services + 1 "Less" action circle
    final List<_QuickItem> items;
    if (!_isQuickAccessExpanded && allItems.length > 8) {
      items = [
        ...allItems.take(7),
        _QuickItem(
          label: 'More',
          icon: Icons.keyboard_arrow_down_rounded,
          accent: _blue,
          action: '__toggle_more__',
        ),
      ];
    } else if (_isQuickAccessExpanded) {
      items = [
        ...allItems,
        _QuickItem(
          label: 'Less',
          icon: Icons.keyboard_arrow_up_rounded,
          accent: _blue,
          action: '__toggle_less__',
        ),
      ];
    } else {
      items = allItems;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 14,
        childAspectRatio: 0.84,
      ),
      itemBuilder: (context, index) {
        final item = items[index];

        return Semantics(
          button: true,
          label: 'Open ${item.label}',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                _handleQuickTap(item, data, authState);
              },
              borderRadius: BorderRadius.circular(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Circular Icon Container (Clean circle with subtle border)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _surface,
                      border: Border.all(
                        color: item.action == '__toggle_more__' ||
                                item.action == '__toggle_less__'
                            ? _blue.withValues(alpha: 0.4)
                            : _line,
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _ink.withValues(alpha: 0.035),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        item.icon,
                        color: item.accent,
                        size: 21,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
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
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
            .animate(delay: (10 * index).ms)
            .fadeIn(duration: 150.ms)
            .slideY(begin: 0.03, end: 0, curve: Curves.easeOutCubic);
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
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _line),
                  ),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/vitap_nexus_logo.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.school_rounded,
                          color: _navy,
                          size: 22,
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

class _NexusDashboardAvatar extends StatefulWidget {
  final String? base64Pfp;
  final VoidCallback onTap;
  final Color surface;
  final Color line;
  final Color navy;

  const _NexusDashboardAvatar({
    required this.base64Pfp,
    required this.onTap,
    required this.surface,
    required this.line,
    required this.navy,
  });

  @override
  State<_NexusDashboardAvatar> createState() => _NexusDashboardAvatarState();
}

class _NexusDashboardAvatarState extends State<_NexusDashboardAvatar> {
  static final Map<String, Uint8List> _memoryByteCache = {};
  Uint8List? _cachedBytes;

  @override
  void initState() {
    super.initState();
    _resolveBytes();
  }

  @override
  void didUpdateWidget(_NexusDashboardAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.base64Pfp != oldWidget.base64Pfp) {
      _resolveBytes();
    }
  }

  void _resolveBytes() {
    final raw = widget.base64Pfp;
    if (raw == null || raw.isEmpty) {
      _cachedBytes = null;
      return;
    }

    if (_memoryByteCache.containsKey(raw)) {
      _cachedBytes = _memoryByteCache[raw];
      return;
    }

    try {
      final clean = raw.contains(',') ? raw.split(',').last : raw;
      final bytes = base64Decode(clean.replaceAll(RegExp(r'\s+'), ''));
      _memoryByteCache[raw] = bytes;
      _cachedBytes = bytes;
    } catch (_) {
      _cachedBytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final customAvatar = StorageService.getCustomAvatarPathSync();
    return Semantics(
      button: true,
      label: 'Open student profile and account settings',
      child: Tooltip(
        message: 'Account Profile',
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: widget.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.line),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: (customAvatar != null && customAvatar.isNotEmpty)
                  ? Image.asset(
                      customAvatar,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.person_outline_rounded,
                        color: widget.navy,
                        size: 20,
                      ),
                    )
                  : _cachedBytes != null
                  ? Image.memory(
                      _cachedBytes!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      cacheWidth: 84,
                      cacheHeight: 84,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.person_outline_rounded,
                        color: widget.navy,
                        size: 20,
                      ),
                    )
                  : Icon(
                      Icons.person_outline_rounded,
                      color: widget.navy,
                      size: 20,
                    ),
            ),
          ),
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
    final palette = AppPalette.of(context);
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
                color: palette.red.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.sync_problem_rounded,
                color: palette.red,
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
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                height: 1.45,
                color: palette.inkMuted,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.isDark ? palette.soft : const Color(0xFF172B4D),
                foregroundColor: palette.ink,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: palette.line),
                ),
              ),
              icon: Icon(
                Icons.refresh_rounded,
                size: 17,
                color: palette.ink,
              ),
              label: Text(
                'TRY AGAIN',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: palette.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
