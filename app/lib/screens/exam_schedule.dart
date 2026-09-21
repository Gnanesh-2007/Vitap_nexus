import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/vtop_providers.dart';
import '../services/storage_service.dart';

class ExamScheduleScreen extends ConsumerStatefulWidget {
  const ExamScheduleScreen({super.key});

  @override
  ConsumerState<ExamScheduleScreen> createState() =>
      _ExamScheduleScreenState();
}

class _ExamScheduleScreenState extends ConsumerState<ExamScheduleScreen> {
  int _selectedCategoryIndex = 0;

  // Dark sleek theme palette matching reference design
  static const _bg = Color(0xFF0D0F12);
  static const _cardBg = Color(0xFF1A1C20);
  static const _pillActiveBg = Color(0xFF38433C);
  static const _pillInactiveBg = Color(0xFF1E2126);
  static const _badgeBg = Color(0xFF282B31);
  static const _reportingBg = Color(0xFF141619);
  static const _muted = Color(0xFF8E9299);
  static const _green = Color(0xFF34C759);
  static const _blue = Color(0xFF356AE6);

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
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(lastSyncedTime, examAsync.isLoading),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: Colors.white,
                backgroundColor: _cardBg,
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
  Widget _buildTopBar(DateTime? lastSyncedTime, bool isRefreshing) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 24,
            ),
            splashRadius: 22,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Exam Schedule',
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Last Synced: ${_formatLastSynced(lastSyncedTime)}',
                  style: GoogleFonts.dmSans(
                    color: _muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: isRefreshing ? null : _onRefresh,
            icon: isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
            splashRadius: 22,
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
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(16),
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
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
              color: _cardBg,
              borderRadius: BorderRadius.circular(18),
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
                  horizontal: 24,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? _pillActiveBg : _pillInactiveBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  formattedTitle,
                  style: GoogleFonts.dmSans(
                    color: isSelected ? Colors.white : _muted,
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Structured Exam Card matching Reference Screenshot ──
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
    final isToday = status == 'Today';
    final isUpcoming = status == 'Upcoming';
    final statusDotColor = isToday
        ? _green
        : (isUpcoming ? _blue : const Color(0xFF9E9E9E));
    final statusTextColor = isToday
        ? _green
        : (isUpcoming ? Colors.white : const Color(0xFFB0B4BC));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
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
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _badgeBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    dateBadgeText,
                    style: GoogleFonts.dmSans(
                      color: const Color(0xFFE0E2E7),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _badgeBg,
                  borderRadius: BorderRadius.circular(20),
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
                      style: GoogleFonts.dmSans(
                        color: statusTextColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Course Name & Code
          Text(
            courseName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 18.5,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          if (courseCode.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              courseCode,
              style: GoogleFonts.dmSans(
                color: _muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 18),

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
                    const SizedBox(height: 15),
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
                    const SizedBox(height: 15),
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
                color: _reportingBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: _muted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reporting: $reportingTime',
                    style: GoogleFonts.dmSans(
                      color: const Color(0xFFD0D4DC),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
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
              style: GoogleFonts.dmSans(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.dmSans(
            color: Colors.white,
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
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                      color: const Color(0xFF2E1C1C),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFE57373),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load exam schedule',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _cardBg,
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
