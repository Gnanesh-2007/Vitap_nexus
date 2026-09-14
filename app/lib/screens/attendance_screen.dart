import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/vtop_providers.dart';
import '../theme/app_theme.dart';
import '../utils/vtop_helpers.dart';
import '../widgets/mesh_ambient_background.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

// ─────────────────────────────────────────────
// Professional minimalist palette
// Kept at file scope so both the screen and calculator
// modal can use the same design tokens.
// ─────────────────────────────────────────────
const Color _background = Color(0xFF0F1117);
const Color _surface = Color(0xFF171B24);
const Color _surfaceLight = Color(0xFF1C202A);
const Color _border = Color(0xFF2A2F3A);

const Color _accent = Color(0xFF8B8FD8);
const Color _accentSoft = Color(0xFFB7B9E8);

const Color _textPrimary = Color(0xFFF4F4F5);
const Color _textSecondary = Color(0xFF9CA3AF);
const Color _textMuted = Color(0xFF687080);

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

  Map<String, dynamic> _calculateBunkStats(int attended, int total, {double target = 75.0}) {
    if (total == 0) {
      return {'canBunk': true, 'count': 0, 'percentage': 100.0};
    }

    final double currentPercentage = (attended / total) * 100;
    final double targetFraction = target / 100.0;

    if (currentPercentage >= target) {
      // attended / (total + X) >= targetFraction => X <= (attended - targetFraction * total) / targetFraction
      final int canBunk = ((attended - targetFraction * total) / targetFraction).floor();
      return {
        'canBunk': true,
        'count': canBunk < 0 ? 0 : canBunk,
        'percentage': currentPercentage,
      };
    } else {
      // (attended + Y) / (total + Y) >= targetFraction => Y >= (targetFraction * total - attended) / (1 - targetFraction)
      final double needed = (targetFraction * total - attended) / (1.0 - targetFraction);
      final int mustAttend = needed.ceil();
      return {
        'canBunk': false,
        'count': mustAttend < 1 ? 1 : mustAttend,
        'percentage': currentPercentage,
      };
    }
  }

  Color _getStatusColor(double percentage) {
    if (percentage >= 85) return const Color(0xFF6FBF9A);
    if (percentage >= 75) return const Color(0xFF8B8FD8);
    if (percentage >= 65) return const Color(0xFFD2A85A);
    return const Color(0xFFD47777);
  }

  void _showCalculatorSheet(BuildContext context, {int initialAttended = 0, int initialTotal = 0, String? courseName}) {
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

  @override
  Widget build(BuildContext context) {
    final attendanceAsync = ref.watch(attendanceProvider);

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        title: Text(
          'Attendance',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Attendance Calculator',
            icon: const Icon(Icons.calculate_outlined, color: _accentSoft),
            onPressed: () => _showCalculatorSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.refresh(attendanceProvider),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: _surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: _textSecondary,
              labelStyle: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Theory Classes'),
                Tab(text: 'Lab / Practical Classes'),
              ],
            ),
          ),
        ),
      ),
      body: MeshAmbientBackground(
        child: attendanceAsync.when(
          data: (attendanceList) {
            if (attendanceList.isEmpty) {
              return Center(
                child: Text(
                  'No attendance records found for this semester.',
                  style: GoogleFonts.manrope(color: _textSecondary),
                ),
              );
            }

            // Split into Theory and Lab
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
                _buildAttendanceList(theoryList, isLabTab: false),
                _buildAttendanceList(labList, isLabTab: true),
              ],
            );
          },
          loading: () => _buildSkeletonLoading(),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                  const SizedBox(height: 16),
                  Text('Failed to load attendance', style: GoogleFonts.manrope(fontSize: 18, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(err.toString(), textAlign: TextAlign.center, style: const TextStyle(color: _textMuted, fontSize: 12)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => ref.refresh(attendanceProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.calculate_rounded, color: Colors.white),
        label: Text('Calculator', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        onPressed: () => _showCalculatorSheet(context),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 140,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08));
  }

  Widget _buildAttendanceList(List<dynamic> list, {required bool isLabTab}) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          isLabTab ? 'No lab courses found in this semester.' : 'No theory courses found.',
          style: GoogleFonts.manrope(color: const Color(0xFF94A3B8)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(attendanceProvider.future),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final course = list[index];
          final courseName = course['course_name'] ?? 'Course';
          final courseCode = course['course_code'] ?? '';
          final slot = course['course_slot'] ?? '';
          final faculty = course['faculty'] ?? '';
          final attended = int.tryParse(course['attended_classes']?.toString() ?? '0') ?? 0;
          final total = int.tryParse(course['total_classes']?.toString() ?? '0') ?? 0;
          final rawPercentageStr = course['attendance_percentage']?.toString().replaceAll('%', '').trim() ?? '0';
          final percentage = double.tryParse(rawPercentageStr) ?? (total > 0 ? (attended / total) * 100 : 0.0);

          final bunkStats = _calculateBunkStats(attended, total);
          final statusColor = _getStatusColor(percentage);

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: percentage < 75 ? AppTheme.error.withValues(alpha: 0.4) : AppTheme.cardBorder,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Code, Slot, and Percentage
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _surfaceLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        courseCode,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (slot.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isLabTab ? _accent.withValues(alpha: 0.10) : _surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                          border: isLabTab ? Border.all(color: _accent.withValues(alpha: 0.25)) : null,
                        ),
                        child: Text(
                          slot,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isLabTab ? _accentSoft : _textSecondary,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Course Name
                Text(
                  courseName,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (faculty.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    faculty,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: total > 0 ? (attended / total) : 0,
                    minHeight: 8,
                    backgroundColor: AppTheme.surfaceLight,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                const SizedBox(height: 12),

                // Footer Row: Attended / Total + Bunk / Attend Recommendation
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$attended / $total Classes Attended',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showCalculatorSheet(
                        context,
                        initialAttended: attended,
                        initialTotal: total,
                        courseName: courseName,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: bunkStats['canBunk']
                              ? const Color(0xFF6FBF9A).withValues(alpha: 0.10)
                              : const Color(0xFFD47777).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: bunkStats['canBunk']
                                ? const Color(0xFF6FBF9A).withValues(alpha: 0.28)
                                : const Color(0xFFD47777).withValues(alpha: 0.28),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              bunkStats['canBunk'] ? Icons.check_circle_outline : Icons.info_outline,
                              size: 13,
                              color: bunkStats['canBunk'] ? const Color(0xFF6FBF9A) : const Color(0xFFD47777),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              bunkStats['canBunk']
                                  ? 'Can miss ${bunkStats['count']} classes'
                                  : 'Attend ${bunkStats['count']} next classes',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: bunkStats['canBunk']
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
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
          )
              .animate(delay: (35 * index).ms)
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
        },
      ),
    );
  }
}

// ─── Attendance Calculator Bottom Sheet ──────────────────────────────────────────

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
  late TextEditingController _attendedCtrl;
  late TextEditingController _totalCtrl;
  double _targetPercentage = 75.0;

  @override
  void initState() {
    super.initState();
    _attendedCtrl = TextEditingController(text: widget.initialAttended > 0 ? '${widget.initialAttended}' : '');
    _totalCtrl = TextEditingController(text: widget.initialTotal > 0 ? '${widget.initialTotal}' : '');
  }

  @override
  void dispose() {
    _attendedCtrl.dispose();
    _totalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attended = int.tryParse(_attendedCtrl.text.trim()) ?? 0;
    final total = int.tryParse(_totalCtrl.text.trim()) ?? 0;
    final currentPercentage = total > 0 ? (attended / total) * 100 : 0.0;

    String resultText = '';
    bool isSafe = true;

    if (total > 0 && attended <= total) {
      final targetFraction = _targetPercentage / 100.0;
      if (currentPercentage >= _targetPercentage) {
        final canBunk = ((attended - targetFraction * total) / targetFraction).floor();
        isSafe = true;
        resultText = canBunk > 0
            ? 'You can safely miss $canBunk more classes and maintain >= ${_targetPercentage.toInt()}%'
            : 'You are on the margin. Cannot miss any more classes!';
      } else {
        final double needed = (targetFraction * total - attended) / (1.0 - targetFraction);
        final mustAttend = needed.ceil();
        isSafe = false;
        resultText = 'You need to attend the next $mustAttend consecutive classes to reach ${_targetPercentage.toInt()}%';
      }
    }

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(top: BorderSide(color: _border, width: 1.0)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Icon(Icons.calculate_rounded, color: _accentSoft, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Attendance Calculator',
                  style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            if (widget.courseName != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.courseName!,
                style: GoogleFonts.manrope(fontSize: 12, color: _accent),
              ),
            ],
            const SizedBox(height: 20),

            // Attended & Total Inputs
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Attended Classes', style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF94A3B8))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _attendedCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'e.g. 18',
                          hintStyle: GoogleFonts.manrope(
                            color: _textMuted,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.check,
                            color: _accentSoft,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: _surfaceLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: _accent,
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Classes', style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF94A3B8))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _totalCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'e.g. 22',
                          hintStyle: GoogleFonts.manrope(
                            color: _textMuted,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.view_list_rounded,
                            color: _accent,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: _surfaceLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: _accent,
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Target Attendance Selection (75%, 80%, 85%, 90%)
            Text('Target Percentage', style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF94A3B8))),
            const SizedBox(height: 8),
            Row(
              children: [75.0, 80.0, 85.0, 90.0].map((target) {
                final isSelected = _targetPercentage == target;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _targetPercentage = target),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? _accent.withValues(alpha: 0.18) : _surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? _accent : _border,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${target.toInt()}%',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? _textPrimary : _textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Calculation Result Banner
            if (total > 0 && attended <= total) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSafe ? const Color(0xFF6FBF9A).withValues(alpha: 0.10) : const Color(0xFFD47777).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSafe ? const Color(0xFF6FBF9A).withValues(alpha: 0.28) : const Color(0xFFD47777).withValues(alpha: 0.28),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current Attendance: ${currentPercentage.toStringAsFixed(1)}%',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: isSafe ? const Color(0xFF6FBF9A) : const Color(0xFFD47777)),
                        ),
                        Icon(isSafe ? Icons.check_circle : Icons.warning_amber_rounded, color: isSafe ? const Color(0xFF6FBF9A) : const Color(0xFFD47777), size: 20),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      resultText,
                      style: GoogleFonts.manrope(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
