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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Timetable',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: p.ink,
                            height: 1.05,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          todayCount == 0
                              ? 'Nothing scheduled today'
                              : '$todayCount ${todayCount == 1 ? 'class' : 'classes'} today',
                          style: GoogleFonts.dmSans(fontSize: 13, color: p.inkMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: 'Refresh timetable',
                    child: GestureDetector(
                      onTap: timetableAsync.isLoading ? null : _refreshTimetable,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: p.soft, shape: BoxShape.circle),
                        child: Icon(Icons.refresh_rounded, size: 20, color: p.ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
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
                          duration: const Duration(milliseconds: 360),
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
                      loading: () => const NexusLoadingState(title: 'Loading timetable...'),
                      error: (err, _) => _buildErrorView(err.toString()),
                    ),
            ),
          ],
        ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
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
const _subjectPalette = [
  Color(0xFF6C7CFF), Color(0xFF14B8A6), Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFF22C55E),
  Color(0xFF8B5CF6), Color(0xFFEAB308), Color(0xFF06B6D4), Color(0xFFF43F5E), Color(0xFF84CC16),
];

Color _subjectColor(String code) {
  var h = 0;
  for (final u in code.codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  return _subjectPalette[h % _subjectPalette.length];
}

/// Seven day pills; the selected one glows as a capsule that slides with the pager.
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

  static const _names = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    const n = 7;
    final pos = progress.clamp(0.0, (n - 1).toDouble());
    final sel = pos.round();
    final accent = Theme.of(context).colorScheme.primary;
    final hsl = HSLColor.fromColor(accent);
    final capsule = hsl.withLightness(hsl.lightness.clamp(0.0, 0.45)).toColor();

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth / n;
        return SizedBox(
          height: 78,
          child: Stack(
            children: [
              Positioned(
                left: pos * w + 2,
                top: 0,
                width: w - 4,
                height: 78,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [capsule, Color.lerp(capsule, const Color(0xFFFF6FA8), 0.5)!],
                    ),
                    boxShadow: [BoxShadow(color: capsule.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6))],
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
                              _names[i],
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: i == sel ? Colors.white70 : p.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${dateFor(i).day}',
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: i == sel ? Colors.white : p.ink,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var k = 0; k < counts[i].clamp(0, 5); k++)
                                  Container(
                                    width: 4,
                                    height: 4,
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: i == sel ? Colors.white : p.inkMuted.withValues(alpha: 0.7),
                                    ),
                                  ),
                                if (counts[i] == 0)
                                  Container(
                                    width: 8,
                                    height: 2,
                                    color: i == sel ? Colors.white54 : p.line,
                                  ),
                              ],
                            ),
                            if (i == todayIndex && i != sel)
                              Container(
                                margin: const EdgeInsets.only(top: 3),
                                width: 14,
                                height: 2.5,
                                decoration: BoxDecoration(color: capsule, borderRadius: BorderRadius.circular(2)),
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
      },
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
    final text = h == 0 ? '$m min break' : (m == 0 ? '$h h break' : '$h h $m min break');
    return Padding(
      padding: const EdgeInsets.fromLTRB(66, 0, 0, 10),
      child: Row(
        children: [
          Icon(Icons.local_cafe_rounded, size: 14, color: p.inkMuted),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: p.inkMuted)),
        ],
      ),
    );
  }
}

/// A class on the day's timeline: time on the left, a coloured card on the right.
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

  String _clock(int m) {
    final h = (m ~/ 60) % 24;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${(m % 60).toString().padLeft(2, '0')}';
  }

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
    final color = _subjectColor(code.isEmpty ? name : code);
    final timed = startMin < (1 << 29);
    final duration = timed ? endMin - startMin : 0;

    final fg = isLive ? Colors.white : p.ink;
    final sub = isLive ? Colors.white.withValues(alpha: 0.82) : p.inkMuted;

    Widget chip(IconData icon, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: isLive ? Colors.white.withValues(alpha: 0.2) : color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: isLive ? Colors.white : color),
              const SizedBox(width: 4),
              Text(text, style: GoogleFonts.dmSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: isLive ? Colors.white : p.ink)),
            ],
          ),
        );

    final left = SizedBox(
      width: 56,
      child: timed
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_clock(startMin),
                    style: GoogleFonts.bricolageGrotesque(fontSize: 20, fontWeight: FontWeight.w800, color: p.ink, height: 1)),
                Text(startMin >= 720 ? 'PM' : 'AM',
                    style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: p.inkMuted)),
                const SizedBox(height: 6),
                Text('${duration}m', style: GoogleFonts.dmSans(fontSize: 11, color: p.inkMuted, fontWeight: FontWeight.w600)),
              ],
            )
          : const SizedBox.shrink(),
    );

    final card = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: isLive
              ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, Color.lerp(color, const Color(0xFF1A1033), 0.6)!])
              : null,
          color: isLive ? null : color.withValues(alpha: p.isDark ? 0.14 : 0.11),
          border: isLive ? null : Border.all(color: color.withValues(alpha: 0.28)),
          boxShadow: isLive ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isLive)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('HAPPENING NOW  ·  ${endMin - nowMin} min left',
                    style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white)),
              ),
            Text(name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.bricolageGrotesque(fontSize: 17.5, fontWeight: FontWeight.w800, color: fg, height: 1.12, letterSpacing: -0.2)),
            const SizedBox(height: 4),
            Text([code, if (faculty.isNotEmpty) faculty].join('  ·  '),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 12, color: sub, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                chip(Icons.place_rounded, venue),
                if (slot.isNotEmpty) chip(Icons.grid_view_rounded, slot),
                if (isLab) chip(Icons.science_rounded, 'Lab'),
              ],
            ),
            if (isLive && timed && duration > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ((nowMin - startMin) / duration).clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Opacity(
      opacity: isPast ? 0.55 : 1,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          left,
          Expanded(child: card),
        ],
      ),
    );
  }
}
