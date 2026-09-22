import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/vtop_providers.dart';
import '../services/storage_service.dart';
import '../utils/error_formatter.dart';
import '../utils/vtop_helpers.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

// ============================================================
// VITAP NEXUS — EDITORIAL ATTENDANCE DESIGN
// Same new visual system as Login + Dashboard.
// ============================================================

const Color _background = Color(0xFFF4F2ED);
const Color _surface = Color(0xFFFFFEFB);
const Color _ink = Color(0xFF17202A);
const Color _inkSoft = Color(0xFF59636E);
const Color _muted = Color(0xFF8B939B);
const Color _line = Color(0xFFDCD9D2);

const Color _navy = Color(0xFF172B4D);
const Color _blue = Color(0xFF356AE6);
const Color _orange = Color(0xFFE47543);
const Color _cream = Color(0xFFEAE5DA);

const Color _success = Color(0xFF23835B);
const Color _warning = Color(0xFFD28A18);
const Color _danger = Color(0xFFD94B4B);

class _AttendanceScreenState extends ConsumerState<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _calculateBunkStats(
    int attended,
    int total, {
    double target = 75.0,
  }) {
    if (total == 0) {
      return {
        'canBunk': true,
        'count': 0,
        'percentage': 100.0,
      };
    }

    final currentPercentage = (attended / total) * 100;
    final targetFraction = target / 100.0;

    if (currentPercentage >= target) {
      final canBunk =
          ((attended - targetFraction * total) / targetFraction).floor();

      return {
        'canBunk': true,
        'count': canBunk < 0 ? 0 : canBunk,
        'percentage': currentPercentage,
      };
    }

    final needed =
        (targetFraction * total - attended) / (1.0 - targetFraction);
    final mustAttend = needed.ceil();

    return {
      'canBunk': false,
      'count': mustAttend < 1 ? 1 : mustAttend,
      'percentage': currentPercentage,
    };
  }

  Color _getStatusColor(double percentage) {
    if (percentage >= 85) return _success;
    if (percentage >= 75) return _blue;
    if (percentage >= 65) return _warning;
    return _danger;
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

  void _showAttendanceDetailModal(
    BuildContext context,
    Map<String, dynamic> course,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AttendanceDetailModal(
        course: course,
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

  String _formatLastSynced(DateTime? timestamp) {
    if (timestamp == null) return 'Not Synced 💾';
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now 💾';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago 💾';
    if (diff.inHours < 24) return '${diff.inHours} hours ago 💾';
    return '${diff.inDays} days ago 💾';
  }

  @override
  Widget build(BuildContext context) {
    final attendanceAsync = ref.watch(attendanceProvider);
    final lastSyncedTime = StorageService.getMemoryTimestamp('attendance');

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 82,
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
                fontWeight: FontWeight.w900,
                fontSize: 23,
                color: _ink,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Last Synced: ${_formatLastSynced(lastSyncedTime)}',
              style: GoogleFonts.dmSans(
                color: _muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showCalculatorSheet(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _line),
                  ),
                  child: const Icon(
                    Icons.calculate_outlined,
                    color: _navy,
                    size: 19,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Material(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: attendanceAsync.isLoading
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await refreshAttendance(ref);
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(ErrorFormatter.format(e, fallback: 'Unable to refresh attendance. Please try again.')),
                              ),
                            );
                          }
                        }
                      },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _line),
                  ),
                  child: attendanceAsync.isLoading
                      ? const Center(
                          child: SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(_navy),
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.refresh_rounded,
                          color: _navy,
                          size: 19,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 6),
          _buildTabSelector(),
          Expanded(
            child: attendanceAsync.when(
              data: (attendanceList) =>
                  _buildAttendanceContent(attendanceList),
              loading: _buildSkeletonLoading,
              error: (err, stack) => _buildErrorView(err.toString()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        elevation: 3,
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.calculate_rounded, size: 19),
        label: Text(
          'CALCULATE',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        onPressed: () => _showCalculatorSheet(context),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 52,
      margin: const EdgeInsets.fromLTRB(20, 3, 20, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _line),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: _navy,
          borderRadius: BorderRadius.circular(11),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: _inkSoft,
        labelStyle: GoogleFonts.spaceGrotesk(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: .5,
        ),
        unselectedLabelStyle: GoogleFonts.spaceGrotesk(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          letterSpacing: .5,
        ),
        tabs: const [
          Tab(text: 'THEORY'),
          Tab(text: 'LAB / PRACTICAL'),
        ],
      ),
    );
  }

  Widget _buildAttendanceContent(List<dynamic> attendanceList) {
    if (attendanceList.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await refreshAttendance(ref);
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text(ErrorFormatter.format(e, fallback: 'Unable to refresh attendance. Please try again.'))),
              );
            }
          }
        },
        color: _navy,
        backgroundColor: _surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: _cream,
                          borderRadius: BorderRadius.circular(19),
                        ),
                        child: const Icon(
                          Icons.folder_off_outlined,
                          size: 27,
                          color: _inkSoft,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'No attendance records',
                        style: GoogleFonts.dmSans(
                          color: _ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Pull down to refresh with latest data.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          color: _muted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final theoryList = <dynamic>[];
    final labList = <dynamic>[];

    for (final item in attendanceList) {
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
        _buildAttendanceList(theoryList, isLabTab: false),
        _buildAttendanceList(labList, isLabTab: true),
      ],
    );
  }

  Widget _buildErrorView(String error) {
    return RefreshIndicator(
      onRefresh: () async {
        try {
          await refreshAttendance(ref);
        } catch (_) {}
      },
      color: _navy,
      backgroundColor: _surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _danger.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.sync_problem_rounded,
                        size: 28,
                        color: _danger,
                      ),
                    ),
                    const SizedBox(height: 17),
                    Text(
                      'Couldn’t load attendance',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        color: _muted,
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 19,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        try {
                          await refreshAttendance(ref);
                        } catch (_) {}
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: Text(
                        'TRY AGAIN',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(13),
            child: const CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'LOADING ATTENDANCE',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: _ink,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList(
    List<dynamic> list, {
    required bool isLabTab,
  }) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await refreshAttendance(ref);
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text(ErrorFormatter.format(e, fallback: 'Unable to refresh attendance. Please try again.'))),
              );
            }
          }
        },
        color: _navy,
        backgroundColor: _surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: Center(
                child: Text(
                  isLabTab
                      ? 'No lab courses found'
                      : 'No theory courses found',
                  style: GoogleFonts.dmSans(
                    color: _muted,
                    fontSize: 13,
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
      onRefresh: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await refreshAttendance(ref);
        } catch (e) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text(ErrorFormatter.format(e, fallback: 'Unable to refresh attendance. Please try again.'))),
            );
          }
        }
      },
      color: _navy,
      backgroundColor: _surface,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
        itemCount: list.length,
        itemBuilder: (context, index) {
        final course = list[index];

        final courseName = course['course_name'] ?? 'Course';
        final courseCode = course['course_code'] ?? '';
        final slot = course['course_slot'] ?? '';
        final faculty = course['faculty'] ?? '';

        final attended = int.tryParse(
              course['attended_classes']?.toString() ?? '0',
            ) ??
            0;

        final total = int.tryParse(
              course['total_classes']?.toString() ?? '0',
            ) ??
            0;

        final rawPercentage = course['attendance_percentage']
                ?.toString()
                .replaceAll('%', '')
                .trim() ??
            '0';

        final percentage = double.tryParse(rawPercentage) ??
            (total > 0 ? (attended / total) * 100 : 0.0);

        final bunkStats = _calculateBunkStats(attended, total);
        final statusColor = _getStatusColor(percentage);
        final progress =
            total > 0 ? (attended / total).clamp(0.0, 1.0) : 0.0;

        return _buildCourseCard(
          index: index,
          course: course is Map<String, dynamic>
              ? course
              : Map<String, dynamic>.from(course as Map),
          courseName: courseName,
          courseCode: courseCode,
          slot: slot,
          faculty: faculty,
          attended: attended,
          total: total,
          percentage: percentage,
          progress: progress,
          statusColor: statusColor,
          bunkStats: bunkStats,
          isLab: isLabTab,
        );
      },
    ),
  );
}

  Widget _buildCourseCard({
    required int index,
    required Map<String, dynamic> course,
    required String courseName,
    required String courseCode,
    required String slot,
    required String faculty,
    required int attended,
    required int total,
    required double percentage,
    required double progress,
    required Color statusColor,
    required Map<String, dynamic> bunkStats,
    required bool isLab,
  }) {
    final isBelowTarget = percentage < 75;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isBelowTarget
              ? _danger.withValues(alpha: .32)
              : _line,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showAttendanceDetailModal(context, course),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(17, 16, 17, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isLab
                      ? Icons.science_outlined
                      : Icons.menu_book_outlined,
                  color: statusColor,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (courseCode.isNotEmpty)
                          Flexible(
                            child: Text(
                              courseCode,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                                letterSpacing: .7,
                              ),
                            ),
                          ),
                        if (slot.isNotEmpty) ...[
                          const SizedBox(width: 7),
                          _smallTag(slot),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      courseName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        height: 1.2,
                      ),
                    ),
                    if (faculty.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        faculty,
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: _muted,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                      letterSpacing: -.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ATTENDANCE',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 6.5,
                      fontWeight: FontWeight.w800,
                      color: _muted,
                      letterSpacing: .8,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: progress,
                    backgroundColor: _cream,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$attended/$total',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: _inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            height: 1,
            color: _line,
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Text(
                '$attended / $total attended',
                style: GoogleFonts.dmSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _inkSoft,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showCalculatorSheet(
                  context,
                  initialAttended: attended,
                  initialTotal: total,
                  courseName: courseName,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: bunkStats['canBunk']
                        ? _success.withValues(alpha: .09)
                        : _danger.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: bunkStats['canBunk']
                          ? _success.withValues(alpha: .22)
                          : _danger.withValues(alpha: .22),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        bunkStats['canBunk']
                            ? Icons.check_circle_outline_rounded
                            : Icons.warning_amber_rounded,
                        size: 13,
                        color: bunkStats['canBunk']
                            ? _success
                            : _danger,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        bunkStats['canBunk']
                            ? 'Miss ${bunkStats['count']}'
                            : 'Attend ${bunkStats['count']}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: bunkStats['canBunk']
                              ? _success
                              : _danger,
                          letterSpacing: .15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
),
)
        .animate(delay: (35 * index).ms)
        .fadeIn(duration: 280.ms)
        .slideY(
          begin: .035,
          end: 0,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _smallTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 7,
          fontWeight: FontWeight.w800,
          color: _inkSoft,
        ),
      ),
    );
  }
}

// ============================================================
// ATTENDANCE CALCULATOR
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
  State<_AttendanceCalculatorModal> createState() =>
      _AttendanceCalculatorModalState();
}

class _AttendanceCalculatorModalState
    extends State<_AttendanceCalculatorModal> {
  late TextEditingController _attendedCtrl;
  late TextEditingController _totalCtrl;

  double _targetPercentage = 75.0;

  @override
  void initState() {
    super.initState();

    _attendedCtrl = TextEditingController(
      text: widget.initialAttended > 0
          ? '${widget.initialAttended}'
          : '',
    );

    _totalCtrl = TextEditingController(
      text: widget.initialTotal > 0
          ? '${widget.initialTotal}'
          : '',
    );
  }

  @override
  void dispose() {
    _attendedCtrl.dispose();
    _totalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attended =
        int.tryParse(_attendedCtrl.text.trim()) ?? 0;
    final total =
        int.tryParse(_totalCtrl.text.trim()) ?? 0;

    final currentPercentage =
        total > 0 ? (attended / total) * 100 : 0.0;

    String resultText = '';
    bool isSafe = true;

    if (total > 0 && attended <= total) {
      final targetFraction = _targetPercentage / 100.0;

      if (currentPercentage >= _targetPercentage) {
        final canBunk = ((attended -
                    targetFraction * total) /
                targetFraction)
            .floor();

        isSafe = true;

        resultText = canBunk > 0
            ? 'You can safely miss $canBunk more classes and maintain ≥ ${_targetPercentage.toInt()}%.'
            : 'You are right on the limit. Avoid missing any more classes.';
      } else {
        final needed =
            (targetFraction * total - attended) /
                (1.0 - targetFraction);

        final mustAttend = needed.ceil();

        isSafe = false;

        resultText =
            'Attend the next $mustAttend consecutive classes to hit ${_targetPercentage.toInt()}%.';
      }
    }

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
        border: Border(
          top: BorderSide(
            color: _line,
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: _line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.calculate_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance Planner',
                        style: GoogleFonts.dmSans(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: _ink,
                        ),
                      ),
                      if (widget.courseName != null)
                        Text(
                          widget.courseName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 10.5,
                            color: _muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _attendedCtrl,
                    label: 'ATTENDED',
                    hint: '18',
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInputField(
                    controller: _totalCtrl,
                    label: 'TOTAL',
                    hint: '22',
                    icon: Icons.format_list_bulleted_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 21),
            Text(
              'TARGET REQUIREMENT',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: _inkSoft,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [75.0, 80.0, 85.0, 90.0].map((target) {
                final selected = _targetPercentage == target;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(
                      () => _targetPercentage = target,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? _navy : _cream,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? _navy : _line,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${target.toInt()}%',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: selected ? Colors.white : _inkSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            if (total > 0 && attended <= total) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSafe
                      ? _success.withValues(alpha: .08)
                      : _danger.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSafe
                        ? _success.withValues(alpha: .22)
                        : _danger.withValues(alpha: .22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'CURRENT RATE',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: isSafe ? _success : _danger,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        Text(
                          '${currentPercentage.toStringAsFixed(1)}%',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w900,
                            color: isSafe ? _success : _danger,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Icon(
                          isSafe
                              ? Icons.check_circle_rounded
                              : Icons.warning_rounded,
                          color: isSafe ? _success : _danger,
                          size: 19,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      resultText,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: _ink,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            color: _inkSoft,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.dmSans(
            color: _ink,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dmSans(
              color: _muted,
              fontSize: 13,
            ),
            prefixIcon: Icon(
              icon,
              color: _inkSoft,
              size: 18,
            ),
            filled: true,
            fillColor: _background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: _blue,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// ATTENDANCE DETAIL MODAL (SUMMARY & DAY-WISE TABS)
// ============================================================

class _AttendanceDetailModal extends ConsumerStatefulWidget {
  final Map<String, dynamic> course;
  final void Function(int attended, int total, String courseName) onOpenCalculator;

  const _AttendanceDetailModal({
    required this.course,
    required this.onOpenCalculator,
  });

  @override
  ConsumerState<_AttendanceDetailModal> createState() =>
      _AttendanceDetailModalState();
}

class _AttendanceDetailModalState extends ConsumerState<_AttendanceDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic>? _dayWiseList;
  bool _isLoadingDayWise = false;
  String? _dayWiseError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _dayWiseList == null && !_isLoadingDayWise) {
        _loadDayWise(forceRefresh: false);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDayWise({bool forceRefresh = false}) async {
    final courseId = widget.course['course_id']?.toString() ?? '';
    final courseType = widget.course['course_type_code']?.toString() ??
        widget.course['course_type']?.toString() ??
        '';

    if (courseId.isEmpty) {
      setState(() {
        _dayWiseError = 'Course ID unavailable to fetch records.';
      });
      return;
    }

    setState(() {
      _isLoadingDayWise = true;
      _dayWiseError = null;
    });

    try {
      final list = await getAttendanceDetail(
        ref: ref,
        courseId: courseId,
        courseType: courseType,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _dayWiseList = list;
          _isLoadingDayWise = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dayWiseError = ErrorFormatter.format(
            e,
            fallback:
                'Unable to load day-wise attendance. Please check your connection and try again.',
          );
          _isLoadingDayWise = false;
        });
      }
    }
  }

  Color _getStatusColor(double percentage) {
    if (percentage >= 85) return _success;
    if (percentage >= 75) return _blue;
    if (percentage >= 65) return _warning;
    return _danger;
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final courseName = course['course_name']?.toString() ?? 'Course';
    final courseCode = course['course_code']?.toString() ?? '';
    final slot = course['course_slot']?.toString() ?? '';
    final faculty = course['faculty']?.toString() ?? '';
    final courseType = course['course_type']?.toString() ?? course['course_type_code']?.toString() ?? '';
    final debarStatus = course['debar_status']?.toString() ?? 'Eligible';

    final attended = int.tryParse(course['attended_classes']?.toString() ?? '0') ?? 0;
    final total = int.tryParse(course['total_classes']?.toString() ?? '0') ?? 0;

    final rawPercentage = course['attendance_percentage']?.toString().replaceAll('%', '').trim() ?? '0';
    final percentage = double.tryParse(rawPercentage) ?? (total > 0 ? (attended / total) * 100 : 0.0);

    final rawRecent = course['attendance_between_percentage']
        ?.toString()
        .replaceAll('%', '')
        .trim();
    final parsedRecent =
        (rawRecent != null && rawRecent.isNotEmpty) ? double.tryParse(rawRecent) : null;
    final recentPercentage =
        (parsedRecent != null && parsedRecent > 0) ? parsedRecent : percentage;

    final statusColor = _getStatusColor(percentage);
    final isEligible = !debarStatus.toLowerCase().contains('debar') && percentage >= 75;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: _line, width: 1)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: _line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          letterSpacing: -.4,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: _inkSoft, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Segmented Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 42,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: _background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: _navy,
                  borderRadius: BorderRadius.circular(9),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: _inkSoft,
                labelStyle: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
                unselectedLabelStyle: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .5,
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Summary'),
                  Tab(text: 'Day-wise'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryTab(
                  context,
                  courseName: courseName,
                  courseCode: courseCode,
                  slot: slot,
                  faculty: faculty,
                  courseType: courseType,
                  debarStatus: debarStatus,
                  attended: attended,
                  total: total,
                  percentage: percentage,
                  recentPercentage: recentPercentage,
                  statusColor: statusColor,
                  isEligible: isEligible,
                ),
                _buildDayWiseTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab(
    BuildContext context, {
    required String courseName,
    required String courseCode,
    required String slot,
    required String faculty,
    required String courseType,
    required String debarStatus,
    required int attended,
    required int total,
    required double percentage,
    required double recentPercentage,
    required Color statusColor,
    required bool isEligible,
  }) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        // Top Overview Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              // Left Visual Card
              Container(
                width: 96,
                height: 112,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: statusColor.withValues(alpha: .3),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isEligible ? Icons.verified_rounded : Icons.warning_rounded,
                        color: statusColor,
                        size: 19,
                      ),
                    ),
                    const SizedBox(height: 5),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                          letterSpacing: -.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      percentage >= 75 ? 'ELIGIBLE' : 'DEBAR RISK',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        letterSpacing: .6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Right 3 stacked mini-cards
              Expanded(
                child: Column(
                  children: [
                    _buildStatMiniCard(
                      label: 'Overall Attendance',
                      value: '${percentage.toStringAsFixed(1)}%',
                      color: statusColor,
                    ),
                    const SizedBox(height: 6),
                    _buildStatMiniCard(
                      label: 'Recent Attendance',
                      value: '${recentPercentage.toStringAsFixed(1)}%',
                      color: _getStatusColor(recentPercentage),
                    ),
                    const SizedBox(height: 6),
                    _buildStatMiniCard(
                      label: 'Attended Classes',
                      value: '$attended / $total',
                      color: _ink,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Course Specifications Card
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
              Text(
                'COURSE SPECIFICATIONS',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: _inkSoft,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              _buildSpecRow('Course Name', courseName),
              _buildDivider(),
              _buildSpecRow('Course Code', courseCode.isNotEmpty ? courseCode : 'N/A'),
              _buildDivider(),
              _buildSpecRow('Course Slot', slot.isNotEmpty ? slot : 'N/A'),
              _buildDivider(),
              _buildSpecRow('Faculty', faculty.isNotEmpty ? faculty : 'N/A'),
              _buildDivider(),
              _buildSpecRow('Course Type', courseType.isNotEmpty ? courseType : 'Regular'),
              _buildDivider(),
              _buildSpecRow(
                'Debar Status',
                debarStatus,
                isBadge: true,
                badgeColor: isEligible ? _success : _danger,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Calculator Launcher Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: () => widget.onOpenCalculator(attended, total, courseName),
            icon: const Icon(Icons.calculate_rounded, size: 19),
            label: Text(
              'Open Bunk & Attendance Calculator',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: .4,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatMiniCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: _inkSoft,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(
    String label,
    String value, {
    bool isBadge = false,
    Color? badgeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isBadge
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (badgeColor ?? _success).withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (badgeColor ?? _success).withValues(alpha: .3),
                        ),
                      ),
                      child: Text(
                        value,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: badgeColor ?? _success,
                          letterSpacing: .4,
                        ),
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: _line.withValues(alpha: .6),
      margin: const EdgeInsets.symmetric(vertical: 2),
    );
  }

  Widget _buildDayWiseTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with Refresh icon
          Row(
            children: [
              Text(
                'Day-wise Attendance',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const Spacer(),
              if (_dayWiseList != null)
                Text(
                  '${_dayWiseList!.length} Sessions',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                  ),
                ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _isLoadingDayWise ? null : () => _loadDayWise(forceRefresh: true),
                icon: _isLoadingDayWise
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _navy),
                      )
                    : const Icon(Icons.refresh_rounded, size: 20, color: _navy),
                tooltip: 'Refresh Day-wise',
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Content body
          Expanded(
            child: _buildDayWiseContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildDayWiseContent() {
    if (_isLoadingDayWise && _dayWiseList == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(_navy),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'FETCHING DAY-WISE RECORDS...',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: _inkSoft,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      );
    }

    if (_dayWiseError != null && (_dayWiseList == null || _dayWiseList!.isEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _danger.withValues(alpha: .1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, color: _danger, size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                'Failed to load day-wise data',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _dayWiseError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(fontSize: 11.5, color: _muted),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _loadDayWise(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final list = _dayWiseList ?? [];
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_rounded, color: _muted.withValues(alpha: .5), size: 42),
            const SizedBox(height: 10),
            Text(
              'No day-wise records available yet.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _muted,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _loadDayWise(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('Fetch Now'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _navy,
                side: const BorderSide(color: _line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table Header
          Container(
            color: _background,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  child: Text(
                    'SNo.',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: _inkSoft,
                      letterSpacing: .5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Date',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: _inkSoft,
                      letterSpacing: .5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Day / Time',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: _inkSoft,
                      letterSpacing: .5,
                    ),
                  ),
                ),
                SizedBox(
                  width: 68,
                  child: Text(
                    'Status',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: _inkSoft,
                      letterSpacing: .5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),

          // Table Rows
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: _line),
              itemBuilder: (context, index) {
                final item = list[index] is Map ? list[index] : <String, dynamic>{};
                final serial = item['serial']?.toString() ?? '${index + 1}';
                final date = item['date']?.toString() ?? '';
                final dayTime = item['day_time']?.toString() ?? item['slot']?.toString() ?? '';
                final status = item['status']?.toString() ?? '';
                final remark = item['remark']?.toString() ?? '';

                final isPresent = status.toLowerCase().contains('present') || status.toLowerCase() == 'p';
                final isAbsent = status.toLowerCase().contains('absent') || status.toLowerCase() == 'a';
                final isOD = status.toLowerCase().contains('duty') || status.toLowerCase() == 'od';

                Color pillBg = _background;
                Color pillText = _inkSoft;
                Color pillBorder = _line;

                if (isPresent) {
                  pillBg = _success.withValues(alpha: .12);
                  pillText = _success;
                  pillBorder = _success.withValues(alpha: .3);
                } else if (isAbsent) {
                  pillBg = _danger.withValues(alpha: .12);
                  pillText = _danger;
                  pillBorder = _danger.withValues(alpha: .3);
                } else if (isOD) {
                  pillBg = _warning.withValues(alpha: .12);
                  pillText = _warning;
                  pillBorder = _warning.withValues(alpha: .3);
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 38,
                        child: Text(
                          serial,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _muted,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              date,
                              style: GoogleFonts.dmSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            if (remark.isNotEmpty)
                              Text(
                                remark,
                                style: GoogleFonts.dmSans(
                                  fontSize: 9.5,
                                  color: _muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          dayTime,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _inkSoft,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 68,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: pillBorder),
                          ),
                          child: Text(
                            status.isNotEmpty ? status : 'N/A',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: pillText,
                              letterSpacing: .3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
