import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/vtop_providers.dart';
import '../services/storage_service.dart';
import '../widgets/last_synced_badge.dart';

class ExamScheduleScreen extends ConsumerStatefulWidget {
  const ExamScheduleScreen({super.key});

  @override
  ConsumerState<ExamScheduleScreen> createState() =>
      _ExamScheduleScreenState();
}

class _ExamScheduleScreenState extends ConsumerState<ExamScheduleScreen> {
  // ── Editorial academic palette ──
  static const _paper = Color(0xFFF4F2ED);
  static const _surface = Color(0xFFFFFEFB);
  static const _ink = Color(0xFF17202A);
  static const _navy = Color(0xFF172B4D);
  static const _blue = Color(0xFF356AE6);
  static const _orange = Color(0xFFE47543);
  static const _green = Color(0xFF278B68);
  static const _red = Color(0xFFC84C43);
  static const _muted = Color(0xFF6E7681);
  static const _line = Color(0xFFE2DED5);
  static const _soft = Color(0xFFF0EEE8);

  TextStyle get _micro => GoogleFonts.spaceGrotesk(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      );

  Future<void> _onRefresh() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await refreshExamSchedule(ref);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not update exam schedule: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final examAsync = ref.watch(examScheduleProvider);

    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            LastSyncedBadge(
              lastSynced: StorageService.getMemoryTimestamp('exam_schedule'),
              isRefreshing: examAsync.isLoading,
              onRefresh: _onRefresh,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: _navy,
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

  // ── Top Bar ──
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line),
            ),
            child: const Icon(
              Icons.event_note_rounded,
              color: _navy,
              size: 20,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EXAMINATIONS',
                  style: _micro.copyWith(color: _orange),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Content ──
  Widget _buildContent(List<dynamic> groups) {
    if (groups.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
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
                      fontWeight: FontWeight.w600,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pull down to refresh',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
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

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index] as Map<String, dynamic>? ?? {};
        final examType = (group['exam_type'] ?? 'Exam').toString();
        final subjects = group['subjects'] as List<dynamic>? ?? [];

        return _buildExamGroup(examType, subjects, index);
      },
    );
  }

  // ── Exam Group (e.g. CAT-I, CAT-II, FAT) ──
  Widget _buildExamGroup(String examType, List<dynamic> subjects, int groupIdx) {
    final accent = _getGroupAccent(groupIdx);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  examType.toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${subjects.length} ${subjects.length == 1 ? "exam" : "exams"}',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Exam cards
          ...subjects.asMap().entries.map((entry) {
            final exam = entry.value as Map<String, dynamic>? ?? {};
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildExamCard(exam, accent, entry.key),
            );
          }),
        ],
      ),
    ).animate().fadeIn(
          duration: const Duration(milliseconds: 300),
          delay: Duration(milliseconds: groupIdx * 100),
        );
  }

  // ── Single Exam Card ──
  Widget _buildExamCard(Map<String, dynamic> exam, Color accent, int idx) {
    final courseCode = (exam['course_code'] ?? '').toString();
    final courseName = (exam['course_name'] ?? '').toString();
    final courseType = (exam['course_type'] ?? '').toString();
    final examDate = (exam['exam_date'] ?? '').toString();
    final examSession = (exam['exam_session'] ?? '').toString();
    final reportingTime = (exam['reporting_time'] ?? '').toString();
    final examTime = (exam['exam_time'] ?? '').toString();
    final venue = (exam['venue'] ?? '').toString();
    final seatNumber = (exam['seat_number'] ?? '').toString();
    final seatLocation = (exam['seat_location'] ?? '').toString();
    final slot = (exam['slot'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.04),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                if (courseCode.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      courseCode,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    courseName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                      height: 1.3,
                    ),
                  ),
                ),
                if (courseType.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      courseType,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: _muted,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Exam details grid
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              children: [
                // Date & Time row
                if (examDate.isNotEmpty || examTime.isNotEmpty)
                  _buildDetailRow(
                    Icons.calendar_today_rounded,
                    _buildDateTimeText(
                        examDate, examTime, examSession, reportingTime),
                    _blue,
                  ),

                // Venue row
                if (venue.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    Icons.location_on_outlined,
                    venue,
                    _green,
                  ),
                ],

                // Seat info row
                if (seatNumber.isNotEmpty || seatLocation.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    Icons.event_seat_rounded,
                    _buildSeatText(seatNumber, seatLocation),
                    _orange,
                  ),
                ],

                // Slot row
                if (slot.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    Icons.access_time_rounded,
                    'Slot: $slot',
                    _muted,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _ink.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  String _buildDateTimeText(
      String date, String time, String session, String reportingTime) {
    final parts = <String>[];
    if (date.isNotEmpty) parts.add(date);
    if (session.isNotEmpty) parts.add('($session)');
    if (time.isNotEmpty) parts.add('• $time');
    if (reportingTime.isNotEmpty) parts.add('• Report: $reportingTime');
    return parts.join(' ');
  }

  String _buildSeatText(String seatNumber, String seatLocation) {
    final parts = <String>[];
    if (seatNumber.isNotEmpty) parts.add('Seat $seatNumber');
    if (seatLocation.isNotEmpty) parts.add(seatLocation);
    return parts.join(' • ');
  }

  Color _getGroupAccent(int index) {
    const accents = [_blue, _orange, _green, _red, _navy];
    return accents[index % accents.length];
  }

  // ── Loading state ──
  Widget _buildLoading() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading exam schedule...',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
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

  // ── Error state ──
  Widget _buildError(Object err) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: _red,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load exam schedule',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pull down to try again',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
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
}
