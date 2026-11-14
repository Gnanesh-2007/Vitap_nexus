import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../providers/vtop_providers.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/attendance_calculator.dart';
import '../utils/error_formatter.dart';
import '../utils/vtop_helpers.dart';
import '../widgets/shadcn/shadcn_ui.dart';
import '../widgets/motion/nexus_motion.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  List<String> _tabs = ['THEORY', 'LAB / PRACTICAL'];
  final double _targetThreshold = 75.0;
  Map<String, dynamic>? _capstoneData;

  AppPalette get _palette => AppPalette.of(context);
  Color get _background => _palette.paper;
  Color get _surface => _palette.surface;
  Color get _ink => _palette.ink;
  Color get _inkSoft => _palette.inkSoft;
  Color get _muted => _palette.inkMuted;
  Color get _line => _palette.line;
  Color get _navy => _palette.navy;
  Color get _blue => _palette.blue;
  Color get _orange => _palette.orange;
  Color get _green => _palette.green;
  Color get _red => _palette.red;
  Color get _soft => _palette.soft;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadCapstoneFromCache();
  }

  Future<void> _loadCapstoneFromCache() async {
    final mem = StorageService.getMemoryCache('capstone_attendance');
    if (mem is Map && mem.isNotEmpty) {
      if (mounted) {
        setState(() {
          _capstoneData = Map<String, dynamic>.from(mem);
        });
      }
      return;
    }
    final disk = await StorageService.getCache('capstone_attendance');
    if (disk is Map && disk.isNotEmpty && mounted) {
      setState(() {
        _capstoneData = Map<String, dynamic>.from(disk);
      });
    }
  }

  void _syncTabs(bool hasCapstone) {
    final desired = <String>[
      'THEORY',
      'LAB / PRACTICAL',
      if (hasCapstone) 'CAPSTONE',
    ];
    if (_tabController == null || _tabs.length != desired.length) {
      final prevIndex = _tabController?.index ?? 0;
      _tabController?.dispose();
      _tabs = desired;
      _tabController = TabController(
        length: desired.length,
        vsync: this,
        initialIndex: prevIndex.clamp(0, desired.length - 1),
      );
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Map<String, dynamic> _calculateBunkStats(int attended, int total, {double? target}) {
    return AttendanceCalculator.calculateBunkStats(
      attended,
      total,
      target: target ?? _targetThreshold,
    );
  }

  Color _getStatusColor(double percentage) {
    if (percentage >= 85) return _green;
    if (percentage >= 75) return _blue;
    if (percentage >= 65) return _orange;
    return _red;
  }

  String _formatLastSynced(DateTime? dt) {
    return StorageService.formatLastSynced(dt);
  }

  void _showCalculatorSheet(
    BuildContext context, {
    int initialAttended = 0,
    int initialTotal = 0,
    String? courseName,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AttendanceCalculatorModal(
        initialAttended: initialAttended,
        initialTotal: initialTotal,
        courseName: courseName,
      ),
    );
  }

  void _showAttendanceDetailModal(BuildContext context, Map<String, dynamic> course, {int initialTabIndex = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AttendanceDetailModal(
        course: course,
        initialTabIndex: initialTabIndex,
        onOpenCalculator: (attended, total, name) {
          Navigator.of(ctx).pop();
          _showCalculatorSheet(
            context,
            initialAttended: attended,
            initialTotal: total,
            courseName: name,
          );
        },
      ),
    );
  }

  Future<void> _onRefresh() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await refreshAttendance(ref);
      await _loadCapstoneFromCache();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: _palette.isDark ? const Color(0xFF2A1C1C) : const Color(0xFF1E293B),
            content: Text(
              'No internet connection. Showing saved data.',
              style: GoogleFonts.dmSans(color: Colors.white, fontSize: 12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceAsync = ref.watch(attendanceProvider);
    final lastSyncedTime = StorageService.getMemoryTimestamp('attendance');
    final memCap = StorageService.getMemoryCache('capstone_attendance');
    final Map<String, dynamic>? capstone = (memCap is Map && memCap.isNotEmpty)
        ? Map<String, dynamic>.from(memCap)
        : _capstoneData;
    final bool hasCapstone = capstone != null && capstone.isNotEmpty;
    _syncTabs(hasCapstone);

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 72,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ACADEMICS',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: _orange,
                letterSpacing: 1.7,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Attendance',
              style: GoogleFonts.dmSans(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Last Synced: ${_formatLastSynced(lastSyncedTime)} 💾',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: _muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line),
            ),
            child: IconButton(
              tooltip: 'Attendance Calculator',
              icon: Icon(Icons.calculate_outlined, color: _navy, size: 20),
              onPressed: () => _showCalculatorSheet(context),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line),
            ),
            child: IconButton(
              tooltip: 'Refresh Attendance',
              icon: Icon(Icons.refresh_rounded, color: _navy, size: 20),
              onPressed: attendanceAsync.isLoading ? null : _onRefresh,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            height: 48,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _line),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: _navy,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: _palette.isDark ? const Color(0xFF0F172A) : Colors.white,
              unselectedLabelColor: _muted,
              labelStyle: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
              unselectedLabelStyle: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
          ),
        ),
      ),
      body: (attendanceAsync.hasValue && attendanceAsync.value!.isNotEmpty)
          ? _buildAttendanceContent(attendanceAsync.value!, capstone: capstone)
          : (StorageService.getMemoryCache('attendance') is List &&
                  (StorageService.getMemoryCache('attendance') as List).isNotEmpty)
              ? _buildAttendanceContent(
                  List<dynamic>.from(StorageService.getMemoryCache('attendance')),
                  capstone: capstone,
                )
              : attendanceAsync.when(
                  data: (list) => _buildAttendanceContent(list, capstone: capstone),
                  loading: () => _buildLoadingView(),
                  error: (err, stack) => _buildErrorView(err.toString()),
                ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Open Attendance & Bunk Calculator',
        backgroundColor: _navy,
        foregroundColor: _palette.isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: const Icon(Icons.calculate_rounded, size: 20),
        label: Text(
          'CALCULATE',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.8,
          ),
        ),
        onPressed: () => _showCalculatorSheet(context),
      ),
    );
  }

  Widget _buildAttendanceContent(
    List<dynamic> attendanceList, {
    Map<String, dynamic>? capstone,
  }) {
    if (attendanceList.isEmpty && (capstone == null || capstone.isEmpty)) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_busy_rounded, size: 48, color: _muted),
                  const SizedBox(height: 12),
                  Text(
                    'No attendance records found',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final theoryList = <dynamic>[];
    final labList = <dynamic>[];

    for (var item in attendanceList) {
      final isLab = VtopHelpers.isLabCourse(
        courseType: item['course_type']?.toString(),
        courseSlot: item['course_slot']?.toString(),
        courseTypeCode: item['course_type_code']?.toString(),
      );
      if (isLab) {
        labList.add(item);
      } else {
        theoryList.add(item);
      }
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildAttendanceList(
          theoryList,
          allCourses: attendanceList,
          isLabTab: false,
        ),
        _buildAttendanceList(
          labList,
          allCourses: attendanceList,
          isLabTab: true,
        ),
        if (capstone != null && capstone.isNotEmpty)
          _buildCapstoneTab(capstone),
      ],
    );
  }

  Widget _buildCapstoneTab(Map<String, dynamic> capstone) {
    final title = (capstone['title'] ?? 'Capstone / SDP').toString().trim();
    final status =
        (capstone['guide_evaluation_status'] ?? '').toString().trim();
    final regDate =
        (capstone['date_of_registration'] ?? '').toString().trim();
    final present = int.tryParse((capstone['present'] ?? '0').toString()) ?? 0;
    final onDuty = int.tryParse((capstone['on_duty'] ?? '0').toString()) ?? 0;
    final absent = int.tryParse((capstone['absent'] ?? '0').toString()) ?? 0;
    final rawPct = (capstone['percentage'] ?? '')
        .toString()
        .replaceAll('%', '')
        .trim();
    final punches = (capstone['punches'] as List<dynamic>?) ?? const [];

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: _navy,
      backgroundColor: _surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 90),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CAPSTONE / SDP ATTENDANCE',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _orange,
                        letterSpacing: 1.1,
                      ),
                    ),
                    if (rawPct.isNotEmpty)
                      Text(
                        '$rawPct%',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _green,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                if (status.isNotEmpty || regDate.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (status.isNotEmpty) 'Guide Eval: $status',
                      if (regDate.isNotEmpty) 'Registered: $regDate',
                    ].join('  ·  '),
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      color: _inkSoft,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildCapstoneCountPill(
                        label: 'Present',
                        count: present,
                        color: _green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCapstoneCountPill(
                        label: 'On Duty',
                        count: onDuty,
                        color: _blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCapstoneCountPill(
                        label: 'Absent',
                        count: absent,
                        color: _red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (punches.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'PUNCH LOG (${punches.length} DAYS)',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: _muted,
                letterSpacing: 0.9,
              ),
            ),
            const SizedBox(height: 10),
            ...punches.whereType<Map>().map((raw) {
              final p = Map<String, dynamic>.from(raw);
              final date = (p['date'] ?? '-').toString();
              final day = (p['day'] ?? '').toString();
              final pStatus = (p['status'] ?? '').toString();
              final punchTime = (p['punch_time'] ?? '').toString();
              final bool isPresent =
                  pStatus.toLowerCase().contains('present');
              final bool isOd = pStatus.toLowerCase().contains('duty') ||
                  pStatus.toLowerCase() == 'od';
              final Color tone =
                  isPresent ? _green : (isOd ? _blue : _red);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _line),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          day.isNotEmpty ? '$date · $day' : date,
                          style: GoogleFonts.dmSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        if (punchTime.isNotEmpty && punchTime != '-') ...[
                          const SizedBox(height: 2),
                          Text(
                            'Punch: $punchTime',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11.5,
                              color: _inkSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        pStatus.isEmpty ? 'Logged' : pStatus,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: tone,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildCapstoneCountPill({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList(
    List<dynamic> list, {
    required List<dynamic> allCourses,
    required bool isLabTab,
  }) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        color: _navy,
        backgroundColor: _surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: Center(
                child: Text(
                  isLabTab ? 'No lab courses found.' : 'No theory courses found.',
                  style: GoogleFonts.dmSans(
                    color: _muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: _navy,
      backgroundColor: _surface,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 90),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final course = list[index] as Map<String, dynamic>;
          return AnimeStaggerItem(
            index: index,
            child: _buildCourseCard(course),
          );
        },
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    final courseName = (course['course_name'] ?? course['course_title'] ?? 'Course').toString();
    final courseCode = (course['course_code'] ?? '').toString();
    final slot = (course['course_slot'] ?? '').toString();
    final faculty = (course['faculty'] ?? '').toString();
    final attended = int.tryParse(course['attended_classes']?.toString() ?? '0') ?? 0;
    final total = int.tryParse(course['total_classes']?.toString() ?? '0') ?? 0;
    final rawPercentageStr =
        course['attendance_percentage']?.toString().replaceAll('%', '').trim() ?? '0';
    final percentage = double.tryParse(rawPercentageStr) ??
        (total > 0 ? (attended / total) * 100 : 0.0);

    final bunkStats = _calculateBunkStats(attended, total);
    final statusColor = _getStatusColor(percentage);

    final statusText = percentage >= 75 ? 'Safe attendance' : 'Low attendance';
    final bunkDescription = (bunkStats['canBunk'] as bool)
        ? 'Can miss ${bunkStats['count']} classes'
        : 'Must attend ${bunkStats['count']} classes';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: NexusCard(
        variant: NexusCardVariant.standard,
        semanticsLabel: '$courseCode $courseName, $percentage% attendance, $statusText, $attended of $total attended, $bunkDescription',
        onTap: () => _showAttendanceDetailModal(context, course),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: _green,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                courseCode,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _green,
                                ),
                              ),
                              if (slot.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _soft,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: _line),
                                  ),
                                  child: Text(
                                    slot,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            courseName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _ink,
                            ),
                          ),
                          if (faculty.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              faculty,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: _muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: GoogleFonts.dmSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                          ),
                        ),
                        Text(
                          'ATTENDANCE',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _muted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                NexusAnimatedProgressBar(
                  percentage: percentage,
                  height: 6,
                  color: statusColor,
                  backgroundColor: _soft,
                  duration: const Duration(milliseconds: 600),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$attended / $total attended',
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _inkSoft,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (bunkStats['canBunk'] as bool)
                            ? _green.withValues(alpha: 0.15)
                            : _orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (bunkStats['canBunk'] as bool)
                              ? _green.withValues(alpha: 0.3)
                              : _orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            (bunkStats['canBunk'] as bool)
                                ? Icons.check_circle_outline_rounded
                                : Icons.info_outline_rounded,
                            size: 13,
                            color: (bunkStats['canBunk'] as bool) ? _green : _orange,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            (bunkStats['canBunk'] as bool)
                                ? 'Miss ${bunkStats['count']}'
                                : 'Attend ${bunkStats['count']}',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: (bunkStats['canBunk'] as bool) ? _green : _orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: _line),
                const SizedBox(height: 10),
                Semantics(
                  button: true,
                  label: 'View day-wise session attendance for $courseName',
                  child: InkWell(
                    onTap: () => _showAttendanceDetailModal(context, course, initialTabIndex: 1),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_month_rounded, size: 14, color: _orange),
                              const SizedBox(width: 6),
                              Text(
                                'DAY-WISE ATTENDANCE',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: _orange,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                'View Sessions',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: _inkSoft,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(Icons.arrow_forward_ios_rounded, size: 10.5, color: _muted),
                            ],
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

  Widget _buildLoadingView() {
    return const NexusLoadingState(
      title: 'Loading attendance records...',
      subtitle: 'Fetching subject attendance from VTOP',
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: _red),
            const SizedBox(height: 16),
            Text(
              'Failed to load attendance',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ErrorFormatter.format(error),
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: _palette.isDark ? const Color(0xFF0F172A) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ATTENDANCE DETAILS MODAL (SUMMARY & DAY-WISE TABS)
// ============================================================

class _AttendanceDetailModal extends ConsumerStatefulWidget {
  final Map<String, dynamic> course;
  final int initialTabIndex;
  final void Function(int attended, int total, String courseName) onOpenCalculator;

  const _AttendanceDetailModal({
    required this.course,
    this.initialTabIndex = 0,
    required this.onOpenCalculator,
  });

  @override
  ConsumerState<_AttendanceDetailModal> createState() => _AttendanceDetailModalState();
}

class _AttendanceDetailModalState extends ConsumerState<_AttendanceDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _modalTabController;
  Future<List<dynamic>>? _dayWiseFuture;

  AppPalette get _palette => AppPalette.of(context);
  Color get _surface => _palette.surface;
  Color get _ink => _palette.ink;
  Color get _inkSoft => _palette.inkSoft;
  Color get _muted => _palette.inkMuted;
  Color get _line => _palette.line;
  Color get _navy => _palette.navy;
  Color get _orange => _palette.orange;
  Color get _green => _palette.green;
  Color get _red => _palette.red;
  Color get _soft => _palette.soft;

  @override
  void initState() {
    super.initState();
    _modalTabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _loadDayWiseAttendance();
  }

  @override
  void dispose() {
    _modalTabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _AttendanceDetailModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.course != widget.course) {
      _loadDayWiseAttendance();
    }
  }

  void _loadDayWiseAttendance() {
    _dayWiseFuture = _fetchDayWiseData();
  }

  Future<List<dynamic>> _fetchDayWiseData({bool forceRefresh = false}) async {
    final auth = ref.read(authProvider);
    final user = auth.username ?? StorageService.currentUsername;
    final semId = auth.activeSemesterId ?? '';

    final rawCourseId = (widget.course['course_id'] ?? '').toString().trim();
    final rawCourseCode = (widget.course['course_code'] ?? '').toString().trim();
    final rawClassNumber = (widget.course['class_number'] ?? '').toString().trim();

    final rawCourseTypeCode = (widget.course['course_type_code'] ?? widget.course['courseTypeCode'] ?? '').toString().trim();
    final rawCourseType = (widget.course['course_type'] ?? widget.course['courseType'] ?? '').toString().trim();

    String courseType = rawCourseTypeCode;
    if (courseType.isEmpty) {
      final ct = rawCourseType.toLowerCase();
      if (ct.contains('embedded lab') || ct == 'ela') {
        courseType = 'ELA';
      } else if (ct.contains('embedded theory') || ct == 'eth') {
        courseType = 'ETH';
      } else if (ct.contains('lab') || ct == 'lo') {
        courseType = 'LO';
      } else if (ct.contains('project') || ct == 'epj') {
        courseType = 'EPJ';
      } else if (ct.contains('theory') || ct == 'th') {
        courseType = 'TH';
      } else if (ct == 'ss' || ct.contains('soft skills')) {
        courseType = 'SS';
      } else {
        courseType = rawCourseType;
      }
    }

    final uniqueSubjectKey = [
      if (rawCourseCode.isNotEmpty) rawCourseCode,
      if (courseType.isNotEmpty) courseType,
      if (rawClassNumber.isNotEmpty) rawClassNumber,
      if (rawCourseId.isNotEmpty) rawCourseId,
    ].join('_');

    final cacheKey = 'att_detail_${semId}_$uniqueSubjectKey';

    if (!forceRefresh) {
      final mem = StorageService.getMemoryCache(cacheKey, username: user);
      if (mem is List && mem.isNotEmpty) {
        return List<dynamic>.from(mem);
      }
      final disk = await StorageService.getCache(cacheKey, username: user);
      if (disk is List && disk.isNotEmpty) {
        return List<dynamic>.from(disk);
      }
    }

    if (auth.username != null && auth.password != null) {
      final candidateIds = <String>[
        if (rawCourseId.isNotEmpty) rawCourseId,
        if (rawClassNumber.isNotEmpty && rawClassNumber != rawCourseId) rawClassNumber,
        if (rawCourseCode.isNotEmpty && rawCourseCode != rawCourseId && rawCourseCode != rawClassNumber) rawCourseCode,
      ];

      for (final cid in candidateIds) {
        try {
          final fresh = await apiService.fetchAttendanceDetail(
            username: auth.username ?? '',
            password: auth.password ?? '',
            semSubId: semId,
            courseId: cid,
            courseType: courseType,
          );
          if (fresh.isNotEmpty) {
            await StorageService.setCache(cacheKey, fresh, username: user, semesterId: semId);
            return fresh;
          }
        } catch (e) {
          debugPrint('Failed to fetch attendance detail with id $cid ($e)');
        }
      }
    }

    final fallback = StorageService.getMemoryCache(cacheKey, username: user) ??
        await StorageService.getCache(cacheKey, username: user);
    if (fallback is List && fallback.isNotEmpty) {
      return List<dynamic>.from(fallback);
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final courseName = (widget.course['course_name'] ?? widget.course['course_title'] ?? 'Course').toString();
    final courseCode = (widget.course['course_code'] ?? '').toString();
    final courseType = (widget.course['course_type'] ?? widget.course['course_type_code'] ?? '').toString();
    final slot = (widget.course['course_slot'] ?? '').toString();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: _line, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ATTENDANCE DETAILS',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: _orange,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        courseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                      if (courseCode.isNotEmpty || courseType.isNotEmpty || slot.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (courseCode.isNotEmpty)
                              Text(
                                courseCode,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _green,
                                ),
                              ),
                            if (courseType.isNotEmpty) ...[
                              Text(
                                ' • $courseType',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _inkSoft,
                                ),
                              ),
                            ],
                            if (slot.isNotEmpty) ...[
                              Text(
                                ' • $slot',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: _muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh Day-wise Attendance',
                  icon: Icon(Icons.refresh_rounded, color: _navy, size: 20),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _dayWiseFuture = _fetchDayWiseData(forceRefresh: true);
                    });
                  },
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: _inkSoft),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line),
            ),
            child: TabBar(
              controller: _modalTabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: _navy,
                borderRadius: BorderRadius.circular(9),
              ),
              labelColor: _palette.isDark ? const Color(0xFF0F172A) : Colors.white,
              unselectedLabelColor: _muted,
              labelStyle: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              tabs: const [
                Tab(text: 'Summary'),
                Tab(text: 'Day-wise'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _modalTabController,
              children: [
                _buildSummaryTab(),
                _buildDayWiseTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    final attended = int.tryParse(widget.course['attended_classes']?.toString() ?? '0') ?? 0;
    final total = int.tryParse(widget.course['total_classes']?.toString() ?? '0') ?? 0;
    final rawPercentageStr =
        widget.course['attendance_percentage']?.toString().replaceAll('%', '').trim() ?? '0';
    final percentage = double.tryParse(rawPercentageStr) ??
        (total > 0 ? (attended / total) * 100 : 0.0);
    final debarStatus = (widget.course['debar_status'] ?? '-').toString();
    final isEligible = !debarStatus.toLowerCase().contains('debar') && percentage >= 75;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                decoration: BoxDecoration(
                  color: isEligible
                      ? _green.withValues(alpha: 0.12)
                      : _red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isEligible ? _green.withValues(alpha: 0.35) : _red.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      isEligible ? Icons.verified_rounded : Icons.warning_rounded,
                      color: isEligible ? _green : _red,
                      size: 30,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isEligible ? _green : _red,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEligible ? 'ELIGIBLE' : 'DEBARRED',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isEligible ? _green : _red,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  _buildMetricRow('Overall Attendance', '${percentage.toStringAsFixed(1)}%', _green),
                  const SizedBox(height: 8),
                  _buildMetricRow('Recent Attendance', '${percentage.toStringAsFixed(1)}%', _green),
                  const SizedBox(height: 8),
                  _buildMetricRow('Attended Classes', '$attended / $total', _ink),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'COURSE SPECIFICATIONS',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: _muted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _soft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: Column(
            children: [
              _buildSpecRow('Course Name', widget.course['course_name'] ?? widget.course['course_title'] ?? '-'),
              const Divider(height: 18),
              _buildSpecRow('Course Code', widget.course['course_code'] ?? '-'),
              const Divider(height: 18),
              _buildSpecRow('Course Slot', widget.course['course_slot'] ?? '-'),
              const Divider(height: 18),
              _buildSpecRow('Faculty', widget.course['faculty'] ?? '-'),
              const Divider(height: 18),
              _buildSpecRow('Course Type', widget.course['course_type'] ?? '-'),
              const Divider(height: 18),
              _buildSpecRow('Debar Status', debarStatus),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: _palette.isDark ? const Color(0xFF0F172A) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.calculate_rounded, size: 20),
            label: Text(
              'Open Bunk & Attendance Calculator',
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            onPressed: () => widget.onOpenCalculator(
              attended,
              total,
              (widget.course['course_name'] ?? widget.course['course_title'] ?? 'Course').toString(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.dmSans(fontSize: 11.5, color: _inkSoft, fontWeight: FontWeight.w600)),
          Text(value, style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: _muted, fontWeight: FontWeight.w500)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink),
          ),
        ),
      ],
    );
  }

  Widget _buildDayWiseTab() {
    if (_dayWiseFuture == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_rounded, size: 36, color: _muted),
            const SizedBox(height: 12),
            Text(
              'No day-wise session data available.',
              style: GoogleFonts.dmSans(color: _muted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: _dayWiseFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const NexusLoadingState(
            title: 'Loading attendance sessions...',
            subtitle: 'Fetching day-wise log from VTOP',
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, size: 36, color: _palette.red),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load attendance history',
                    style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.bold, color: _ink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ErrorFormatter.format(snapshot.error, fallback: 'Could not retrieve session details.'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(fontSize: 12, color: _muted),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: _palette.onNavy,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      setState(() {
                        _dayWiseFuture = _fetchDayWiseData(forceRefresh: true);
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return NexusEmptyState(
            icon: Icons.event_busy_rounded,
            title: 'No attendance sessions found',
            description: 'No individual class records were returned for this course.',
            lottieHeight: 110,
            action: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _navy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                setState(() {
                  _dayWiseFuture = _fetchDayWiseData(forceRefresh: true);
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
            ),
          );
        }

        return RefreshIndicator(
          color: _navy,
          onRefresh: () async {
            setState(() {
              _dayWiseFuture = _fetchDayWiseData(forceRefresh: true);
            });
            await _dayWiseFuture;
          },
          child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Day-wise Attendance',
                  style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.bold, color: _ink),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _soft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _line),
                      ),
                      child: Text(
                        '${list.length} Sessions',
                        style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: _muted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _line),
                      ),
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        tooltip: 'Refresh Day-wise Records',
                        icon: Icon(Icons.refresh_rounded, color: _navy),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _dayWiseFuture = _fetchDayWiseData(forceRefresh: true);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _line),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: DataTable(
                  horizontalMargin: 12,
                  columnSpacing: 10,
                  headingRowColor: WidgetStateProperty.all(_surface),
                  headingTextStyle: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w800, color: _muted),
                  columns: const [
                    DataColumn(label: Text('SNo.')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Day / Time')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: list.asMap().entries.map((entry) {
                    final item = entry.value as Map<String, dynamic>;
                    final status = (item['status'] ?? item['attendance_status'] ?? 'Present').toString();
                    final isPresent = status.toLowerCase().contains('present');
                    final isOd = status.toLowerCase().contains('duty') || status.toLowerCase() == 'od';
                    final date = (item['date'] ?? item['attendance_date'] ?? '-').toString();
                    final slot = (item['slot'] ?? '').toString();
                    final dayTime = (item['day_time'] ?? item['day_and_timing'] ?? item['time'] ?? '').toString();
                    final timeDisplay = dayTime.isNotEmpty ? (slot.isNotEmpty ? '$slot • $dayTime' : dayTime) : (slot.isNotEmpty ? slot : '-');

                    final Color statusColor = isPresent ? _green : (isOd ? _orange : _red);

                    return DataRow(
                      cells: [
                        DataCell(Text('${entry.key + 1}', style: GoogleFonts.spaceGrotesk(fontSize: 11, color: _muted, fontWeight: FontWeight.w700))),
                        DataCell(Text(date, style: GoogleFonts.dmSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: _ink))),
                        DataCell(Text(timeDisplay, style: GoogleFonts.dmSans(fontSize: 11, color: _inkSoft))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              isPresent ? 'Present' : (isOd ? 'On Duty' : 'Absent'),
                              style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w700, color: statusColor),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      );
      },
    );
  }
}

// ============================================================
// ATTENDANCE BUNK & CALCULATOR MODAL
// ============================================================

class _AttendanceCalculatorModal extends StatefulWidget {
  final int initialAttended;
  final int initialTotal;
  final String? courseName;

  const _AttendanceCalculatorModal({
    this.initialAttended = 0,
    this.initialTotal = 0,
    this.courseName,
  });

  @override
  State<_AttendanceCalculatorModal> createState() => _AttendanceCalculatorModalState();
}

class _AttendanceCalculatorModalState extends State<_AttendanceCalculatorModal> {
  late TextEditingController _attendedController;
  late TextEditingController _totalController;
  double _targetPercentage = 75.0;

  AppPalette get _palette => AppPalette.of(context);
  Color get _surface => _palette.surface;
  Color get _ink => _palette.ink;
  Color get _inkSoft => _palette.inkSoft;
  Color get _muted => _palette.inkMuted;
  Color get _line => _palette.line;
  Color get _navy => _palette.navy;
  Color get _orange => _palette.orange;
  Color get _green => _palette.green;
  Color get _soft => _palette.soft;

  @override
  void initState() {
    super.initState();
    _attendedController = TextEditingController(text: widget.initialAttended.toString());
    _totalController = TextEditingController(text: widget.initialTotal.toString());
  }

  @override
  void dispose() {
    _attendedController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attended = int.tryParse(_attendedController.text) ?? 0;
    final total = int.tryParse(_totalController.text) ?? 0;
    final currentPercentage = total > 0 ? (attended / total) * 100 : 0.0;
    final stats = AttendanceCalculator.calculateBunkStats(attended, total, target: _targetPercentage);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 14,
      ),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: _line, width: 1)),
      ),
      child: SingleChildScrollView(
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
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ATTENDANCE CALCULATOR',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: _orange,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.courseName ?? 'Bunk & Target Planner',
                      style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.bold, color: _ink),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: _inkSoft),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (stats['canBunk'] as bool) ? _green.withValues(alpha: 0.12) : _orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (stats['canBunk'] as bool) ? _green.withValues(alpha: 0.3) : _orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    (stats['canBunk'] as bool) ? Icons.celebration_rounded : Icons.schedule_rounded,
                    color: (stats['canBunk'] as bool) ? _green : _orange,
                    size: 32,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (stats['canBunk'] as bool)
                              ? 'You can miss ${stats['count']} more class${(stats['count'] as int) == 1 ? '' : 'es'}'
                              : 'Need to attend ${stats['count']} more class${(stats['count'] as int) == 1 ? '' : 'es'}',
                          style: GoogleFonts.dmSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: (stats['canBunk'] as bool) ? _green : _orange,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Current: ${currentPercentage.toStringAsFixed(1)}% • Target: ${_targetPercentage.toInt()}%',
                          style: GoogleFonts.dmSans(fontSize: 12, color: _inkSoft, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _attendedController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.dmSans(color: _ink, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Classes Attended',
                      labelStyle: GoogleFonts.dmSans(color: _muted),
                      fillColor: _soft,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _line)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _line)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _totalController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.dmSans(color: _ink, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Total Classes',
                      labelStyle: GoogleFonts.dmSans(color: _muted),
                      fillColor: _soft,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _line)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _line)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'TARGET PERCENTAGE: ${_targetPercentage.toInt()}%',
              style: GoogleFonts.spaceGrotesk(fontSize: 9.5, fontWeight: FontWeight.w800, color: _muted, letterSpacing: 1.2),
            ),
            Slider(
              value: _targetPercentage,
              min: 50,
              max: 95,
              divisions: 9,
              activeColor: _navy,
              inactiveColor: _line,
              label: '${_targetPercentage.toInt()}%',
              onChanged: (val) => setState(() => _targetPercentage = val),
            ),
          ],
        ),
      ),
    );
  }
}
