import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';

class GradesScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;

  const GradesScreen({super.key, this.initialData});

  @override
  ConsumerState<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends ConsumerState<GradesScreen> {
  late Future<Map<String, dynamic>> _gradesFuture;
  String _selectedSemester = 'All';
  final TextEditingController _searchController = TextEditingController();

  static const _paper = Color(0xFFF4F2ED);
  static const _surface = Color(0xFFFFFEFB);
  static const _ink = Color(0xFF17202A);
  static const _inkSoft = Color(0xFF56616D);
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
        letterSpacing: 1,
      );

  @override
  void initState() {
    super.initState();
    _fetchGrades();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _fetchGrades({bool forceRefresh = false}) {
    _gradesFuture = _getGradesData(forceRefresh: forceRefresh);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: RefreshIndicator(
          color: _blue,
          backgroundColor: _surface,
          onRefresh: () async {
            setState(() => _fetchGrades(forceRefresh: true));
            await _gradesFuture;
          },
          child: FutureBuilder<Map<String, dynamic>>(
            future: _gradesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoading();
              }

              if (snapshot.hasError) {
                return _buildError(snapshot.error!);
              }

              final data = snapshot.data ?? {};
              final allCourses = (data['courses'] as List<dynamic>?) ?? [];
              final semesters = _extractSemesters(allCourses);

              // Overall totals from VTOP or fallback
              final overallCgpa = data['cgpa']?.toString() ?? 'N/A';
              final overallEarned = data['credits_earned']?.toString() ?? 'N/A';
              final overallRegistered =
                  data['credits_registered']?.toString() ?? 'N/A';

              // Filter courses based on selected semester
              List<dynamic> filteredCourses = allCourses;
              if (_selectedSemester != 'All') {
                filteredCourses = allCourses
                    .where((c) =>
                        (c['exam_month']?.toString() ?? '').trim() ==
                        _selectedSemester)
                    .toList();
              }

              // Filter by search query if present
              final searchQuery = _searchController.text.trim().toLowerCase();
              if (searchQuery.isNotEmpty) {
                filteredCourses = filteredCourses.where((c) {
                  final code =
                      (c['course_code'] ?? '').toString().toLowerCase();
                  final title =
                      (c['course_title'] ?? '').toString().toLowerCase();
                  final grade = (c['grade'] ?? '').toString().toLowerCase();
                  return code.contains(searchQuery) ||
                      title.contains(searchQuery) ||
                      grade.contains(searchQuery);
                }).toList();
              }

              // Compute metrics for display
              String heroGpaLabel = 'CURRENT CGPA';
              String heroGpaValue = overallCgpa;
              String heroEarned = overallEarned;
              String heroRegistered = overallRegistered;

              if (_selectedSemester != 'All') {
                final semStats = _calculateStats(filteredCourses);
                heroGpaLabel = 'SEMESTER SGPA';
                heroGpaValue = semStats['gpa'];
                heroEarned = semStats['earned'];
                heroRegistered = semStats['registered'];
              }

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: _buildHero(
                        heroGpaLabel,
                        heroGpaValue,
                        heroEarned,
                        heroRegistered,
                        _selectedSemester,
                      ),
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
                        : (_selectedSemester == 'All' && searchQuery.isEmpty
                            ? SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final sem = semesters[index];
                                    final semCourses = allCourses
                                        .where((c) =>
                                            (c['exam_month']?.toString() ??
                                                '').trim() ==
                                            sem)
                                        .toList();
                                    return _buildSemesterGroup(
                                        sem, semCourses);
                                  },
                                  childCount: semesters.length,
                                ),
                              )
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: _buildCourse(
                                          filteredCourses[index]),
                                    );
                                  },
                                  childCount: filteredCourses.length,
                                ),
                              )),
                  ),
                ],
              );
            },
          ),
        ),
      ),
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
              child: const Icon(
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
                  'ACADEMICS',
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
              child: const Icon(
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(21),
        boxShadow: const [
          BoxShadow(
            color: Color(0x17172B4D),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
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
              horizontal: 11,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: .10),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.fact_check_outlined,
                  color: Colors.white54,
                  size: 15,
                ),
                const SizedBox(width: 7),
                Text(
                  semester == 'All'
                      ? 'Total credits registered'
                      : 'Semester credits registered',
                  style: GoogleFonts.dmSans(
                    color: Colors.white60,
                    fontSize: 10.5,
                  ),
                ),
                const Spacer(),
                Text(
                  registered,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
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
                      color: isSelected ? Colors.white : _ink,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: .2)
                          : _soft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : _inkSoft,
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
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: _muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: _ink,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Search course by name, code or grade...',
                hintStyle: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  color: _muted,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() {});
              },
              child: const Icon(Icons.close_rounded, size: 16, color: _muted),
            ),
        ],
      ),
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
          child: const Icon(
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
                const Icon(Icons.calendar_month_outlined, size: 16, color: _navy),
                const SizedBox(width: 8),
                Text(
                  semester,
                  style: GoogleFonts.dmSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const Spacer(),
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
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• ${semCourses.length} courses',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
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

  Widget _buildCourse(dynamic course) {
    final grade = course['grade']?.toString() ?? '-';
    final color = _getGradeColor(grade);
    final code = course['course_code']?.toString() ?? '';
    final title = course['course_title']?.toString() ?? 'Course';
    final credits = course['credits']?.toString() ?? '0';
    final type = course['course_type']?.toString() ?? '';
    final month = course['exam_month']?.toString() ?? '';
    final distribution = course['course_distribution']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: .35),
              ),
            ),
            child: Center(
              child: Text(
                grade,
                style: GoogleFonts.dmSans(
                  color: color,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (code.isNotEmpty)
                      _Pill(
                        code,
                        _blue,
                        const Color(0xFFEAF0FD),
                      ),
                    _Pill(
                      '$credits CREDITS',
                      _muted,
                      _soft,
                    ),
                    if (distribution.isNotEmpty)
                      _Pill(
                        distribution,
                        _inkSoft,
                        _soft,
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.18,
                  ),
                ),
                if (type.isNotEmpty || month.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      if (type.isNotEmpty)
                        _Pill(type, _muted, _soft),
                      if (month.isNotEmpty)
                        _Pill(
                          month,
                          _orange,
                          const Color(0xFFF9ECE7),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
          const Icon(
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
          const SizedBox(
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
                    child: const Icon(
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
                    error.toString(),
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
                      foregroundColor: Colors.white,
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
