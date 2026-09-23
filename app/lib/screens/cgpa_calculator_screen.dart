import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

// ============================================================================
// DATA MODELS
// ============================================================================

class SemesterEntry {
  final String id;
  String name;
  double sgpa;
  double credits;
  bool isHistorical;
  List<CourseGradeEntry> courses;

  SemesterEntry({
    required this.id,
    required this.name,
    required this.sgpa,
    required this.credits,
    this.isHistorical = false,
    List<CourseGradeEntry>? courses,
  }) : courses = courses ?? [];

  SemesterEntry copyWith({
    String? id,
    String? name,
    double? sgpa,
    double? credits,
    bool? isHistorical,
    List<CourseGradeEntry>? courses,
  }) {
    return SemesterEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      sgpa: sgpa ?? this.sgpa,
      credits: credits ?? this.credits,
      isHistorical: isHistorical ?? this.isHistorical,
      courses: courses ?? List.from(this.courses),
    );
  }

  double get totalGradePoints => sgpa * credits;
}

class CourseGradeEntry {
  final String id;
  String code;
  String title;
  double credits;
  String grade; // 'S', 'A', 'B', 'C', 'D', 'E', 'F'

  CourseGradeEntry({
    required this.id,
    required this.code,
    required this.title,
    required this.credits,
    this.grade = 'S',
  });

  static int gradeToPoint(String g) {
    switch (g.trim().toUpperCase()) {
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
        return 0;
      default:
        return 10;
    }
  }

  int get gradePoint => gradeToPoint(grade);
  double get coursePoints => credits * gradePoint;
}

// ============================================================================
// MAIN CGPA CALCULATOR & PLANNER SCREEN
// ============================================================================

class CgpaCalculatorScreen extends ConsumerStatefulWidget {
  const CgpaCalculatorScreen({super.key});

  @override
  ConsumerState<CgpaCalculatorScreen> createState() => _CgpaCalculatorScreenState();
}

class _CgpaCalculatorScreenState extends ConsumerState<CgpaCalculatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<SemesterEntry> _semesters = [];
  List<CourseGradeEntry> _currentSemCourses = [];
  bool _isLoading = true;
  double? _baselineCgpa;

  // Target Calculator State
  double _targetCgpa = 9.0;
  double _targetFutureCredits = 21.0;

  AppPalette get _palette => AppPalette.of(context);
  Color get _paper => _palette.paper;
  Color get _surface => _palette.surface;
  Color get _ink => _palette.ink;
  Color get _inkSoft => _palette.inkSoft;
  Color get _navy => _palette.navy;
  Color get _blue => _palette.blue;
  Color get _orange => _palette.orange;
  Color get _green => _palette.green;
  Color get _red => _palette.red;
  Color get _muted => _palette.inkMuted;
  Color get _line => _palette.line;

  TextStyle get _micro => GoogleFonts.spaceGrotesk(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAcademicData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAcademicData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Load Grade History (for past completed semesters)
      Map<String, dynamic>? gradesData;
      final memGrades = StorageService.getMemoryCache('grades');
      if (memGrades is Map && memGrades.isNotEmpty) {
        gradesData = Map<String, dynamic>.from(memGrades);
      } else {
        final diskGrades = await StorageService.getCache('grades');
        if (diskGrades is Map && diskGrades.isNotEmpty) {
          gradesData = Map<String, dynamic>.from(diskGrades);
        }
      }

      // If cache empty, try fetching live
      if (gradesData == null || gradesData.isEmpty) {
        final auth = ref.read(authProvider);
        if (auth.username != null && auth.password != null) {
          try {
            final fresh = await apiService.fetchGradeHistory(
              username: auth.username!,
              password: auth.password!,
            );
            if (fresh.isNotEmpty) {
              gradesData = fresh;
              await StorageService.setCache('grades', fresh);
            }
          } catch (_) {}
        }
      }

      // Extract Semesters from Grade History
      final List<SemesterEntry> loadedSems = [];
      if (gradesData != null && gradesData.containsKey('courses')) {
        final courses = (gradesData['courses'] as List<dynamic>?) ?? [];
        
        // Group by exam_month / semester
        final Map<String, List<dynamic>> semGroups = {};
        for (var c in courses) {
          final sem = (c['exam_month']?.toString() ?? 'Semester').trim();
          semGroups.putIfAbsent(sem, () => []).add(c);
        }

        int semIdx = 1;
        for (var entry in semGroups.entries) {
          final semCourses = entry.value;
          double semPoints = 0;
          double semCredits = 0;

          for (var sc in semCourses) {
            final cred = double.tryParse(sc['credits']?.toString() ?? '0') ?? 0.0;
            final gr = (sc['grade']?.toString() ?? '').trim().toUpperCase();
            final pt = CourseGradeEntry.gradeToPoint(gr);
            if (cred > 0 && gr != 'N' && gr != 'P') {
              semPoints += (cred * pt);
              semCredits += cred;
            } else if (cred > 0 && gr == 'P') {
              // Pass non-graded course contributes credits
              semCredits += cred;
            }
          }

          final semGpa = semCredits > 0 ? (semPoints / semCredits) : 0.0;
          final semName = 'Semester $semIdx (${entry.key})';

          loadedSems.add(
            SemesterEntry(
              id: 'sem_$semIdx',
              name: semName,
              sgpa: double.parse(semGpa.toStringAsFixed(2)),
              credits: semCredits,
              isHistorical: true,
            ),
          );
          semIdx++;
        }
      }

      // 2. Load current enrolled courses (from attendance or courses cache)
      final List<CourseGradeEntry> currentCourses = [];
      final memAtt = StorageService.getMemoryCache('attendance');
      final diskAtt = memAtt ?? await StorageService.getCache('attendance');
      
      if (diskAtt is Map && diskAtt.containsKey('courses')) {
        final list = (diskAtt['courses'] as List<dynamic>?) ?? [];
        int cIdx = 1;
        for (var c in list) {
          final title = c['course_title']?.toString() ?? c['course_name']?.toString() ?? 'Course $cIdx';
          final code = c['course_code']?.toString() ?? '';
          final credStr = c['credits']?.toString() ?? '3.0';
          final cred = double.tryParse(credStr) ?? 3.0;

          currentCourses.add(
            CourseGradeEntry(
              id: 'curr_c_$cIdx',
              code: code,
              title: title,
              credits: cred > 0 ? cred : 3.0,
              grade: 'S',
            ),
          );
          cIdx++;
        }
      }

      // Fallback: If no courses found, create standard defaults
      if (currentCourses.isEmpty) {
        currentCourses.addAll([
          CourseGradeEntry(id: 'c1', code: 'CSE3001', title: 'Software Engineering', credits: 4.0, grade: 'S'),
          CourseGradeEntry(id: 'c2', code: 'CSE3002', title: 'Computer Networks', credits: 4.0, grade: 'A'),
          CourseGradeEntry(id: 'c3', code: 'CSE3003', title: 'Database Systems', credits: 4.0, grade: 'S'),
          CourseGradeEntry(id: 'c4', code: 'MAT2001', title: 'Applied Statistics', credits: 3.0, grade: 'A'),
          CourseGradeEntry(id: 'c5', code: 'HUM1001', title: 'Ethics & Values', credits: 2.0, grade: 'S'),
        ]);
      }

      // If no past semesters loaded from history, create default Sem 1 - 3
      if (loadedSems.isEmpty) {
        loadedSems.addAll([
          SemesterEntry(id: 'sem_1', name: 'Semester 1', sgpa: 8.70, credits: 21.0, isHistorical: true),
          SemesterEntry(id: 'sem_2', name: 'Semester 2', sgpa: 8.95, credits: 22.0, isHistorical: true),
          SemesterEntry(id: 'sem_3', name: 'Semester 3', sgpa: 9.10, credits: 20.0, isHistorical: true),
        ]);
      }

      // Compute present semester SGPA from currentCourses
      double currSemCredits = 0;
      double currSemPoints = 0;
      for (var c in currentCourses) {
        currSemCredits += c.credits;
        currSemPoints += c.coursePoints;
      }
      final currSgpa = currSemCredits > 0 ? (currSemPoints / currSemCredits) : 9.5;

      // Append present semester to the list
      final nextSemNum = loadedSems.length + 1;
      loadedSems.add(
        SemesterEntry(
          id: 'sem_present',
          name: 'Semester $nextSemNum (Present)',
          sgpa: double.parse(currSgpa.toStringAsFixed(2)),
          credits: currSemCredits > 0 ? currSemCredits : 21.0,
          isHistorical: false,
          courses: currentCourses,
        ),
      );

      // Save baseline stats (historical only)
      double histPoints = 0;
      double histCreds = 0;
      for (var s in loadedSems.where((s) => s.isHistorical)) {
        histPoints += s.totalGradePoints;
        histCreds += s.credits;
      }
      _baselineCgpa = histCreds > 0 ? (histPoints / histCreds) : null;

      _semesters = loadedSems;
      _currentSemCourses = currentCourses;
      _targetCgpa = (_baselineCgpa != null ? (_baselineCgpa! + 0.25).clamp(6.0, 9.8) : 9.0);
      _targetCgpa = double.parse(_targetCgpa.toStringAsFixed(2));
    } catch (e) {
      debugPrint('CgpaCalculator: Error initializing data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================================
  // MATH & CALCULATIONS
  // ============================================================================

  double get _totalCumulativeCredits {
    return _semesters.fold(0.0, (sum, s) => sum + s.credits);
  }

  double get _totalCumulativePoints {
    return _semesters.fold(0.0, (sum, s) => sum + s.totalGradePoints);
  }

  double get _overallCgpa {
    final totalCreds = _totalCumulativeCredits;
    if (totalCreds <= 0) return 0.0;
    return _totalCumulativePoints / totalCreds;
  }

  double get _presentSemSgpa {
    double pts = 0;
    double crs = 0;
    for (var c in _currentSemCourses) {
      pts += c.coursePoints;
      crs += c.credits;
    }
    return crs > 0 ? (pts / crs) : 0.0;
  }

  double get _presentSemCredits {
    return _currentSemCourses.fold(0.0, (sum, c) => sum + c.credits);
  }

  void _syncCourseSgpaToPresentSem() {
    final sgpa = _presentSemSgpa;
    final creds = _presentSemCredits;
    final idx = _semesters.indexWhere((s) => s.id == 'sem_present' || !s.isHistorical);
    if (idx != -1) {
      setState(() {
        _semesters[idx].sgpa = double.parse(sgpa.toStringAsFixed(2));
        _semesters[idx].credits = creds;
      });
    }
  }

  // ============================================================================
  // BUILD UI
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _paper,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_blue),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading Academic Records...',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _inkSoft,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final overall = _overallCgpa;
    final delta = _baselineCgpa != null ? (overall - _baselineCgpa!) : 0.0;

    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _paper,
        foregroundColor: _ink,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: _navy),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ACADEMIC PLANNER',
              style: _micro.copyWith(color: _orange),
            ),
            const SizedBox(height: 2),
            Text(
              'CGPA & SGPA Calculator',
              style: GoogleFonts.dmSans(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reset to History',
            icon: Icon(Icons.refresh_rounded, color: _navy),
            onPressed: () {
              HapticFeedback.selectionClick();
              _loadAcademicData();
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _line),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: _navy,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: _muted,
              labelStyle: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
              tabs: const [
                Tab(text: 'Semesters'),
                Tab(text: 'Course Sim'),
                Tab(text: 'Target Goal'),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Overall Cumulative Scoreboard Hero
            _buildOverallCgpaHero(overall, delta),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSemestersTab(),
                  _buildCourseSimulatorTab(),
                  _buildTargetGoalTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // 1. OVERALL SCOREBOARD HERO
  // ============================================================================

  Widget _buildOverallCgpaHero(double overallCgpa, double delta) {
    final isDeltaPositive = delta >= 0.0;
    final deltaStr = isDeltaPositive
        ? '+${delta.toStringAsFixed(2)}'
        : delta.toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Main Overall CGPA Circle / Badge
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _navy,
              boxShadow: [
                BoxShadow(
                  color: _navy.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    overallCgpa.toStringAsFixed(2),
                    style: GoogleFonts.dmSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.05,
                    ),
                  ),
                  Text(
                    'OVERALL',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: const Color(0xFFF2B35B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Stats Breakdown
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PROJECTED CGPA',
                      style: _micro.copyWith(color: _muted),
                    ),
                    if (_baselineCgpa != null && delta.abs() >= 0.01)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: (isDeltaPositive ? _green : _orange)
                              .withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$deltaStr vs Past',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: isDeltaPositive ? _green : _orange,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildHeroStat(
                      'TOTAL CREDITS',
                      _totalCumulativeCredits.toStringAsFixed(1),
                      _blue,
                    ),
                    const SizedBox(width: 16),
                    _buildHeroStat(
                      'SEMESTERS',
                      '${_semesters.length} Terms',
                      _orange,
                    ),
                    const SizedBox(width: 16),
                    _buildHeroStat(
                      'GRADE POINTS',
                      _totalCumulativePoints.toStringAsFixed(0),
                      _green,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String label, String val, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          val,
          style: GoogleFonts.dmSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 7.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: _muted,
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // TAB 1: SEMESTER-BY-SEMESTER AGGREGATOR
  // ============================================================================

  Widget _buildSemestersTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SEMESTER BREAKDOWN',
              style: _micro.copyWith(color: _muted),
            ),
            Text(
              '${_semesters.length} Semesters Included',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _inkSoft,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // List of Semesters
        ..._semesters.asMap().entries.map((entry) {
          final idx = entry.key;
          final sem = entry.value;
          return _buildSemesterCard(sem, idx);
        }),

        const SizedBox(height: 16),

        // Add Next Semester Button
        ElevatedButton.icon(
          onPressed: _addNewSemester,
          style: ElevatedButton.styleFrom(
            backgroundColor: _surface,
            foregroundColor: _navy,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: _navy, width: 1.5),
            ),
          ),
          icon: Icon(Icons.add_circle_outline_rounded, size: 20, color: _navy),
          label: Text(
            'ADD FUTURE SEMESTER (SEM ${_semesters.length + 1})',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: _navy,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSemesterCard(SemesterEntry sem, int index) {
    final isPresent = sem.id == 'sem_present' || (!sem.isHistorical && index == _semesters.length - 1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPresent ? _blue : _line,
          width: isPresent ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (isPresent ? _blue : _navy).withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: isPresent ? _blue : _navy,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sem.name,
                        style: GoogleFonts.dmSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      Text(
                        sem.isHistorical ? 'Historical Records' : 'Simulated / Projected',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: sem.isHistorical ? _green : _orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Delete Button (only for custom/future added semesters)
              if (!sem.isHistorical && _semesters.length > 1)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: 20, color: _red),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _semesters.removeAt(index);
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),

          // SGPA & Credits Controls Row
          Row(
            children: [
              // SGPA Control
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _paper,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SEMESTER GPA',
                        style: _micro.copyWith(color: _muted),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniStepper(
                            icon: Icons.remove_rounded,
                            onTap: () {
                              if (sem.sgpa > 1.0) {
                                setState(() {
                                  sem.sgpa = double.parse((sem.sgpa - 0.1).toStringAsFixed(2));
                                });
                              }
                            },
                          ),
                          GestureDetector(
                            onTap: () => _showEditSgpaDialog(sem),
                            child: Text(
                              sem.sgpa.toStringAsFixed(2),
                              style: GoogleFonts.dmSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: _blue,
                              ),
                            ),
                          ),
                          _buildMiniStepper(
                            icon: Icons.add_rounded,
                            onTap: () {
                              if (sem.sgpa < 10.0) {
                                setState(() {
                                  sem.sgpa = double.parse((sem.sgpa + 0.1).toStringAsFixed(2));
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Credits Control
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _paper,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CREDITS',
                        style: _micro.copyWith(color: _muted),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniStepper(
                            icon: Icons.remove_rounded,
                            onTap: () {
                              if (sem.credits > 1.0) {
                                setState(() {
                                  sem.credits = sem.credits - 1.0;
                                });
                              }
                            },
                          ),
                          GestureDetector(
                            onTap: () => _showEditCreditsDialog(sem),
                            child: Text(
                              sem.credits.toStringAsFixed(1),
                              style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                          ),
                          _buildMiniStepper(
                            icon: Icons.add_rounded,
                            onTap: () {
                              if (sem.credits < 35.0) {
                                setState(() {
                                  sem.credits = sem.credits + 1.0;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (isPresent) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () {
                _tabController.animateTo(1);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 14, color: _blue),
                        const SizedBox(width: 8),
                        Text(
                          'Simulate using active courses',
                          style: GoogleFonts.dmSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _blue,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _blue),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStepper({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _line),
        ),
        child: Icon(icon, size: 15, color: _ink),
      ),
    );
  }

  void _addNewSemester() {
    HapticFeedback.selectionClick();
    final nextNum = _semesters.length + 1;
    setState(() {
      _semesters.add(
        SemesterEntry(
          id: 'sem_future_$nextNum',
          name: 'Semester $nextNum',
          sgpa: 9.0,
          credits: 20.0,
          isHistorical: false,
        ),
      );
    });
  }

  // ============================================================================
  // TAB 2: CURRENT SEMESTER COURSE-BY-COURSE SIMULATOR
  // ============================================================================

  Widget _buildCourseSimulatorTab() {
    final sgpa = _presentSemSgpa;
    final creds = _presentSemCredits;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      children: [
        // Present Semester Mini Hero
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT SEMESTER SGPA',
                    style: _micro.copyWith(color: _muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sgpa.toStringAsFixed(2),
                    style: GoogleFonts.dmSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: _blue,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _syncCourseSgpaToPresentSem();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Synced SGPA (${sgpa.toStringAsFixed(2)}) to Present Semester in Semesters Tab!',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: _navy,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: Text(
                  'APPLY TO SEMESTERS',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ENROLLED COURSES (${_currentSemCourses.length})',
              style: _micro.copyWith(color: _muted),
            ),
            Text(
              '${creds.toStringAsFixed(1)} Total Credits',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _inkSoft,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Course Cards
        ..._currentSemCourses.asMap().entries.map((entry) {
          final idx = entry.key;
          final course = entry.value;
          return _buildCourseGradeCard(course, idx);
        }),

        const SizedBox(height: 14),

        // Add Custom Course
        OutlinedButton.icon(
          onPressed: _addCustomCourse,
          style: OutlinedButton.styleFrom(
            foregroundColor: _navy,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: _line),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(
            'ADD ANOTHER COURSE',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseGradeCard(CourseGradeEntry course, int index) {
    const grades = ['S', 'A', 'B', 'C', 'D', 'E', 'F'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.code.isNotEmpty ? course.code : 'COURSE ${index + 1}',
                      style: _micro.copyWith(color: _orange),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      course.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
              // Credits Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _paper,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _line),
                ),
                child: Text(
                  '${course.credits.toStringAsFixed(1)} Cr',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Grade Selection Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: grades.map((g) {
              final isSelected = course.grade == g;
              Color gradeColor = _blue;
              if (g == 'S') gradeColor = _green;
              if (g == 'F') gradeColor = _red;

              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    course.grade = g;
                    _syncCourseSgpaToPresentSem();
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 38,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected ? gradeColor : _paper,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? gradeColor : _line,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      g,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : _ink,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _addCustomCourse() {
    HapticFeedback.selectionClick();
    final nextIdx = _currentSemCourses.length + 1;
    setState(() {
      _currentSemCourses.add(
        CourseGradeEntry(
          id: 'custom_$nextIdx',
          code: 'ELECTIVE $nextIdx',
          title: 'Custom Course $nextIdx',
          credits: 3.0,
          grade: 'S',
        ),
      );
      _syncCourseSgpaToPresentSem();
    });
  }

  // ============================================================================
  // TAB 3: TARGET CGPA GOAL SOLVER
  // ============================================================================

  Widget _buildTargetGoalTab() {
    // Current completed stats
    double completedPoints = 0;
    double completedCredits = 0;
    for (var s in _semesters.where((s) => s.isHistorical)) {
      completedPoints += s.totalGradePoints;
      completedCredits += s.credits;
    }

    if (completedCredits == 0) {
      completedCredits = _totalCumulativeCredits - _targetFutureCredits;
      completedPoints = _totalCumulativePoints - (_presentSemSgpa * _presentSemCredits);
    }

    final futureCredits = _targetFutureCredits;
    final totalTargetCredits = completedCredits + futureCredits;
    final targetPointsTotal = _targetCgpa * totalTargetCredits;
    final requiredPoints = targetPointsTotal - completedPoints;
    final requiredSgpa = futureCredits > 0 ? (requiredPoints / futureCredits) : 0.0;

    final isFeasible = requiredSgpa <= 10.0 && requiredSgpa >= 0.0;
    final maxPossibleCgpa = (completedPoints + (10.0 * futureCredits)) / totalTargetCredits;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      children: [
        // Target Selector Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TARGET CGPA GOAL',
                style: _micro.copyWith(color: _muted),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _targetCgpa.toStringAsFixed(2),
                    style: GoogleFonts.dmSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: _blue,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isFeasible ? _green : _red).withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isFeasible ? 'ACHIEVABLE 🎯' : 'REQUIRES MORE CREDITS ⚠️',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isFeasible ? _green : _red,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Target Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _blue,
                  inactiveTrackColor: _line,
                  thumbColor: _navy,
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _targetCgpa,
                  min: 6.0,
                  max: 10.0,
                  divisions: 80,
                  label: _targetCgpa.toStringAsFixed(2),
                  onChanged: (val) {
                    setState(() {
                      _targetCgpa = double.parse(val.toStringAsFixed(2));
                    });
                  },
                ),
              ),

              const SizedBox(height: 8),

              // Future Credits Load
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Across next credits load:',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      color: _inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      _buildMiniStepper(
                        icon: Icons.remove_rounded,
                        onTap: () {
                          if (_targetFutureCredits > 3.0) {
                            setState(() => _targetFutureCredits -= 1.0);
                          }
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '${_targetFutureCredits.toInt()} Cr',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                      ),
                      _buildMiniStepper(
                        icon: Icons.add_rounded,
                        onTap: () {
                          if (_targetFutureCredits < 80.0) {
                            setState(() => _targetFutureCredits += 1.0);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Result Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CALCULATED REQUIREMENT',
                style: _micro.copyWith(color: _muted),
              ),
              const SizedBox(height: 12),
              if (isFeasible) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      requiredSgpa.toStringAsFixed(2),
                      style: GoogleFonts.dmSans(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: _green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Required SGPA',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'You need to maintain an average of ${requiredSgpa.toStringAsFixed(2)} SGPA over the next ${_targetFutureCredits.toInt()} credits to hit your goal of ${_targetCgpa.toStringAsFixed(2)} CGPA.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    height: 1.45,
                    color: _inkSoft,
                  ),
                ),
              ] else ...[
                Text(
                  'Goal Exceeds Maximum Possible',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _red,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'With all "S" grades (10.0 SGPA) across the next ${_targetFutureCredits.toInt()} credits, your highest reachable CGPA is ${maxPossibleCgpa.toStringAsFixed(2)}. Increase your planned credit duration to reach ${_targetCgpa.toStringAsFixed(2)}.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    height: 1.45,
                    color: _inkSoft,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // DIALOGS & OVERRIDES
  // ============================================================================

  void _showEditSgpaDialog(SemesterEntry sem) {
    final controller = TextEditingController(text: sem.sgpa.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Edit SGPA for ${sem.name}',
          style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'e.g. 9.15',
            labelText: 'Semester GPA (0.0 - 10.0)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: _muted)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val >= 0.0 && val <= 10.0) {
                setState(() {
                  sem.sgpa = double.parse(val.toStringAsFixed(2));
                });
              }
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _navy),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditCreditsDialog(SemesterEntry sem) {
    final controller = TextEditingController(text: sem.credits.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Edit Credits for ${sem.name}',
          style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'e.g. 21.0',
            labelText: 'Total Semester Credits',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: _muted)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0.0 && val <= 50.0) {
                setState(() {
                  sem.credits = val;
                });
              }
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _navy),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
