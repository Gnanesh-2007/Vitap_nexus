import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shadcn/shadcn_ui.dart';
import '../widgets/motion/nexus_motion.dart';

// ============================================================================
// DATA MODELS
// ============================================================================

class CourseInputRow {
  final TextEditingController creditsController;
  String? selectedGrade;

  CourseInputRow({String credits = '', this.selectedGrade})
      : creditsController = TextEditingController(text: credits);

  void dispose() {
    creditsController.dispose();
  }
}

class SemesterGpaInputRow {
  final TextEditingController gpaController;

  SemesterGpaInputRow({String gpa = ''})
      : gpaController = TextEditingController(text: gpa);

  void dispose() {
    gpaController.dispose();
  }
}

// ============================================================================
// CGPA CALCULATOR SCREEN
// ============================================================================

class CgpaCalculatorScreen extends ConsumerStatefulWidget {
  const CgpaCalculatorScreen({super.key});

  @override
  ConsumerState<CgpaCalculatorScreen> createState() =>
      _CgpaCalculatorScreenState();
}

class _CgpaCalculatorScreenState extends ConsumerState<CgpaCalculatorScreen> {
  // 1. Semester GPA
  final List<CourseInputRow> _courseRows = [];
  double? _calculatedSemesterGpa;
  double? _calculatedSemesterCredits;

  // 2. Target CGPA Planner
  final TextEditingController _targetCurrentCgpaController =
      TextEditingController();
  final TextEditingController _targetCompletedSemsController =
      TextEditingController();
  final TextEditingController _targetGoalCgpaController =
      TextEditingController();
  double? _calculatedRequiredSgpa;
  bool? _isTargetAchievable;
  String? _targetFeedbackMessage;

  // 3. Cumulative GPA
  final List<SemesterGpaInputRow> _semesterGpaRows = [];
  double? _calculatedCumulativeGpa;

  // VTOP prefetch
  bool _isLoadingVtop = false;
  bool _hasPrefetchedVtop = false;

  final List<Map<String, dynamic>> _gradeOptions = [
    {'grade': 'S', 'points': 10, 'label': 'S (10 pts)', 'color': Color(0xFF10B981)},
    {'grade': 'A', 'points': 9, 'label': 'A (9 pts)', 'color': Color(0xFF3B82F6)},
    {'grade': 'B', 'points': 8, 'label': 'B (8 pts)', 'color': Color(0xFF6366F1)},
    {'grade': 'C', 'points': 7, 'label': 'C (7 pts)', 'color': Color(0xFF8B5CF6)},
    {'grade': 'D', 'points': 6, 'label': 'D (6 pts)', 'color': Color(0xFFF59E0B)},
    {'grade': 'E', 'points': 5, 'label': 'E (5 pts)', 'color': Color(0xFFEC4899)},
    {'grade': 'F', 'points': 0, 'label': 'F (0 pts)', 'color': Color(0xFFEF4444)},
  ];

  @override
  void initState() {
    super.initState();
    _initializeDefaultRows();
    _tryPrefetchVtopData();
  }

  void _initializeDefaultRows() {
    // Start with 3 clean empty course rows
    _courseRows.addAll([
      CourseInputRow(credits: '', selectedGrade: null),
      CourseInputRow(credits: '', selectedGrade: null),
      CourseInputRow(credits: '', selectedGrade: null),
    ]);

    // Start with 2 clean empty semester GPA rows
    _semesterGpaRows.addAll([
      SemesterGpaInputRow(gpa: ''),
      SemesterGpaInputRow(gpa: ''),
    ]);
  }

  Future<void> _tryPrefetchVtopData() async {
    final mem = StorageService.getMemoryCache('grades');
    if (mem is Map && mem.isNotEmpty) {
      _applyVtopGradeData(Map<String, dynamic>.from(mem));
      return;
    }

    final disk = await StorageService.getCache('grades');
    if (disk is Map && disk.isNotEmpty) {
      _applyVtopGradeData(Map<String, dynamic>.from(disk));
      return;
    }

    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.username == null) return;

    setState(() => _isLoadingVtop = true);
    try {
      final fresh = await apiService.fetchGradeHistory(
        username: auth.username ?? '',
        password: auth.password ?? '',
      );
      if (mounted && fresh.isNotEmpty) {
        _applyVtopGradeData(fresh);
      }
    } catch (_) {
      // Keep blank defaults
    } finally {
      if (mounted) setState(() => _isLoadingVtop = false);
    }
  }

  void _applyVtopGradeData(Map<String, dynamic> data) {
    if (_hasPrefetchedVtop) return;
    _hasPrefetchedVtop = true;

    try {
      final cgpaStr = data['cgpa']?.toString() ??
          data['current_cgpa']?.toString() ??
          data['cumulative_grade_point_average']?.toString();
      final double? parsedCgpa = double.tryParse(cgpaStr ?? '');

      final semesterHistory = data['semester_grades'] ??
          data['semesters'] ??
          data['grade_history'] ??
          [];

      if (semesterHistory is List && semesterHistory.isNotEmpty) {
        final List<SemesterGpaInputRow> fetchedRows = [];
        for (var sem in semesterHistory) {
          if (sem is Map) {
            final gpa = sem['gpa'] ?? sem['sgpa'] ?? sem['semester_gpa'];
            if (gpa != null) {
              fetchedRows.add(SemesterGpaInputRow(gpa: gpa.toString()));
            }
          }
        }

        if (fetchedRows.isNotEmpty) {
          setState(() {
            for (var row in _semesterGpaRows) {
              row.dispose();
            }
            _semesterGpaRows.clear();
            _semesterGpaRows.addAll(fetchedRows);
          });
        }

        if (parsedCgpa != null && parsedCgpa > 0) {
          _targetCurrentCgpaController.text = parsedCgpa.toStringAsFixed(2);
          _targetCompletedSemsController.text =
              semesterHistory.length.toString();
        }
      } else if (parsedCgpa != null && parsedCgpa > 0) {
        _targetCurrentCgpaController.text = parsedCgpa.toStringAsFixed(2);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    for (var row in _courseRows) {
      row.dispose();
    }
    for (var row in _semesterGpaRows) {
      row.dispose();
    }
    _targetCurrentCgpaController.dispose();
    _targetCompletedSemsController.dispose();
    _targetGoalCgpaController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // CALCULATIONS
  // ==========================================================================

  void _calculateSemesterGpa(AppPalette palette) {
    double totalCredits = 0.0;
    double totalGradePoints = 0.0;
    int filledCourses = 0;

    for (var row in _courseRows) {
      final credits = double.tryParse(row.creditsController.text.trim()) ?? 0.0;
      final grade = row.selectedGrade;

      if (credits > 0 && grade != null) {
        final point = _getGradePoint(grade);
        totalCredits += credits;
        totalGradePoints += (credits * point);
        filledCourses++;
      }
    }

    if (filledCourses == 0 || totalCredits == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please enter credits and select a grade for at least one course.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: palette.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _calculatedSemesterCredits = totalCredits;
      _calculatedSemesterGpa = totalGradePoints / totalCredits;
    });

    HapticFeedback.mediumImpact();
  }

  void _calculateTargetRequiredSgpa(AppPalette palette) {
    final currentCgpa =
        double.tryParse(_targetCurrentCgpaController.text.trim());
    final completedSems =
        int.tryParse(_targetCompletedSemsController.text.trim());
    final targetCgpa = double.tryParse(_targetGoalCgpaController.text.trim());

    if (currentCgpa == null || completedSems == null || targetCgpa == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please fill in all Target Planner fields with valid numbers.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: palette.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (currentCgpa < 0 ||
        currentCgpa > 10 ||
        targetCgpa < 0 ||
        targetCgpa > 10 ||
        completedSems <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'CGPA must be between 0.0 and 10.0, and completed semesters > 0.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: palette.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final totalRequiredPoints = targetCgpa * (completedSems + 1);
    final currentTotalPoints = currentCgpa * completedSems;
    final requiredSgpa = totalRequiredPoints - currentTotalPoints;

    setState(() {
      _calculatedRequiredSgpa = requiredSgpa;
      _isTargetAchievable = requiredSgpa <= 10.0 && requiredSgpa >= 0.0;

      if (requiredSgpa > 10.0) {
        _targetFeedbackMessage =
            'Target is mathematically impossible in 1 semester (Max SGPA is 10.0). Consider aiming for this target across multiple semesters.';
      } else if (requiredSgpa < 5.0) {
        _targetFeedbackMessage =
            'Easily achievable! A passing SGPA of at least ${requiredSgpa < 0 ? '5.00' : requiredSgpa.toStringAsFixed(2)} will reach your goal.';
      } else {
        _targetFeedbackMessage =
            'Target Achievable! Maintain an SGPA of ${requiredSgpa.toStringAsFixed(2)} in your upcoming semester.';
      }
    });

    HapticFeedback.mediumImpact();
  }

  void _calculateCumulativeGpa(AppPalette palette) {
    double totalGpa = 0.0;
    int count = 0;

    for (var row in _semesterGpaRows) {
      final gpa = double.tryParse(row.gpaController.text.trim());
      if (gpa != null && gpa >= 0 && gpa <= 10) {
        totalGpa += gpa;
        count++;
      }
    }

    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please enter valid GPA (0.0 - 10.0) for at least one semester.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: palette.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _calculatedCumulativeGpa = totalGpa / count;
    });

    HapticFeedback.mediumImpact();
  }

  int _getGradePoint(String grade) {
    switch (grade.trim().toUpperCase()) {
      case 'S':
        return 10;
      case 'A':
        return 9;
      case 'B':
        return 8;
      case 'C':
        return 7;
      case 'D':
        return 6;
      case 'E':
        return 5;
      case 'F':
      case 'N':
      default:
        return 0;
    }
  }

  void _showInfoDialog(String title, String content, AppPalette palette) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.line),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: palette.blue, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  color: palette.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          content,
          style: GoogleFonts.inter(
            color: palette.inkSoft,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'GOT IT',
              style: GoogleFonts.spaceGrotesk(
                color: palette.blue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BUILD METHOD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        backgroundColor: palette.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: palette.ink, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'CGPA CALCULATOR',
          style: GoogleFonts.spaceGrotesk(
            color: palette.ink,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 0.8,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isLoadingVtop)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.blue,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: palette.inkSoft, size: 20),
              tooltip: 'Reset Fields',
              onPressed: () {
                setState(() {
                  _hasPrefetchedVtop = false;
                  for (var r in _courseRows) {
                    r.dispose();
                  }
                  for (var r in _semesterGpaRows) {
                    r.dispose();
                  }
                  _courseRows.clear();
                  _semesterGpaRows.clear();
                  _calculatedSemesterGpa = null;
                  _calculatedRequiredSgpa = null;
                  _calculatedCumulativeGpa = null;
                  _targetCurrentCgpaController.clear();
                  _targetCompletedSemsController.clear();
                  _targetGoalCgpaController.clear();
                  _initializeDefaultRows();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reset all calculator fields'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Overview Banner
              AnimeStaggerItem(
                index: 0,
                child: _buildHeaderBanner(palette),
              ),
              const SizedBox(height: 16),

              // 2. Card 1: SEMESTER GPA
              AnimeStaggerItem(
                index: 1,
                child: _buildSemesterGpaCard(palette),
              ),
              const SizedBox(height: 16),

              // 3. Card 2: TARGET CGPA PLANNER
              AnimeStaggerItem(
                index: 2,
                child: _buildTargetCgpaCard(palette),
              ),
              const SizedBox(height: 16),

              // 4. Card 3: CUMULATIVE GPA
              AnimeStaggerItem(
                index: 3,
                child: _buildCumulativeGpaCard(palette),
              ),
              const SizedBox(height: 16),

              // 5. Card 4: VIT-AP RELATIVE GRADING SYSTEM
              AnimeStaggerItem(
                index: 4,
                child: _buildGradingSystemCard(palette),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // 1. HEADER OVERVIEW BANNER
  // ==========================================================================

  Widget _buildHeaderBanner(AppPalette palette) {
    return NexusCard(
      variant: NexusCardVariant.standard,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.calculate_rounded, color: palette.blue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VIT-AP ACADEMIC CALCULATOR',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: palette.blue,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Calculate semester SGPA, forecast target goals, and compute overall cumulative CGPA.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: palette.inkSoft,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 2. CARD 1: SEMESTER GPA
  // ==========================================================================

  Widget _buildSemesterGpaCard(AppPalette palette) {
    return NexusCard(
      variant: NexusCardVariant.standard,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              Icon(Icons.calendar_month_rounded,
                  color: palette.blue, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SEMESTER GPA',
                  style: GoogleFonts.spaceGrotesk(
                    color: palette.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => _showInfoDialog(
                  'Semester GPA (SGPA)',
                  'SGPA is calculated as:\n\n'
                      'SGPA = Σ (Course Credits × Grade Points) / Σ (Course Credits)\n\n'
                      'Grade Points:\n'
                      '• S = 10\n• A = 9\n• B = 8\n• C = 7\n• D = 6\n• E = 5\n• F/N = 0',
                  palette,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: palette.inkMuted,
                    size: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Column Headers
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'CREDITS',
                  style: GoogleFonts.spaceGrotesk(
                    color: palette.inkMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: Text(
                  'GRADE',
                  style: GoogleFonts.spaceGrotesk(
                    color: palette.inkMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: 8),

          // Course Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _courseRows.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _buildCourseRowItem(index, palette);
            },
          ),
          const SizedBox(height: 14),

          // Action Buttons: +ADD COURSE & CALCULATE
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _courseRows
                          .add(CourseInputRow(credits: '', selectedGrade: null));
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: palette.line),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: palette.soft,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: palette.ink, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'ADD COURSE',
                          style: GoogleFonts.spaceGrotesk(
                            color: palette.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _calculateSemesterGpa(palette),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt_rounded,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'CALCULATE',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Calculated Result Display
          if (_calculatedSemesterGpa != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.soft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: palette.blue.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: palette.blue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      color: palette.blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SEMESTER SGPA',
                          style: GoogleFonts.spaceGrotesk(
                            color: palette.inkMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _calculatedSemesterGpa!.toStringAsFixed(2),
                              style: GoogleFonts.spaceGrotesk(
                                color: palette.blue,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '/ 10.0',
                              style: GoogleFonts.inter(
                                color: palette.inkMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total Credits',
                        style: GoogleFonts.inter(
                          color: palette.inkMuted,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        _calculatedSemesterCredits?.toStringAsFixed(1) ?? '0',
                        style: GoogleFonts.spaceGrotesk(
                          color: palette.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCourseRowItem(int index, AppPalette palette) {
    final row = _courseRows[index];

    return Row(
      children: [
        // Credits Field
        Expanded(
          flex: 4,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.line, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            child: TextField(
              controller: row.creditsController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(
                color: palette.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Credits',
                hintStyle: GoogleFonts.inter(
                  color: palette.inkMuted,
                  fontSize: 12,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Select Grade Dropdown
        Expanded(
          flex: 5,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.line, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: row.selectedGrade,
                isExpanded: true,
                dropdownColor: palette.surface,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: palette.inkSoft,
                  size: 18,
                ),
                hint: Text(
                  'Grade',
                  style: GoogleFonts.inter(
                    color: palette.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                items: _gradeOptions.map((opt) {
                  final grade = opt['grade'] as String;
                  final label = opt['label'] as String;
                  return DropdownMenuItem<String>(
                    value: grade,
                    child: Text(
                      label,
                      style: GoogleFonts.spaceGrotesk(
                        color: palette.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    row.selectedGrade = val;
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Delete Button
        Container(
          width: 38,
          height: 44,
          decoration: BoxDecoration(
            color: palette.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: palette.red.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: palette.red,
              size: 18,
            ),
            padding: EdgeInsets.zero,
            onPressed: () {
              if (_courseRows.length <= 1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('At least one course row is required.'),
                    duration: Duration(milliseconds: 800),
                  ),
                );
                return;
              }
              setState(() {
                row.dispose();
                _courseRows.removeAt(index);
              });
            },
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // 3. CARD 2: TARGET CGPA PLANNER
  // ==========================================================================

  Widget _buildTargetCgpaCard(AppPalette palette) {
    return NexusCard(
      variant: NexusCardVariant.standard,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Target Icon, Title, NEW badge, Info Icon
          Row(
            children: [
              Icon(Icons.track_changes_rounded,
                  color: palette.orange, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'TARGET CGPA PLANNER',
                  style: GoogleFonts.spaceGrotesk(
                    color: palette.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: palette.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'GOAL',
                  style: GoogleFonts.spaceGrotesk(
                    color: palette.orange,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _showInfoDialog(
                  'Target CGPA Planner',
                  'Calculate the required SGPA needed in your next semester to reach your desired Target CGPA.\n\n'
                      'Formula:\n'
                      'Required SGPA = [Target CGPA × (N + 1) - Current CGPA × N] / 1\n\n'
                      'Where N = Number of completed semesters.',
                  palette,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: palette.inkMuted,
                    size: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Input 1: CURRENT CGPA
          _buildPlannerInputField(
            label: 'CURRENT CGPA',
            hint: 'e.g., 8.5',
            controller: _targetCurrentCgpaController,
            palette: palette,
          ),
          const SizedBox(height: 10),

          // Input 2: SEMESTERS COMPLETED
          _buildPlannerInputField(
            label: 'SEMESTERS COMPLETED',
            hint: 'e.g., 3',
            controller: _targetCompletedSemsController,
            isInteger: true,
            palette: palette,
          ),
          const SizedBox(height: 10),

          // Input 3: TARGET CGPA
          _buildPlannerInputField(
            label: 'TARGET CGPA GOAL',
            hint: 'e.g., 9.0',
            controller: _targetGoalCgpaController,
            palette: palette,
          ),
          const SizedBox(height: 14),

          // Calculate Required SGPA Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _calculateTargetRequiredSgpa(palette),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.ads_click_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'CALCULATE REQUIRED SGPA',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Calculation Result
          if (_calculatedRequiredSgpa != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isTargetAchievable == true
                    ? palette.green.withValues(alpha: 0.1)
                    : palette.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isTargetAchievable == true
                      ? palette.green.withValues(alpha: 0.3)
                      : palette.red.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'REQUIRED NEXT SGPA',
                          style: GoogleFonts.spaceGrotesk(
                            color: _isTargetAchievable == true
                                ? palette.green
                                : palette.red,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: (_isTargetAchievable == true
                                  ? palette.green
                                  : palette.red)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _isTargetAchievable == true
                              ? 'ACHIEVABLE'
                              : 'IMPOSSIBLE',
                          style: GoogleFonts.spaceGrotesk(
                            color: _isTargetAchievable == true
                                ? palette.green
                                : palette.red,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _calculatedRequiredSgpa!.toStringAsFixed(2),
                    style: GoogleFonts.spaceGrotesk(
                      color: palette.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _targetFeedbackMessage ?? '',
                    style: GoogleFonts.inter(
                      color: palette.inkSoft,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlannerInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required AppPalette palette,
    bool isInteger = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            color: palette.inkMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: palette.soft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.line, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: TextField(
            controller: controller,
            keyboardType:
                TextInputType.numberWithOptions(decimal: !isInteger),
            style: GoogleFonts.inter(
              color: palette.ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                color: palette.inkMuted,
                fontSize: 12,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // 4. CARD 3: CUMULATIVE GPA
  // ==========================================================================

  Widget _buildCumulativeGpaCard(AppPalette palette) {
    return NexusCard(
      variant: NexusCardVariant.standard,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Title
          Row(
            children: [
              Icon(Icons.layers_rounded, color: palette.blue, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CUMULATIVE GPA (CGPA)',
                  style: GoogleFonts.spaceGrotesk(
                    color: palette.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => _showInfoDialog(
                  'Cumulative GPA (CGPA)',
                  'CGPA represents your overall academic performance across all completed semesters.\n\n'
                      'Cumulative GPA = Average of all completed Semester GPAs.\n\n'
                      'Add each of your semester GPAs below to calculate your true cumulative score.',
                  palette,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: palette.inkMuted,
                    size: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Header
          Text(
            'SEMESTER GPAS RECORD',
            style: GoogleFonts.spaceGrotesk(
              color: palette.inkMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          // Dynamic Semester GPA Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _semesterGpaRows.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _buildSemesterGpaRowItem(index, palette);
            },
          ),
          const SizedBox(height: 14),

          // Buttons: +ADD SEM & CALCULATE
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _semesterGpaRows.add(SemesterGpaInputRow(gpa: ''));
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: palette.line),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: palette.soft,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: palette.ink, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'ADD SEMESTER',
                          style: GoogleFonts.spaceGrotesk(
                            color: palette.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _calculateCumulativeGpa(palette),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calculate_rounded,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'CALCULATE CGPA',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Calculated Cumulative GPA Result Display
          if (_calculatedCumulativeGpa != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.soft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: palette.blue.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: palette.blue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.military_tech_rounded,
                      color: palette.blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CUMULATIVE CGPA',
                          style: GoogleFonts.spaceGrotesk(
                            color: palette.inkMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _calculatedCumulativeGpa!.toStringAsFixed(2),
                              style: GoogleFonts.spaceGrotesk(
                                color: palette.blue,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '/ 10.0',
                              style: GoogleFonts.inter(
                                color: palette.inkMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Semesters',
                        style: GoogleFonts.inter(
                          color: palette.inkMuted,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        '${_semesterGpaRows.length}',
                        style: GoogleFonts.spaceGrotesk(
                          color: palette.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSemesterGpaRowItem(int index, AppPalette palette) {
    final row = _semesterGpaRows[index];

    return Row(
      children: [
        // Semester GPA Input
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.line, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: TextField(
              controller: row.gpaController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(
                color: palette.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Semester ${index + 1} GPA',
                hintStyle: GoogleFonts.inter(
                  color: palette.inkMuted,
                  fontSize: 12,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Delete Red Trash Button
        Container(
          width: 38,
          height: 44,
          decoration: BoxDecoration(
            color: palette.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: palette.red.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: palette.red,
              size: 18,
            ),
            padding: EdgeInsets.zero,
            onPressed: () {
              if (_semesterGpaRows.length <= 1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('At least one semester GPA is required.'),
                    duration: Duration(milliseconds: 800),
                  ),
                );
                return;
              }
              setState(() {
                row.dispose();
                _semesterGpaRows.removeAt(index);
              });
            },
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // 5. CARD 4: VIT-AP GRADING SYSTEM GUIDE CARD
  // ==========================================================================

  Widget _buildGradingSystemCard(AppPalette palette) {
    return NexusCard(
      variant: NexusCardVariant.standard,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: palette.blue,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'VIT-AP Relative Grading System',
                  style: GoogleFonts.spaceGrotesk(
                    color: palette.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            'VIT-AP uses a relative grading curve where letter grades and grade points are awarded based on the batch distribution (mean μ and standard deviation σ).',
            style: GoogleFonts.inter(
              color: palette.inkSoft,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // Grade Points Grid
          Container(
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.line),
            ),
            child: Column(
              children: [
                _buildGradeScaleRow('S Grade', '10 Points', 'Outstanding',
                    palette.green, palette),
                Divider(height: 1, color: palette.line),
                _buildGradeScaleRow('A Grade', '9 Points', 'Excellent',
                    palette.blue, palette),
                Divider(height: 1, color: palette.line),
                _buildGradeScaleRow('B Grade', '8 Points', 'Very Good',
                    palette.navy, palette),
                Divider(height: 1, color: palette.line),
                _buildGradeScaleRow('C Grade', '7 Points', 'Good',
                    palette.orange, palette),
                Divider(height: 1, color: palette.line),
                _buildGradeScaleRow('D Grade', '6 Points', 'Fair',
                    palette.orange, palette),
                Divider(height: 1, color: palette.line),
                _buildGradeScaleRow('E Grade', '5 Points', 'Pass',
                    palette.inkSoft, palette),
                Divider(height: 1, color: palette.line),
                _buildGradeScaleRow('F / N Grade', '0 Points', 'Fail / Absent',
                    palette.red, palette),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeScaleRow(
    String grade,
    String points,
    String label,
    Color color,
    AppPalette palette,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              grade,
              style: GoogleFonts.spaceGrotesk(
                color: palette.ink,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: palette.inkMuted,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            points,
            style: GoogleFonts.spaceGrotesk(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
