import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/vtop_providers.dart';
import '../services/storage_service.dart';
import '../utils/vtop_helpers.dart';
import '../widgets/last_synced_badge.dart';
import '../widgets/mesh_ambient_background.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

// ─────────────────────────────────────────────
// Dark Palette & Color Tokens
// ─────────────────────────────────────────────
const Color _background = Color(0xFF090A0F);
const Color _surface = Color(0xFF12151E);
const Color _surfaceLight = Color(0xFF1A1F2C);
const Color _border = Color(0xFF262C3A);

const Color _accent = Color(0xFF6366F1);
const Color _accentSoft = Color(0xFFA5B4FC);

const Color _textPrimary = Color(0xFFF8FAFC);
const Color _textSecondary = Color(0xFF94A3B8);
const Color _textMuted = Color(0xFF64748B);

const Color _success = Color(0xFF10B981);
const Color _warning = Color(0xFFF59E0B);
const Color _danger = Color(0xFFF43F5E);

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
      final int canBunk = ((attended - targetFraction * total) / targetFraction).floor();
      return {
        'canBunk': true,
        'count': canBunk < 0 ? 0 : canBunk,
        'percentage': currentPercentage,
      };
    } else {
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
    if (percentage >= 85) return _success;
    if (percentage >= 75) return _accentSoft;
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

  @override
  Widget build(BuildContext context) {
    final attendanceAsync = ref.watch(attendanceProvider);

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _background,
        title: Text(
          'Attendance',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: _textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Calculator',
            icon: const Icon(Icons.calculate_outlined, color: _accentSoft, size: 22),
            onPressed: () => _showCalculatorSheet(context),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: _textSecondary, size: 22),
            onPressed: () => ref.refresh(attendanceProvider.future),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_accent, Color(0xFF4F46E5)],
                ),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: _textSecondary,
              labelStyle: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold),
              unselectedLabelStyle: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Theory Classes'),
                Tab(text: 'Lab / Practical'),
              ],
            ),
          ),
        ),
      ),
      body: MeshAmbientBackground(
        child: Column(
          children: [
            LastSyncedBadge(
              lastSynced: StorageService.getMemoryTimestamp('attendance'),
              isRefreshing: attendanceAsync.isLoading,
              onRefresh: () => ref.refresh(attendanceProvider.future),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
            Expanded(
              child: attendanceAsync.when(
                data: (attendanceList) => _buildAttendanceContent(attendanceList),
                loading: () => _buildSkeletonLoading(),
                error: (err, stack) => _buildErrorView(err.toString()),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        elevation: 4,
        backgroundColor: _accent,
        icon: const Icon(Icons.calculate_rounded, color: Colors.white, size: 20),
        label: Text(
          'Calculator',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        onPressed: () => _showCalculatorSheet(context),
      ),
    );
  }

  Widget _buildAttendanceContent(List<dynamic> attendanceList) {
    if (attendanceList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_off_outlined, size: 48, color: _textMuted),
            const SizedBox(height: 12),
            Text(
              'No attendance records found.',
              style: GoogleFonts.manrope(color: _textSecondary, fontSize: 15),
            ),
          ],
        ),
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

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(attendanceProvider.future),
      color: _accent,
      backgroundColor: _surface,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildAttendanceList(theoryList, isLabTab: false),
          _buildAttendanceList(labList, isLabTab: true),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 40, color: _danger),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load attendance',
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(color: _textMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => ref.refresh(attendanceProvider.future),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Retry',
                style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 150,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.05));
  }

  Widget _buildAttendanceList(List<dynamic> list, {required bool isLabTab}) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          isLabTab ? 'No lab courses found' : 'No theory courses found',
          style: GoogleFonts.manrope(color: _textMuted, fontSize: 14),
        ),
      );
    }

    return RefreshIndicator(
      color: _accent,
      backgroundColor: _surface,
      onRefresh: () async => ref.refresh(attendanceProvider.future),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
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
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: percentage < 75 ? _danger.withValues(alpha: 0.35) : _border,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _accent.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        courseCode,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _accentSoft,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (slot.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          slot,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _textSecondary,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Text(
                  courseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    height: 1.2,
                  ),
                ),
                if (faculty.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    faculty,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: _textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                Stack(
                  children: [
                    Container(
                      height: 7,
                      decoration: BoxDecoration(
                        color: _surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (total > 0 ? (attended.toDouble() / total) : 0.0).clamp(0.0, 1.0),
                      child: Container(
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$attended / $total Attended',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _showCalculatorSheet(
                          context,
                          initialAttended: attended,
                          initialTotal: total,
                          courseName: courseName,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: bunkStats['canBunk']
                                ? _success.withValues(alpha: 0.12)
                                : _danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: bunkStats['canBunk']
                                  ? _success.withValues(alpha: 0.3)
                                  : _danger.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                bunkStats['canBunk']
                                    ? Icons.check_circle_rounded
                                    : Icons.warning_amber_rounded,
                                size: 13,
                                color: bunkStats['canBunk'] ? _success : _danger,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                bunkStats['canBunk']
                                    ? 'Can miss ${bunkStats['count']} classes'
                                    : 'Attend ${bunkStats['count']} next classes',
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: bunkStats['canBunk'] ? _success : _danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
              .animate(delay: (40 * index).ms)
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
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
    _attendedCtrl = TextEditingController(
      text: widget.initialAttended > 0 ? '${widget.initialAttended}' : '',
    );
    _totalCtrl = TextEditingController(
      text: widget.initialTotal > 0 ? '${widget.initialTotal}' : '',
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
            ? 'You can safely miss $canBunk more classes and maintain ≥ ${_targetPercentage.toInt()}%'
            : 'You are right on the limit. Avoid missing any more classes!';
      } else {
        final double needed = (targetFraction * total - attended) / (1.0 - targetFraction);
        final mustAttend = needed.ceil();
        isSafe = false;
        resultText = 'Attend the next $mustAttend consecutive classes to hit ${_targetPercentage.toInt()}%';
      }
    }

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: _border, width: 1.0)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calculate_rounded, color: _accentSoft, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance Planner',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      if (widget.courseName != null)
                        Text(
                          widget.courseName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: _accentSoft,
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
                    label: 'Attended Classes',
                    hint: 'e.g. 18',
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInputField(
                    controller: _totalCtrl,
                    label: 'Total Classes',
                    hint: 'e.g. 22',
                    icon: Icons.format_list_bulleted_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text(
              'Target Requirement',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [75.0, 80.0, 85.0, 90.0].map((target) {
                final isSelected = _targetPercentage == target;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _targetPercentage = target),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? _accent : _surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? _accentSoft : _border,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _accent.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          '${target.toInt()}%',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : _textSecondary,
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
                  color: isSafe ? _success.withValues(alpha: 0.1) : _danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSafe ? _success.withValues(alpha: 0.3) : _danger.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current Rate: ${currentPercentage.toStringAsFixed(1)}%',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            color: isSafe ? _success : _danger,
                            fontSize: 14,
                          ),
                        ),
                        Icon(
                          isSafe ? Icons.check_circle_rounded : Icons.warning_rounded,
                          color: isSafe ? _success : _danger,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      resultText,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: _textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
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
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.manrope(color: _textMuted, fontSize: 13),
            prefixIcon: Icon(icon, color: _accentSoft, size: 18),
            filled: true,
            fillColor: _surfaceLight,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              borderSide: const BorderSide(color: _accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}