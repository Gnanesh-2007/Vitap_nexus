import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/vtop_providers.dart';
import '../services/storage_service.dart';
import '../utils/attendance_calculator.dart';
import '../utils/error_formatter.dart';
import '../theme/app_theme.dart';
import '../utils/vtop_helpers.dart';
import '../widgets/motion/nexus_motion.dart';
import '../widgets/shadcn/shadcn_ui.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  late final PageController _pager;
  late int _selected;
  Timer? _ticker;

  static const List<String> _days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    final todayName = DateFormat('EEEE').format(DateTime.now());
    int initialIdx = _days.indexOf(todayName);
    if (initialIdx == -1) initialIdx = 1;
    _selected = initialIdx;
    _pager = PageController(initialPage: initialIdx);
    // Keeps the live class + progress fresh.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pager.dispose();
    super.dispose();
  }

  DateTime _dateForIndex(int i) {
    final now = DateTime.now();
    final sunday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday % 7));
    return sunday.add(Duration(days: i));
  }

  Future<void> _refreshTimetable() async {
    final messenger = ScaffoldMessenger.of(context);
    final cs = Theme.of(context).colorScheme;
    try {
      await refreshTimetable(ref);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: cs.primaryContainer,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            content: Text(
              'Timetable synced with VTOP',
              style: TextStyle(
                color: cs.onPrimaryContainer,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: cs.errorContainer,
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Offline mode: showing saved timetable.',
              style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
            ),
          ),
        );
      }
    }
  }

  int _getTodayClassCount(Map<String, dynamic> timetableData) {
    final todayName = DateFormat('EEEE').format(DateTime.now());
    final raw = VtopHelpers.getClassesForDay(timetableData, todayName);
    return raw.length;
  }

  Map<String, dynamic> _resolveTimetableData(
    AsyncValue<Map<String, dynamic>> timetableAsync,
  ) {
    if (timetableAsync.hasValue && timetableAsync.value!.isNotEmpty) {
      return timetableAsync.value!;
    }
    final mem = StorageService.getMemoryCache('timetable');
    if (mem is Map && mem.isNotEmpty) {
      return Map<String, dynamic>.from(mem);
    }
    return timetableAsync.valueOrNull ?? <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final timetableAsync = ref.watch(timetableProvider);
    final timetableData = _resolveTimetableData(timetableAsync);
    final todayCount = _getTodayClassCount(timetableData);

    final counts = [
      for (final d in _days)
        VtopHelpers.getClassesForDay(timetableData, d).length,
    ];

    return Scaffold(
      backgroundColor: p.paper,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: p.paper,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 72,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SCHEDULE',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: p.orange,
                letterSpacing: 1.7,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Timetable',
              style: GoogleFonts.dmSans(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              todayCount == 0
                  ? 'No classes today'
                  : '$todayCount ${todayCount == 1 ? 'class' : 'classes'} today',
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                color: p.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.line),
            ),
            child: IconButton(
              tooltip: 'Refresh Timetable',
              icon: Icon(Icons.refresh_rounded, color: p.navy, size: 20),
              onPressed: timetableAsync.isLoading ? null : _refreshTimetable,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: AnimatedBuilder(
              animation: _pager,
              builder: (context, _) {
                final page = (_pager.hasClients && _pager.page != null)
                    ? _pager.page!
                    : _selected.toDouble();
                return _WeekStrip(
                  progress: page,
                  counts: counts,
                  dateFor: _dateForIndex,
                  todayIndex: _days.indexOf(DateFormat('EEEE').format(DateTime.now())),
                  onSelect: (i) {
                    if (_pager.hasClients) {
                      _pager.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                );
              },
            ),
          ),
          Expanded(
            child: timetableData.isNotEmpty
                ? _buildPages(timetableData)
                : timetableAsync.when(
                    data: _buildPages,
                    loading: () =>
                        const NexusLoadingState(title: 'Loading timetable...'),
                    error: (err, _) => _buildErrorView(err.toString()),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPages(Map<String, dynamic> timetableData) {
    return RefreshIndicator(
      onRefresh: _refreshTimetable,
      notificationPredicate: (n) => n.depth == 1,
      child: PageView.builder(
        controller: _pager,
        itemCount: _days.length,
        onPageChanged: (i) {
          HapticFeedback.selectionClick();
          setState(() => _selected = i);
        },
        itemBuilder: (context, i) {
          final day = _days[i];
          final sorted = VtopHelpers.sortTimetableList(
            VtopHelpers.getClassesForDay(timetableData, day),
          );
          return _buildDay(day, sorted);
        },
      ),
    );
  }

  Widget _buildDay(String day, List<dynamic> classes) {
    if (classes.isEmpty) {
      return LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: const NexusEmptyState(
              title: 'No classes found',
              description: 'Enjoy your free day! 🎉',
            ),
          ),
        ),
      );
    }

    final todayName = DateFormat('EEEE').format(DateTime.now());
    final isToday = day == todayName;
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;

    final children = <Widget>[];
    int? prevEnd;
    var i = 0;
    for (final raw in classes) {
      final item = Map<String, dynamic>.from(raw as Map);
      final r = VtopHelpers.parseItemTimeRange(item);
      final start = r['start']!;
      final end = r['end']!;
      final timed = start < (1 << 29);
      if (timed && prevEnd != null && start - prevEnd > 15) {
        children.add(_GapLine(minutes: start - prevEnd));
      }
      if (timed) prevEnd = prevEnd == null ? end : (end > prevEnd ? end : prevEnd);
      final isLive = isToday && timed && nowMin >= start && nowMin <= end;
      final isPast = isToday && timed && nowMin > end;
      children.add(
        AnimeStaggerItem(
          index: i++,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ClassCard(
              item: item,
              startMin: start,
              endMin: end,
              nowMin: nowMin,
              isLive: isLive,
              isPast: isPast,
              onTap: () => _showClassDetailsSheet(item),
            ),
          ),
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 90),
      children: children,
    );
  }

  void _showClassDetailsSheet(Map<String, dynamic> item) {
    final cs = Theme.of(context).colorScheme;
    final courseName =
        (item['course_name'] ?? item['course_title'] ?? 'Course').toString();
    final courseCode = (item['course_code'] ?? '').toString();
    final courseType = (item['course_type'] ?? '').toString();
    final faculty = (item['faculty'] ?? '').toString();
    final venue = (item['venue'] ?? item['room_no'] ?? 'TBA').toString();
    final slot = VtopHelpers.cleanSlot(item['slot']?.toString());
    final timeRange = VtopHelpers.formatItemTimeRange(item);

    final memAtt = StorageService.getMemoryCache('attendance');
    final List<dynamic> attendanceList = memAtt is List ? memAtt : const [];
    final attMatch = _matchCourseAttendance(item, attendanceList);

    double? attPct;
    String? attDetail;
    bool canBunk = true;
    if (attMatch != null) {
      final a =
          int.tryParse((attMatch['attended_classes'] ?? '0').toString()) ?? 0;
      final t =
          int.tryParse((attMatch['total_classes'] ?? '0').toString()) ?? 0;
      if (t > 0) {
        attPct = double.tryParse(
              (attMatch['attendance_percentage'] ?? '')
                  .toString()
                  .replaceAll('%', '')
                  .trim(),
            ) ??
            ((a / t) * 100);
        final bunk =
            AttendanceCalculator.calculateBunkStats(a, t, target: 75.0);
        canBunk = bunk['canBunk'] == true;
        final c = (bunk['count'] as int?) ?? 0;
        attDetail = canBunk
            ? '$a/$t classes ($c safe to skip)'
            : '$a/$t classes (Attend next $c)';
      }
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: cs.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courseName,
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  [courseCode, courseType]
                      .where((s) => s.isNotEmpty)
                      .join(' · '),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildSheetDetailRow(
                        ctx,
                        icon: Icons.schedule_rounded,
                        label: 'Timing',
                        value: timeRange.isEmpty ? 'Scheduled' : timeRange,
                      ),
                      const Divider(height: 20),
                      _buildSheetDetailRow(
                        ctx,
                        icon: Icons.location_on_outlined,
                        label: 'Venue',
                        value: venue,
                      ),
                      const Divider(height: 20),
                      _buildSheetDetailRow(
                        ctx,
                        icon: Icons.grid_view_rounded,
                        label: 'Slot',
                        value: slot.isEmpty ? 'N/A' : slot,
                      ),
                      if (faculty.isNotEmpty) ...[
                        const Divider(height: 20),
                        _buildSheetDetailRow(
                          ctx,
                          icon: Icons.person_outline_rounded,
                          label: 'Faculty',
                          value: faculty,
                        ),
                      ],
                      if (attPct != null && attDetail != null) ...[
                        const Divider(height: 20),
                        _buildSheetDetailRow(
                          ctx,
                          icon: Icons.pie_chart_outline_rounded,
                          label: 'Attendance (${attPct.toStringAsFixed(0)}%)',
                          value: attDetail,
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
    );
  }

  Widget _buildSheetDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  static Map<String, dynamic>? _matchCourseAttendance(
    Map<String, dynamic> item,
    List<dynamic> attendanceList,
  ) {
    final code = (item['course_code'] ?? '').toString().trim().toUpperCase();
    if (code.isEmpty || attendanceList.isEmpty) return null;
    final slot = VtopHelpers.cleanSlot(item['slot']?.toString());
    final courseType = (item['course_type'] ?? '').toString();
    final itemIsLab = VtopHelpers.isLabCourse(
      courseType: courseType,
      courseSlot: slot,
    );

    Map<String, dynamic>? fallback;
    for (final raw in attendanceList) {
      if (raw is! Map) continue;
      final att = Map<String, dynamic>.from(raw);
      final attCode =
          (att['course_code'] ?? '').toString().trim().toUpperCase();
      if (attCode != code) continue;
      fallback ??= att;
      final attIsLab = VtopHelpers.isLabCourse(
        courseType: att['course_type']?.toString(),
        courseSlot: att['course_slot']?.toString(),
        courseTypeCode: att['course_type_code']?.toString(),
      );
      if (attIsLab == itemIsLab) return att;
    }
    return fallback;
  }

  Widget _buildErrorView(String error) {
    return NexusErrorState(
      message: ErrorFormatter.format(error),
      retryLabel: 'Retry',
      onRetry: _refreshTimetable,
    );
  }
}

/// Day selector: sliding thumb that follows the page swipe.
class _WeekStrip extends StatelessWidget {
  final double progress;
  final List<int> counts;
  final DateTime Function(int) dateFor;
  final int todayIndex;
  final ValueChanged<int> onSelect;

  const _WeekStrip({
    required this.progress,
    required this.counts,
    required this.dateFor,
    required this.todayIndex,
    required this.onSelect,
  });

  static const _letters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    const n = 7;
    final pos = progress.clamp(0.0, (n - 1).toDouble());
    final sel = pos.round();

    return Container(
      height: 76,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment(-1 + 2 * pos / (n - 1), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.navy,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _letters[i],
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: sel == i
                                ? p.onNavy.withValues(alpha: 0.75)
                                : p.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${dateFor(i).day}',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: sel == i ? p.onNavy : p.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 5,
                          child: i == todayIndex && sel != i
                              ? Container(
                                  width: 14,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: p.orange,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (var d = 0; d < counts[i].clamp(0, 4); d++)
                                      Container(
                                        width: 4,
                                        height: 4,
                                        margin: const EdgeInsets.symmetric(horizontal: 1.2),
                                        decoration: BoxDecoration(
                                          color: sel == i
                                              ? p.onNavy
                                              : p.inkMuted.withValues(alpha: 0.5),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
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
    );
  }
}

class _GapLine extends StatelessWidget {
  final int minutes;
  const _GapLine({required this.minutes});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final text = h == 0 ? '${m}m free' : (m == 0 ? '${h}h free' : '${h}h ${m}m free');
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: p.line, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: p.inkMuted,
              ),
            ),
          ),
          Expanded(child: Divider(color: p.line, thickness: 1)),
        ],
      ),
    );
  }
}

/// A single class: accent bar, time + duration, title, chips, live progress.
class _ClassCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int startMin;
  final int endMin;
  final int nowMin;
  final bool isLive;
  final bool isPast;
  final VoidCallback onTap;

  const _ClassCard({
    required this.item,
    required this.startMin,
    required this.endMin,
    required this.nowMin,
    required this.isLive,
    required this.isPast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final name = (item['course_name'] ?? item['course_title'] ?? 'Course').toString();
    final code = (item['course_code'] ?? '').toString();
    final type = (item['course_type'] ?? '').toString();
    final faculty = (item['faculty'] ?? '').toString();
    final venue = (item['venue'] ?? item['room_no'] ?? 'TBA').toString();
    final slot = VtopHelpers.cleanSlot(item['slot']?.toString());
    final isLab = VtopHelpers.isLabCourse(courseType: type, courseSlot: slot);
    final accent = isLab ? p.orange : p.blue;
    final timed = startMin < (1 << 29);
    final duration = timed ? endMin - startMin : 0;
    final range = VtopHelpers.formatItemTimeRange(item);

    Widget chip(IconData icon, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: p.soft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: p.inkMuted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: p.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        );

    return Opacity(
      opacity: isPast ? 0.6 : 1,
      child: NexusSpringPress(
        scaleDown: 0.985,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isLive ? accent : p.line,
              width: isLive ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 14, color: accent),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                range.isEmpty ? 'Scheduled' : range,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                ),
                              ),
                            ),
                            if (duration > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${duration}m',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: p.inkMuted,
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (isLive)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimeRadarWave(color: p.red, size: 12),
                                  const SizedBox(width: 5),
                                  Text(
                                    'NOW',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: p.red,
                                    ),
                                  ),
                                ],
                              )
                            else if (isPast)
                              Icon(Icons.check_circle_rounded, size: 16, color: p.green),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: p.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [code, type].where((e) => e.isNotEmpty).join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: p.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            chip(Icons.location_on_outlined, venue),
                            if (slot.isNotEmpty) chip(Icons.grid_view_rounded, slot),
                            if (faculty.isNotEmpty)
                              chip(Icons.person_outline_rounded, faculty),
                          ],
                        ),
                        if (isLive && duration > 0) ...[
                          const SizedBox(height: 10),
                          NexusAnimatedProgressBar(
                            percentage:
                                ((nowMin - startMin) / duration * 100).clamp(0.0, 100.0),
                            height: 4,
                            color: accent,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
