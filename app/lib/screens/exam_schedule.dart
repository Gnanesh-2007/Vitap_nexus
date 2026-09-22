import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/vtop_providers.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_formatter.dart';

class ExamScheduleScreen extends ConsumerStatefulWidget {
  const ExamScheduleScreen({super.key});

  @override
  ConsumerState<ExamScheduleScreen> createState() =>
      _ExamScheduleScreenState();
}

class _ExamScheduleScreenState extends ConsumerState<ExamScheduleScreen> {
  int _selectedCategoryIndex = 0;

  // Campus Editorial Palette
  AppPalette get _palette => AppPalette.of(context);
  Color get _paper => _palette.paper;
  Color get _surface => _palette.surface;
  Color get _ink => _palette.ink;
  Color get _navy => _palette.navy;
  Color get _blue => _palette.blue;
  Color get _orange => _palette.orange;
  Color get _green => _palette.green;
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
              ErrorFormatter.format(e, fallback: 'Unable to update exam schedule. Please try again.'),
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

  String _computeStatus(String dateStr) {
    if (dateStr.isEmpty) return 'Upcoming';
    try {
      DateTime? examDt;
      for (final fmt in [
        DateFormat('dd-MMM-yyyy'),
        DateFormat('dd/MM/yyyy'),
        DateFormat('yyyy-MM-dd'),
        DateFormat('dd-MM-yyyy'),
        DateFormat('d-MMM-yyyy'),
        DateFormat('dd-MMM-yy'),
      ]) {
        try {
          examDt = fmt.parse(dateStr.trim());
          break;
        } catch (_) {}
      }
      if (examDt != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final examDay = DateTime(examDt.year, examDt.month, examDt.day);
        if (examDay.isBefore(today)) return 'Completed';
        if (examDay.isAtSameMomentAs(today)) return 'Today';
        return 'Upcoming';
      }
    } catch (_) {}
    return 'Upcoming';
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
                color: _navy,
                backgroundColor: _surface,
                child: examAsync.when(
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EXAMINATIONS',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: _orange,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Exam Schedule',
                  style: GoogleFonts.dmSans(
                    color: _ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
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
          ),
          Material(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: isRefreshing ? null : _onRefresh,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _line),
                ),
                child: isRefreshing
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(_navy),
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: _navy,
                        size: 20,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Main Content with Filter Tabs ──
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
                    child: const Icon(
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
    final currentGroup = groups[validIndex] as Map<String, dynamic>? ?? {};
    final subjects = (currentGroup['subjects'] as List<dynamic>?) ?? [];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _buildCategoryPills(groups, validIndex),
        const SizedBox(height: 18),
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
  }

  // ── Category Pills (CAT-1, CAT-2, FAT) ──
  Widget _buildCategoryPills(List<dynamic> groups, int selectedIdx) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: groups.asMap().entries.map((entry) {
          final idx = entry.key;
          final group = entry.value as Map<String, dynamic>? ?? {};
          final rawType = (group['exam_type'] ?? 'Exam').toString();
          final formattedTitle = _formatExamType(rawType);
          final isSelected = idx == selectedIdx;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedCategoryIndex = idx;
                });
              },
              borderRadius: BorderRadius.circular(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? _navy : _surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? _navy : _line,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _navy.withValues(alpha: 0.16),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  formattedTitle,
                  style: GoogleFonts.dmSans(
                    color: isSelected ? Colors.white : _muted,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
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

    // Slot/Session badge text (e.g. "18-Aug-2026 • AN1")
    final sessionTag = slot.isNotEmpty ? slot : examSession;
    final dateBadgeText = sessionTag.isNotEmpty
        ? '$examDate • $sessionTag'
        : examDate;

    // Status: Completed / Today / Upcoming
    final status = _computeStatus(examDate);
    final isCompleted = status == 'Completed';
    final isToday = status == 'Today';

    final Color statusDotColor;
    final Color statusBgColor;
    final Color statusTextColor;

    if (isCompleted) {
      statusDotColor = _green;
      statusBgColor = const Color(0xFFE8F4EF);
      statusTextColor = _green;
    } else if (isToday) {
      statusDotColor = _blue;
      statusBgColor = const Color(0xFFEAF0FD);
      statusTextColor = _blue;
    } else {
      statusDotColor = _orange;
      statusBgColor = const Color(0xFFF9ECE7);
      statusTextColor = _orange;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0617202A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Date • Slot Pill (Left) & Status Badge (Right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (dateBadgeText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _line),
                  ),
                  child: Text(
                    dateBadgeText,
                    style: GoogleFonts.spaceGrotesk(
                      color: _navy,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusDotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: GoogleFonts.spaceGrotesk(
                        color: statusTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Course Name & Code
          Text(
            courseName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          if (courseCode.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              courseCode,
              style: GoogleFonts.spaceGrotesk(
                color: _muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
          const SizedBox(height: 16),

          // 2x2 Details Grid (Time, Venue, Seat Location, Seat Number)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column (Time & Seat Location)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldMetric(
                      icon: Icons.access_time_rounded,
                      label: 'Time',
                      value: examTime.isNotEmpty ? examTime : '—',
                    ),
                    const SizedBox(height: 14),
                    _buildFieldMetric(
                      icon: Icons.event_seat_rounded,
                      label: 'Seat Location',
                      value: seatLocation.isNotEmpty ? seatLocation : '—',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Right Column (Venue & Seat Number)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldMetric(
                      icon: Icons.location_on_rounded,
                      label: 'Venue',
                      value: venue.isNotEmpty ? venue : '—',
                    ),
                    const SizedBox(height: 14),
                    _buildFieldMetric(
                      icon: Icons.tag_rounded,
                      label: 'Seat Number',
                      value: seatNumber.isNotEmpty ? seatNumber : '—',
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Bottom Reporting Inset Capsule
          if (reportingTime.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 15,
                    color: _navy,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reporting: $reportingTime',
                    style: GoogleFonts.spaceGrotesk(
                      color: _ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 250.ms, delay: Duration(milliseconds: idx * 60));
  }

  Widget _buildFieldMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _muted),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.dmSans(
            color: _ink,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  // ── Loading state ──
  Widget _buildLoading() {
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
                      foregroundColor: Colors.white,
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
