import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_formatter.dart';
import '../widgets/shadcn/shadcn_ui.dart';
import '../widgets/motion/nexus_motion.dart';
import 'cgpa_calculator_screen.dart';

class GradesScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;

  const GradesScreen({super.key, this.initialData});

  @override
  ConsumerState<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends ConsumerState<GradesScreen> {
  late Future<Map<String, dynamic>> _gradesFuture;
  Map<String, dynamic>? _cachedData;
  String _selectedSemester = 'All';
  String? _selectedGrade;
  final TextEditingController _searchController = TextEditingController();

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
  Color get _soft => _palette.soft;

  TextStyle get _micro => GoogleFonts.spaceGrotesk(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      );

  @override
  void initState() {
    super.initState();
    final mem = widget.initialData ?? StorageService.getMemoryCache('grades');
    if (mem is Map && mem.isNotEmpty) {
      _cachedData = Map<String, dynamic>.from(mem);
    }
    _fetchGrades();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _fetchGrades({bool forceRefresh = false}) {
    _gradesFuture = _getGradesData(forceRefresh: forceRefresh).then((data) {
      if (mounted && data.isNotEmpty) {
        setState(() => _cachedData = data);
      }
      return data;
    });
  }

  Future<Map<String, dynamic>> _getGradesData({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      if (widget.initialData != null && widget.initialData!.isNotEmpty) {
        return widget.initialData!;
      }

      final mem = StorageService.getMemoryCache('grades');
      if (mem is Map && mem.isNotEmpty) {
        return Map<String, dynamic>.from(mem);
      }

      final disk = await StorageService.getCache('grades');
      if (disk is Map && disk.isNotEmpty) {
        return Map<String, dynamic>.from(disk);
      }
    }

    final auth = ref.read(authProvider);

    try {
      final fresh = await apiService.fetchGradeHistory(
        username: auth.username ?? '',
        password: auth.password ?? '',
      );

      if (fresh.isNotEmpty) {
        await StorageService.setCache('grades', fresh);
        return fresh;
      }
    } catch (e) {
      debugPrint(
        'GradesScreen: Network fetch failed ($e). Checking offline cache...',
      );

      final fallback = widget.initialData ??
          StorageService.getMemoryCache('grades') ??
          await StorageService.getCache('grades');

      if (fallback is Map && fallback.isNotEmpty) {
        return Map<String, dynamic>.from(fallback);
      }

      rethrow;
    }

    final fallback = widget.initialData ??
        StorageService.getMemoryCache('grades') ??
        await StorageService.getCache('grades');

    if (fallback is Map && fallback.isNotEmpty) {
      return Map<String, dynamic>.from(fallback);
    }

    return {};
  }

  Color _getGradeColor(String grade) {
    switch (grade.toUpperCase().trim()) {
      case 'S':
        return _green;
      case 'A':
        return _blue;
      case 'B':
        return const Color(0xFF6575C5);
      case 'C':
        return const Color(0xFFC48A21);
      case 'D':
      case 'E':
        return _orange;
      case 'F':
      case 'N':
        return _red;
      case 'P':
        return const Color(0xFF328C9B);
      default:
        return _blue;
    }
  }

  List<String> _extractSemesters(List<dynamic> courses) {
    final List<String> semesters = [];
    for (final c in courses) {
      final sem = (c['exam_month']?.toString() ?? '').trim();
      if (sem.isNotEmpty && !semesters.contains(sem)) {
        semesters.add(sem);
      }
    }
    return semesters;
  }

  Map<String, dynamic> _calculateStats(List<dynamic> courses) {
    double totalGradePoints = 0;
    double gpaCredits = 0;
    double earnedCredits = 0;
    double registeredCredits = 0;

    for (final c in courses) {
      final credits = double.tryParse(c['credits']?.toString() ?? '0') ?? 0.0;
      final grade = (c['grade']?.toString() ?? '').trim().toUpperCase();

      registeredCredits += credits;

      if (['S', 'A', 'B', 'C', 'D', 'E', 'P'].contains(grade)) {
        earnedCredits += credits;
      }

      int? gradePoint;
      switch (grade) {
        case 'S':
          gradePoint = 10;
          break;
        case 'A':
          gradePoint = 9;
          break;
        case 'B':
          gradePoint = 8;
          break;
        case 'C':
          gradePoint = 7;
          break;
        case 'D':
          gradePoint = 6;
          break;
        case 'E':
          gradePoint = 5;
          break;
        case 'F':
        case 'N':
          gradePoint = 0;
          break;
        default:
          gradePoint = null;
          break;
      }

      if (gradePoint != null && credits > 0) {
        totalGradePoints += (credits * gradePoint);
        gpaCredits += credits;
      }
    }

    final gpa = gpaCredits > 0
        ? (totalGradePoints / gpaCredits).toStringAsFixed(2)
        : 'N/A';

    return {
      'gpa': gpa,
      'earned': earnedCredits % 1 == 0
          ? earnedCredits.toInt().toString()
          : earnedCredits.toStringAsFixed(1),
      'registered': registeredCredits % 1 == 0
          ? registeredCredits.toInt().toString()
          : registeredCredits.toStringAsFixed(1),
    };
  }

  Future<void> _onRefresh() async {
    try {
      final fresh = await _getGradesData(forceRefresh: true);
      if (mounted && fresh.isNotEmpty) {
        setState(() => _cachedData = fresh);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No internet connection. Showing saved data.',
            style: GoogleFonts.dmSans(
              color: _palette.onNavy,
              fontWeight: FontWeight.w600,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _navy,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: RefreshIndicator(
          color: _blue,
          backgroundColor: _surface,
          onRefresh: _onRefresh,
          child: FutureBuilder<Map<String, dynamic>>(
            future: _gradesFuture,
            builder: (context, snapshot) {
              final data = _cachedData ?? snapshot.data;
              if (data != null && data.isNotEmpty) {
                return _buildGradesContent(data);
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoading();
              }

              if (snapshot.hasError) {
                return _buildError(snapshot.error!);
              }

              return _buildGradesContent(data ?? {});
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGradesContent(Map<String, dynamic> data) {
    final allCourses = (data['courses'] as List<dynamic>?) ?? [];
    final semesters = _extractSemesters(allCourses);

    // Overall totals from VTOP or fallback
    final overallCgpa = data['cgpa']?.toString() ?? 'N/A';
    final overallEarned = data['credits_earned']?.toString() ?? 'N/A';
    final overallRegistered = data['credits_registered']?.toString() ?? 'N/A';

    // Filter courses based on selected semester
    List<dynamic> semFilteredCourses = allCourses;
    if (_selectedSemester != 'All') {
      semFilteredCourses = allCourses
          .where(
            (c) =>
                (c['exam_month']?.toString() ?? '').trim() == _selectedSemester,
          )
          .toList();
    }

    // Compute metrics for display (before grade/search sub-filters)
    String heroGpaLabel = 'CUMULATIVE CGPA';
    String heroGpaValue = overallCgpa;
    String heroEarned = overallEarned;
    String heroRegistered = overallRegistered;

    if (_selectedSemester != 'All') {
      final semStats = _calculateStats(semFilteredCourses);
      heroGpaLabel = 'SEMESTER SGPA';
      heroGpaValue = semStats['gpa'];
      heroEarned = semStats['earned'];
      heroRegistered = semStats['registered'];
    } else if (heroGpaValue == 'N/A' && allCourses.isNotEmpty) {
      final allStats = _calculateStats(allCourses);
      heroGpaValue = allStats['gpa'];
      heroEarned = allStats['earned'];
      heroRegistered = allStats['registered'];
    }

    // Apply Grade Filter & Search Query
    List<dynamic> filteredCourses = semFilteredCourses;
    if (_selectedGrade != null) {
      filteredCourses = filteredCourses
          .where(
            (c) =>
                (c['grade']?.toString() ?? '').trim().toUpperCase() ==
                _selectedGrade,
          )
          .toList();
    }

    final searchQuery = _searchController.text.trim().toLowerCase();
    if (searchQuery.isNotEmpty) {
      filteredCourses = filteredCourses.where((c) {
        final code = (c['course_code'] ?? '').toString().toLowerCase();
        final title = (c['course_title'] ?? '').toString().toLowerCase();
        final grade = (c['grade'] ?? '').toString().toLowerCase();
        return code.contains(searchQuery) ||
            title.contains(searchQuery) ||
            grade.contains(searchQuery);
      }).toList();
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: _buildHero(
              heroGpaLabel,
              heroGpaValue,
              heroEarned,
              heroRegistered,
              _selectedSemester,
            ),
          ),
        ),

        // Interactive Grade Distribution Strip
        if (semFilteredCourses.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: _buildGradeDistributionCard(semFilteredCourses),
            ),
          ),

        // Semester Filter Segmented Tabs
        if (semesters.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildSemesterFilterBar(
                semesters: semesters,
                allCourses: allCourses,
              ),
            ),
          ),

        // Search Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: _buildSearchBar(),
          ),
        ),

        // Courses Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _buildCoursesHeader(
              filteredCourses.length,
              _selectedSemester,
            ),
          ),
        ),

        // Course Cards
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: filteredCourses.isEmpty
              ? SliverToBoxAdapter(child: _buildEmpty())
              : (_selectedSemester == 'All' &&
                      searchQuery.isEmpty &&
                      _selectedGrade == null
                  ? SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final sem = semesters[index];
                          final semCourses = allCourses
                              .where(
                                (c) =>
                                    (c['exam_month']?.toString() ?? '')
                                        .trim() ==
                                    sem,
                              )
                              .toList();
                          return _buildSemesterGroup(sem, semCourses);
                        },
                        childCount: semesters.length,
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AnimeStaggerItem(
                              index: index,
                              child: _buildCourse(filteredCourses[index]),
                            ),
                          );
                        },
                        childCount: filteredCourses.length,
                      ),
                    )),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: _navy,
                size: 19,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACADEMIC TRANSCRIPT',
                  style: _micro.copyWith(color: _orange),
                ),
                const SizedBox(height: 3),
                Text(
                  'Grades & CGPA',
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
          Tooltip(
            message: 'CGPA & GPA Calculator',
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CgpaCalculatorScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calculate_outlined,
                      color: _blue,
                      size: 17,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Calc',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => setState(() => _fetchGrades(forceRefresh: true)),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _line),
              ),
              child: Icon(
                Icons.refresh_rounded,
                color: _navy,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(
    String gpaLabel,
    String gpa,
    String earned,
    String registered,
    String semester,
  ) {
    final numericGpa = double.tryParse(gpa) ?? 0.0;
    final numericEarned = double.tryParse(earned) ?? 0.0;
    final numericReg = double.tryParse(registered) ?? 0.0;
    final creditProgress = numericReg > 0
        ? (numericEarned / numericReg).clamp(0.0, 1.0)
        : 1.0;

    String standingLabel = 'ACADEMIC RECORD';
    Color standingColor = const Color(0xFF79B7FF);
    if (numericGpa >= 9.0) {
      standingLabel = 'CHANCELLOR DISTINCTION • 9.0+';
      standingColor = const Color(0xFF4ADE80);
    } else if (numericGpa >= 8.0) {
      standingLabel = 'FIRST CLASS WITH DISTINCTION';
      standingColor = const Color(0xFFF2B35B);
    } else if (numericGpa >= 6.5) {
      standingLabel = 'FIRST CLASS STANDING';
      standingColor = const Color(0xFF79B7FF);
    } else if (numericGpa > 0) {
      standingLabel = 'ACTIVE STANDING';
      standingColor = const Color(0xFFFBBF24);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _palette.heroBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _palette.isDark ? _line : const Color(0xFF172B4D),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x17172B4D),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: standingColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: standingColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      size: 13,
                      color: standingColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      standingLabel,
                      style: GoogleFonts.spaceGrotesk(
                        color: standingColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CgpaCalculatorScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        size: 12,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'GPA Simulator',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: gpaLabel,
                  value: gpa,
                  icon: Icons.auto_graph_rounded,
                  accent: const Color(0xFFF2B35B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetric(
                  label: 'CREDITS EARNED',
                  value: earned,
                  icon: Icons.school_outlined,
                  accent: const Color(0xFF79B7FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: .10),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.fact_check_outlined,
                      color: Colors.white60,
                      size: 15,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      semester == 'All'
                          ? 'Total Credits Earned vs Registered'
                          : 'Semester Credits Earned vs Registered',
                      style: GoogleFonts.dmSans(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$earned / $registered',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: creditProgress,
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF79B7FF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeDistributionCard(List<dynamic> courses) {
    final counts = <String, int>{
      'S': 0,
      'A': 0,
      'B': 0,
      'C': 0,
      'D': 0,
      'E': 0,
      'P': 0,
    };
    for (final c in courses) {
      final g = (c['grade']?.toString() ?? '').trim().toUpperCase();
      if (counts.containsKey(g)) {
        counts[g] = (counts[g] ?? 0) + 1;
      } else if (g.isNotEmpty && g != '-') {
        counts[g] = (counts[g] ?? 0) + 1;
      }
    }

    final activeEntries =
        counts.entries.where((e) => e.value > 0).toList();
    if (activeEntries.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
              Text(
                'GRADE DISTRIBUTION (TAP TO FILTER)',
                style: _micro.copyWith(color: _muted, fontSize: 8.5),
              ),
              if (_selectedGrade != null)
                GestureDetector(
                  onTap: () => setState(() => _selectedGrade = null),
                  child: Text(
                    'Clear Filter ($_selectedGrade)',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _blue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: activeEntries.map((entry) {
                final g = entry.key;
                final count = entry.value;
                final color = _getGradeColor(g);
                final isSelected = _selectedGrade == g;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedGrade = isSelected ? null : g;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.18)
                            : _soft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? color
                              : color.withValues(alpha: 0.28),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            g,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$count',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterFilterBar({
    required List<String> semesters,
    required List<dynamic> allCourses,
  }) {
    final allTabs = ['All', ...semesters];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: allTabs.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final sem = allTabs[index];
          final isSelected = _selectedSemester == sem;
          final count = sem == 'All'
              ? allCourses.length
              : allCourses
                  .where((c) =>
                      (c['exam_month']?.toString() ?? '').trim() == sem)
                  .length;

          return InkWell(
            onTap: () => setState(() => _selectedSemester = sem),
            borderRadius: BorderRadius.circular(19),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? _navy : _surface,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: isSelected ? _navy : _line,
                  width: 1.2,
                ),
                boxShadow: isSelected
                    ? const [
                        BoxShadow(
                          color: Color(0x14172B4D),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sem,
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? (_palette.isDark ? const Color(0xFF0F172A) : Colors.white)
                          : _ink,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (_palette.isDark
                              ? const Color(0x330F172A)
                              : Colors.white.withValues(alpha: .2))
                          : _soft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? (_palette.isDark ? const Color(0xFF0F172A) : Colors.white)
                            : _inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return NexusSearchBar(
      controller: _searchController,
      hintText: 'Search course by name, code or grade...',
      onChanged: (_) => setState(() {}),
      onClear: () {
        _searchController.clear();
        setState(() {});
      },
    );
  }

  Widget _buildCoursesHeader(int count, String semester) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _line),
          ),
          child: Icon(
            Icons.menu_book_outlined,
            color: _blue,
            size: 15,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            semester == 'All'
                ? 'ALL SEMESTER GRADES'
                : 'GRADES FOR $semester',
            style: _micro.copyWith(
              color: _ink,
              fontSize: 9.5,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: _soft,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            '$count COURSES',
            style: GoogleFonts.spaceGrotesk(
              color: _navy,
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .55,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSemesterGroup(String semester, List<dynamic> semCourses) {
    final stats = _calculateStats(semCourses);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Semester Subheader Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_outlined, size: 15, color: _navy),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    semester,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'SGPA: ',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
                Text(
                  stats['gpa'],
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '• ${semCourses.length}',
                  style: GoogleFonts.dmSans(
                    fontSize: 10.5,
                    color: _inkSoft,
                  ),
                ),
              ],
            ),
          ),

          // Course Cards
          ...semCourses.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildCourse(c),
            ),
          ),
        ],
      ),
    );
  }

  int? _getGradePoint(String grade) {
    switch (grade.toUpperCase().trim()) {
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
        return null;
    }
  }

  Widget _buildCourse(dynamic course) {
    final grade = (course['grade']?.toString() ?? '-').trim();
    final color = _getGradeColor(grade);
    final gp = _getGradePoint(grade);
    final code = (course['course_code']?.toString() ?? '').trim();
    final title = (course['course_title']?.toString() ?? 'Course').trim();
    final credits = (course['credits']?.toString() ?? '0').trim();
    final type = (course['course_type']?.toString() ?? '').trim();
    final month = (course['exam_month']?.toString() ?? '').trim();
    final distribution = (course['course_distribution']?.toString() ?? '').trim();
    final totalMarks = (course['total_marks']?.toString() ?? '').trim();

    return NexusCard(
      variant: NexusCardVariant.standard,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      onTap: () => _showCourseGradeDetailSheet(course),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Grade & Grade Point Badge
          Container(
            width: 52,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withValues(alpha: .35),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  grade,
                  style: GoogleFonts.spaceGrotesk(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
                if (gp != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    '$gp GP',
                    style: GoogleFonts.spaceGrotesk(
                      color: color.withValues(alpha: 0.85),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 13),

          // Center: Course Title & Clean Metadata Row
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: _ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    height: 1.22,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (code.isNotEmpty)
                      _Pill(
                        code,
                        _blue,
                        _blue.withValues(alpha: 0.12),
                      ),
                    _Pill(
                      '$credits CR',
                      _inkSoft,
                      _soft,
                    ),
                    if (distribution.isNotEmpty)
                      _Pill(
                        distribution,
                        _muted,
                        _soft,
                      ),
                    if (totalMarks.isNotEmpty &&
                        totalMarks != '-' &&
                        totalMarks != '0')
                      _Pill(
                        'SCORE: $totalMarks',
                        _green,
                        _green.withValues(alpha: 0.12),
                      ),
                    if (month.isNotEmpty && _selectedSemester != 'All')
                      _Pill(
                        month,
                        _orange,
                        _orange.withValues(alpha: 0.12),
                      ),
                    if (type.isNotEmpty && distribution.isEmpty)
                      _Pill(
                        type,
                        _muted,
                        _soft,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: _muted,
          ),
        ],
      ),
    );
  }

  void _showCourseGradeDetailSheet(dynamic course) {
    final grade = (course['grade']?.toString() ?? '-').trim();
    final color = _getGradeColor(grade);
    final gp = _getGradePoint(grade);
    final code = (course['course_code']?.toString() ?? '-').trim();
    final title = (course['course_title']?.toString() ?? 'Course').trim();
    final credits = (course['credits']?.toString() ?? '0').trim();
    final type = (course['course_type']?.toString() ?? '-').trim();
    final month = (course['exam_month']?.toString() ?? '-').trim();
    final distribution = (course['course_distribution']?.toString() ?? '-').trim();
    final totalMarks = (course['total_marks']?.toString() ?? '').trim();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: _line, width: 1.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Center(
                      child: Text(
                        grade,
                        style: GoogleFonts.spaceGrotesk(
                          color: color,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: _blue,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          title,
                          style: GoogleFonts.dmSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _soft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _line),
                ),
                child: Column(
                  children: [
                    _buildDetailLine('Letter Grade', grade, valueColor: color),
                    if (gp != null) ...[
                      Divider(height: 18, color: _line),
                      _buildDetailLine('Grade Points', '$gp / 10 GP'),
                    ],
                    Divider(height: 18, color: _line),
                    _buildDetailLine('Course Credits', '$credits Credits'),
                    if (totalMarks.isNotEmpty && totalMarks != '-') ...[
                      Divider(height: 18, color: _line),
                      _buildDetailLine('Total Marks', totalMarks),
                    ],
                    if (distribution.isNotEmpty && distribution != '-') ...[
                      Divider(height: 18, color: _line),
                      _buildDetailLine('Curriculum Category', distribution),
                    ],
                    if (type.isNotEmpty && type != '-') ...[
                      Divider(height: 18, color: _line),
                      _buildDetailLine('Course Type', type),
                    ],
                    if (month.isNotEmpty && month != '-') ...[
                      Divider(height: 18, color: _line),
                      _buildDetailLine('Exam Month', month),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailLine(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _inkSoft,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor ?? _ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Icon(
            Icons.menu_book_outlined,
            color: _muted,
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            _searchController.text.isNotEmpty
                ? 'No matching courses found for "${_searchController.text}".'
                : 'No grade records found for the selected semester.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: _muted,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _blue,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Loading grades...',
            style: GoogleFonts.dmSans(
              color: _muted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * .75,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFCEDEA),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      color: _red,
                      size: 31,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to Load Grade History',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    ErrorFormatter.format(
                      error,
                      fallback: 'Unable to load grade history. Please check your connection and try again.',
                    ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: _muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() => _fetchGrades(forceRefresh: true));
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      'Try Again',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: _palette.isDark ? const Color(0xFF0F172A) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _HeroMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: Colors.white.withValues(alpha: .11),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 16),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white54,
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;

  const _Pill(this.text, this.color, this.background);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: .25,
        ),
      ),
    );
  }
}
