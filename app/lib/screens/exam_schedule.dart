import 'package:flutter/material.dart';
import '../widgets/nexus_segmented.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/vtop_providers.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shadcn/shadcn_ui.dart';

class ExamScheduleScreen extends ConsumerStatefulWidget {
  const ExamScheduleScreen({super.key});

  @override
  ConsumerState<ExamScheduleScreen> createState() =>
      _ExamScheduleScreenState();
}

class _ExamScheduleScreenState extends ConsumerState<ExamScheduleScreen> {
  int _selectedCategoryIndex = 0;
  final PageController _pager = PageController();

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  // Responsive dynamic palette getters
  AppPalette get _palette => AppPalette.of(context);
  Color get _paper => _palette.paper;
  Color get _surface => _palette.surface;
  Color get _ink => _palette.ink;
  Color get _navy => _palette.navy;
  Color get _muted => _palette.inkMuted;
  Color get _line => _palette.line;
  Color get _soft => _palette.soft;



  Future<void> _onRefresh() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await refreshExamSchedule(ref);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2A1C1C),
            content: Text(
              'Could not update exam schedule: $e',
              style: GoogleFonts.dmSans(color: Colors.white, fontSize: 12),
            ),
          ),
        );
      }
    }
  }

  String _formatExamType(String raw) {
    final clean = raw.trim();
    final upper = clean.toUpperCase();

    if (upper.contains('CONTINUOUS ASSESSMENT TEST - 1') ||
        upper.contains('CONTINUOUS ASSESSMENT TEST 1') ||
        upper.contains('CAT-1') ||
        upper.contains('CAT 1') ||
        upper.contains('CAT-I') ||
        upper == 'CAT I') {
      return 'CAT - 1';
    }
    if (upper.contains('CONTINUOUS ASSESSMENT TEST - 2') ||
        upper.contains('CONTINUOUS ASSESSMENT TEST 2') ||
        upper.contains('CAT-2') ||
        upper.contains('CAT 2') ||
        upper.contains('CAT-II') ||
        upper == 'CAT II') {
      return 'CAT - 2';
    }
    if (upper.contains('FINAL ASSESSMENT TEST') ||
        upper.contains('FINAL ASSESSMENT') ||
        upper.contains('TERM END') ||
        upper.contains('TEE') ||
        upper.contains('FAT')) {
      return 'FAT';
    }
    if (upper.contains('MID TERM') || upper.contains('MID-TERM')) {
      return 'MID - TERM';
    }

    return clean;
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
    final examAsync = ref.watch(examScheduleProvider);
    final lastSyncedTime = StorageService.getMemoryTimestamp('exam_schedule');

    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(lastSyncedTime, examAsync.isLoading, examAsync.value ?? []),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                notificationPredicate: (n) => n.depth <= 1,
                color: _navy,
                backgroundColor: _surface,
                child: (examAsync.hasValue && examAsync.value!.isNotEmpty)
                    ? _buildContent(examAsync.value!)
                    : (StorageService.getMemoryCache('exam_schedule') is List && (StorageService.getMemoryCache('exam_schedule') as List).isNotEmpty)
                        ? _buildContent(List<dynamic>.from(StorageService.getMemoryCache('exam_schedule')))
                        : examAsync.when(
                            data: (groups) => _buildContent(groups),
                            loading: () => _buildLoading(),
                            error: (err, _) => _buildError(err),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Navigation Bar ──
  Widget _buildTopBar(DateTime? lastSyncedTime, bool isRefreshing, List<dynamic> groups) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exams',
                  style: GoogleFonts.bricolageGrotesque(
                    color: _ink,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatLastSynced(lastSyncedTime).replaceAll(' 💾', ''),
                  style: GoogleFonts.dmSans(color: _muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: isRefreshing ? null : _onRefresh,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: _soft, shape: BoxShape.circle),
              child: isRefreshing
                  ? Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(_ink)),
                      ),
                    )
                  : Icon(Icons.refresh_rounded, color: _ink, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _parseDate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final fixed = text.replaceAllMapped(
      RegExp(r'[A-Za-z]+'),
      (m) => '${m[0]![0].toUpperCase()}${m[0]!.substring(1).toLowerCase()}',
    );
    for (final fmt in [
      DateFormat('dd-MMM-yyyy', 'en_US'),
      DateFormat('d-MMM-yyyy', 'en_US'),
      DateFormat('dd-MMM-yy', 'en_US'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('dd-MM-yyyy'),
    ]) {
      try {
        return fmt.parseStrict(fixed);
      } catch (_) {}
    }
    return null;
  }

  // ── Main Content with Filter Tabs ──
  Widget _buildSegmented(List<dynamic> groups, int validIndex) {
    final labels = [
      for (final g in groups) _formatExamType(((g is Map ? g['exam_type'] : null) ?? 'Exam').toString()),
    ];
    return AnimatedBuilder(
      animation: _pager,
      builder: (context, _) {
        final page = (_pager.hasClients && _pager.page != null) ? _pager.page! : validIndex.toDouble();
        return NexusSegmented(
          labels: labels,
          position: page,
          onSelect: (i) {
            if (_pager.hasClients) {
              _pager.animateToPage(i, duration: const Duration(milliseconds: 340), curve: Curves.easeOutCubic);
            } else {
              setState(() => _selectedCategoryIndex = i);
            }
          },
        );
      },
    );
  }

  Widget _buildContent(List<dynamic> groups) {
    if (groups.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _line),
                    ),
                    child: Icon(
                      Icons.event_available_rounded,
                      color: _muted,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No exam schedule available',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pull down to refresh with latest data',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final validIndex = _selectedCategoryIndex < groups.length
        ? _selectedCategoryIndex
        : 0;

    final tabs = <ShadcnTab>[];
    for (final g in groups) {
      final m = g is Map ? g : const {};
      final count = (m['subjects'] as List?)?.length ?? 0;
      tabs.add(ShadcnTab(
        label: _formatExamType((m['exam_type'] ?? 'Exam').toString()),
        badge: count > 0 ? '$count' : null,
      ));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
          child: _buildSegmented(groups, validIndex),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pager,
            itemCount: groups.length,
            onPageChanged: (i) {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategoryIndex = i);
            },
            itemBuilder: (context, gi) {
              final group = groups[gi] as Map<String, dynamic>? ?? {};
              final subjects = (group['subjects'] as List<dynamic>?) ?? [];
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  if (subjects.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _line),
                      ),
                      child: Center(
                        child: Text(
                          'No subjects scheduled for this category.',
                          style: GoogleFonts.dmSans(
                            color: _muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    ...subjects.asMap().entries.map((entry) {
                      final exam = entry.value as Map<String, dynamic>? ?? {};
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildExamCard(exam, entry.key),
                      );
                    }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Structured Exam Card in Campus Editorial Theme ──
  Widget _buildExamCard(Map<String, dynamic> exam, int idx) {
    final courseCode = (exam['course_code'] ?? '').toString().trim();
    final courseName = (exam['course_name'] ?? 'Course').toString().trim();
    final examDate = (exam['exam_date'] ?? '').toString().trim();
    final slot = (exam['slot'] ?? '').toString().trim();
    final examSession = (exam['exam_session'] ?? '').toString().trim();
    final examTime = (exam['exam_time'] ?? '').toString().trim();
    final venue = (exam['venue'] ?? '').toString().trim();
    final seatLocation = (exam['seat_location'] ?? '').toString().trim();
    final seatNumber = (exam['seat_number'] ?? '').toString().trim();
    final reportingTime = (exam['reporting_time'] ?? '').toString().trim();

    final date = _parseDate(examDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = date == null ? null : DateTime(date.year, date.month, date.day).difference(today).inDays;
    final isCompleted = days != null && days < 0;
    final isToday = days == 0;
    final sessionTag = slot.isNotEmpty ? slot : examSession;

    final String countdown = days == null
        ? ''
        : isCompleted
            ? 'Done'
            : isToday
                ? 'TODAY'
                : days == 1
                    ? 'Tomorrow'
                    : 'In $days days';
    final hsl = HSLColor.fromColor(_palette.navy);
    final base = hsl.withLightness(hsl.lightness.clamp(0.0, 0.42)).toColor();
    final urgent = !isCompleted && days != null && days <= 2;
    final c1 = isCompleted ? _soft : (urgent ? const Color(0xFFE5484D) : base);
    final c2 = isCompleted ? _soft : (urgent ? const Color(0xFF7A1540) : Color.lerp(base, const Color(0xFF1A0E3A), 0.6)!);
    final onTop = isCompleted ? _muted : Colors.white;

    Widget detail(IconData icon, String label, String value) => value.isEmpty || value == '-'
        ? const SizedBox.shrink()
        : SizedBox(
            width: 138,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 15, color: _ink),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label.toUpperCase(),
                          style: GoogleFonts.dmSans(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: _muted)),
                      Text(value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: _ink, height: 1.2)),
                    ],
                  ),
                ),
              ],
            ),
          );

    return Opacity(
      opacity: isCompleted ? 0.62 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c1, c2]),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        date == null ? '--' : '${date.day}',
                        style: GoogleFonts.bricolageGrotesque(fontSize: 46, fontWeight: FontWeight.w800, color: onTop, height: 0.95, letterSpacing: -1.5),
                      ),
                      Text(
                        date == null ? examDate : '${DateFormat('MMM').format(date).toUpperCase()}  ·  ${DateFormat('EEE').format(date).toUpperCase()}',
                        style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: onTop.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (countdown.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: isCompleted ? _line : Colors.white, borderRadius: BorderRadius.circular(16)),
                          child: Text(countdown,
                              style: GoogleFonts.bricolageGrotesque(
                                  fontSize: 13.5, fontWeight: FontWeight.w800, color: isCompleted ? _muted : (urgent ? const Color(0xFFB4232A) : base))),
                        ),
                      if (sessionTag.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(sessionTag, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: onTop.withValues(alpha: 0.9))),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(courseName,
                      style: GoogleFonts.bricolageGrotesque(fontSize: 19, fontWeight: FontWeight.w800, color: _ink, height: 1.12, letterSpacing: -0.3)),
                  if (courseCode.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(courseCode, style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: _muted)),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 12,
                    children: [
                      detail(Icons.schedule_rounded, 'Time', examTime),
                      detail(Icons.alarm_rounded, 'Report by', reportingTime),
                      detail(Icons.apartment_rounded, 'Venue', venue),
                      detail(Icons.meeting_room_rounded, 'Room', seatLocation),
                      detail(Icons.event_seat_rounded, 'Seat', seatNumber),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(_navy),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading exam schedule...',
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  // ── Error state ──
  Widget _buildError(Object err) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCEDEA),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFC84C43),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load exam schedule',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    err.toString(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: _muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _onRefresh,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      'Try Again',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: _palette.onNavy,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
