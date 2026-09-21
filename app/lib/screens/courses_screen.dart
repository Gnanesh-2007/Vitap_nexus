import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  late Future<Map<String, dynamic>> _coursesFuture;

  // Selected Course & Faculty Section State
  Map<String, dynamic>? _selectedCourse;
  List<dynamic> _classSections = [];
  int _selectedSectionIndex = 0;
  bool _isLoadingSections = false;

  Map<String, dynamic>? _currentCourseDetail;
  bool _isLoadingDetail = false;
  bool _isDownloading = false;
  int _sectionRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  void _loadCourses({bool forceRefresh = false}) {
    _coursesFuture = _getCoursesData(forceRefresh: forceRefresh);
  }

  Future<Map<String, dynamic>> _getCoursesData({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final mem = StorageService.getMemoryCache('courses');
      if (mem is Map && mem.isNotEmpty) {
        return Map<String, dynamic>.from(mem);
      }
      final disk = await StorageService.getCache('courses');
      if (disk is Map && disk.isNotEmpty) {
        return Map<String, dynamic>.from(disk);
      }
    }

    final auth = ref.read(authProvider);
    final creds = await StorageService.getCredentials();
    final semId = auth.activeSemesterId ?? creds['semesterId'] ?? '';
    try {
      final fresh = await apiService.fetchCoursePageCourses(
        username: auth.username ?? creds['username'] ?? '',
        password: auth.password ?? creds['password'] ?? '',
        semSubId: semId,
      );
      if (fresh.isNotEmpty) {
        await StorageService.setCache('courses', fresh);
        return fresh;
      }
    } catch (e) {
      debugPrint('CoursesScreen: Courses fetch failed ($e). Checking offline cache...');
      final fallback = StorageService.getMemoryCache('courses') ??
          await StorageService.getCache('courses');
      if (fallback is Map && fallback.isNotEmpty) {
        return Map<String, dynamic>.from(fallback);
      }
      rethrow;
    }

    final fallback = StorageService.getMemoryCache('courses') ??
        await StorageService.getCache('courses');
    if (fallback is Map && fallback.isNotEmpty) {
      return Map<String, dynamic>.from(fallback);
    }
    return {};
  }

  Future<void> _selectCourse(Map<String, dynamic> course) async {
    final auth = ref.read(authProvider);
    final username = auth.username ?? '';
    final password = auth.password ?? '';
    final semId = auth.activeSemesterId ?? '';
    final courseValue = course['value']?.toString() ?? '';

    setState(() {
      _selectedCourse = course;
      _classSections = [];
      _selectedSectionIndex = 0;
      _isLoadingSections = true;
      _currentCourseDetail = null;
    });

    try {
      // 1. Fetch all slots / faculty entries for this course
      final slotsData = await apiService.fetchCoursePageSlots(
        username: username,
        password: password,
        semSubId: semId,
        classId: courseValue,
      );

      final entries = (slotsData['class_entries'] as List<dynamic>?) ?? [];
      if (!mounted) return;

      setState(() {
        _classSections = entries;
        _isLoadingSections = false;
      });

      if (entries.isNotEmpty) {
        _loadSectionDetail(0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingSections = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppTheme.error, content: Text('Error loading sections: $e')),
      );
    }
  }

  Future<void> _loadSectionDetail(int index) async {
    if (index < 0 || index >= _classSections.length) return;

    final section = _classSections[index];
    final auth = ref.read(authProvider);
    final username = auth.username ?? '';
    final password = auth.password ?? '';
    final semId = auth.activeSemesterId ?? '';

    final erpId = section['erp_id']?.toString() ?? '';
    final classId = section['class_id']?.toString() ??
        (_selectedCourse?['value']?.toString() ?? '');

    // Change the selected faculty immediately. The UI must remain tappable
    // while the new section's materials are loading.
    final requestId = ++_sectionRequestId;

    setState(() {
      _selectedSectionIndex = index;
      _isLoadingDetail = true;
      _currentCourseDetail = null;
    });

    try {
      final detail = await apiService.fetchCourseDetail(
        username: username,
        password: password,
        semSubId: semId,
        erpId: erpId,
        classId: classId,
      );

      if (!mounted || requestId != _sectionRequestId) return;

      setState(() {
        _currentCourseDetail = detail;
        _isLoadingDetail = false;
      });
    } catch (e) {
      if (!mounted || requestId != _sectionRequestId) return;

      setState(() {
        _isLoadingDetail = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          content: Text('Error loading course materials: $e'),
        ),
      );
    }
  }

  Future<void> _downloadMaterial(String downloadPath, String filename) async {
    if (downloadPath.isEmpty) return;
    final auth = ref.read(authProvider);

    setState(() => _isDownloading = true);
    try {
      final bytes = await apiService.downloadCourseMaterial(
        username: auth.username ?? '',
        password: auth.password ?? '',
        downloadPath: downloadPath,
      );

      if (!mounted) return;
      setState(() => _isDownloading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.success,
          content: Text(
            'Downloaded "$filename" (${(bytes.length / 1024).toStringAsFixed(1)} KB)',
            style: GoogleFonts.dmSans(color: Colors.white),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppTheme.error, content: Text('Download failed: $e')),
      );
    }
  }


  String _courseSearchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          onPressed: () {
            if (_selectedCourse != null) {
              setState(() {
                _selectedCourse = null;
                _classSections = [];
                _currentCourseDetail = null;
                _courseSearchQuery = '';
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          _selectedCourse == null ? 'Courses' : 'Course details',
          style: GoogleFonts.dmSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.ink,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: _selectedCourse == null
          ? _buildCoursesHome()
          : _buildCourseDetailView(),
    );
  }

  Widget _buildCoursesHome() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _loadCourses(forceRefresh: true));
        await _coursesFuture;
      },
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _coursesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildCoursesLoading();
          }

          if (snapshot.hasError) {
            return _buildCourseError(snapshot.error.toString());
          }

          final data = snapshot.data ?? {};
          final courses = (data['courses'] as List<dynamic>?) ?? [];

          if (courses.isEmpty) {
            return _buildEmptyCourses();
          }

          final filtered = courses.where((course) {
            final q = _courseSearchQuery.trim().toLowerCase();
            if (q.isEmpty) return true;

            final code = course['course_code']?.toString().toLowerCase() ?? '';
            final title = course['course_title']?.toString().toLowerCase() ??
                course['label']?.toString().toLowerCase() ??
                '';
            final type = course['course_type']?.toString().toLowerCase() ?? '';

            return code.contains(q) || title.contains(q) || type.contains(q);
          }).toList();

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
            children: [
              _buildCoursesHero(courses.length),
              const SizedBox(height: 18),
              _buildCourseSearch(),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Your courses',
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${filtered.length} shown',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.muted,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (filtered.isEmpty)
                _buildNoSearchResults()
              else
                ...filtered.asMap().entries.map(
                  (entry) => _buildCourseTile(
                    entry.value,
                    entry.key,
                    courses.length,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCoursesHero(int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: AppTheme.navy,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count COURSES',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Your academic\nworkspace.',
            style: GoogleFonts.dmSans(
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'Open a course to view faculty sections, lecture notes, syllabus and course materials.',
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.70),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              const Icon(
                Icons.touch_app_rounded,
                size: 15,
                color: Color(0xFFBFD1FF),
              ),
              const SizedBox(width: 7),
              Text(
                'Tap any course to open its workspace',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCourseSearch() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: TextField(
        onChanged: (value) {
          setState(() => _courseSearchQuery = value);
        },
        style: GoogleFonts.dmSans(
          fontSize: 13,
          color: AppTheme.ink,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Search course code or name',
          hintStyle: GoogleFonts.dmSans(
            fontSize: 13,
            color: AppTheme.mutedLight,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppTheme.muted,
          ),
          suffixIcon: _courseSearchQuery.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    setState(() => _courseSearchQuery = '');
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppTheme.muted,
                  ),
                ),
          filled: true,
          fillColor: AppTheme.surface,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildCourseTile(
    dynamic course,
    int index,
    int total,
  ) {
    final code = course['course_code']?.toString() ?? '';
    final title = course['course_title']?.toString() ??
        course['label']?.toString() ??
        'Course';
    final type = course['course_type']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectCourse(course),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 13, 14, 13),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EEE8),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    (index + 1).toString().padLeft(2, '0'),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (code.isNotEmpty)
                        Text(
                          code.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                      if (type.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8EEF9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            type,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: AppTheme.navy,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCourseDetailView() {
    if (_isLoadingSections) {
      return _buildCoursesLoading();
    }

    final activeSection =
        _classSections.isNotEmpty &&
                _selectedSectionIndex < _classSections.length
            ? _classSections[_selectedSectionIndex]
            : null;

    final syllabusPath =
        _currentCourseDetail?['syllabus_download_path']?.toString() ?? '';
    final coursePlanPath =
        _currentCourseDetail?['course_plan_download_path']?.toString() ?? '';
    final downloadAllPath =
        _currentCourseDetail?['download_all_path']?.toString() ?? '';
    final lectures =
        (_currentCourseDetail?['lectures'] as List<dynamic>?) ?? [];

    final courseCode =
        _selectedCourse?['course_code']?.toString() ??
        activeSection?['course_code']?.toString() ??
        '';
    final courseTitle =
        _selectedCourse?['course_title']?.toString() ??
        activeSection?['course_title']?.toString() ??
        'Course Detail';

    // One vertical scroll container owns the entire detail page.
    // This is important: the faculty selector is horizontal, while the
    // lecture archive is part of this same vertical scroll view.
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDetailHero(
            courseCode,
            courseTitle,
            activeSection,
          ),
          if (_classSections.length > 1) ...[
            const SizedBox(height: 20),
            _buildSectionSelector(),
          ],
          const SizedBox(height: 20),

          if (_isLoadingDetail)
            _buildDetailLoading()
          else ...[
            _buildResourcePanel(
              syllabusPath,
              coursePlanPath,
              downloadAllPath,
            ),
            const SizedBox(height: 28),
            _buildLectureHeader(lectures.length),
            const SizedBox(height: 12),

            if (lectures.isEmpty)
              _buildNoLectures()
            else
              Column(
                children: lectures.asMap().entries.map((entry) {
                  return _buildLectureCard(
                    entry.value,
                    entry.key,
                    lectures.length,
                  );
                }).toList(),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailHero(
    String code,
    String title,
    dynamic activeSection,
  ) {
    final faculty = activeSection?['faculty']?.toString() ?? '';
    final slot = activeSection?['slot']?.toString() ?? '';
    final type = activeSection?['course_type']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: AppTheme.navy,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  code.isEmpty ? 'COURSE' : code.toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFBFD1FF),
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              if (type.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    type,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 25,
              height: 1.12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.6,
            ),
          ),
          if (faculty.isNotEmpty || slot.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.12),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 16,
                  color: Color(0xFFD9E3FF),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    faculty.isEmpty ? 'Faculty not available' : faculty,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ),
                if (slot.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.schedule_rounded,
                    size: 15,
                    color: Color(0xFFD9E3FF),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    slot,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.76),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'FACULTY / SECTION',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.muted,
                letterSpacing: 0.9,
              ),
            ),
            const Spacer(),
            if (_classSections.length > 1)
              Text(
                'SWIPE →',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
          ],
        ),
        const SizedBox(height: 9),

        // A plain horizontal SingleChildScrollView + Row is deliberately used
        // here. It gives each faculty card a real hit-test area and avoids the
        // nested horizontal ListView feeling "stuck" inside the page scroll.
        SizedBox(
          height: 82,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(_classSections.length, (index) {
                final section = _classSections[index];
                final selected = index == _selectedSectionIndex;
                final faculty =
                    section['faculty']?.toString() ?? 'Faculty';
                final slot = section['slot']?.toString() ?? '';
                final type = section['course_type']?.toString() ?? '';

                return Padding(
                  padding: EdgeInsets.only(
                    right: index == _classSections.length - 1 ? 0 : 9,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _loadSectionDetail(index),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 205,
                        height: 82,
                        padding: const EdgeInsets.fromLTRB(13, 11, 13, 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.navy
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? AppTheme.navy
                                : AppTheme.cardBorder,
                          ),
                          boxShadow: selected
                              ? AppTheme.cardShadow
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type.isEmpty
                                  ? 'SECTION'
                                  : type.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: selected
                                    ? const Color(0xFFBFD1FF)
                                    : AppTheme.primary,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              faculty,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : AppTheme.ink,
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 12,
                                  color: selected
                                      ? Colors.white.withValues(alpha: 0.65)
                                      : AppTheme.muted,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    slot.isEmpty
                                        ? 'Faculty section'
                                        : 'Slot $slot',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? Colors.white.withValues(
                                              alpha: 0.65,
                                            )
                                          : AppTheme.muted,
                                    ),
                                  ),
                                ),
                                if (selected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 14,
                                    color: Color(0xFFBFD1FF),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResourcePanel(
    String syllabusPath,
    String coursePlanPath,
    String downloadAllPath,
  ) {
    final hasAny =
        syllabusPath.isNotEmpty ||
        coursePlanPath.isNotEmpty ||
        downloadAllPath.isNotEmpty;

    if (!hasAny) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EEE8),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                color: AppTheme.muted,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No quick-download resources are available for this section.',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  height: 1.4,
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUICK RESOURCES',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (syllabusPath.isNotEmpty)
                Expanded(
                  child: _resourceButton(
                    label: 'Syllabus',
                    icon: Icons.description_outlined,
                    color: AppTheme.primary,
                    onTap: _isDownloading
                        ? null
                        : () => _downloadMaterial(
                              syllabusPath,
                              'Syllabus.pdf',
                            ),
                  ),
                ),
              if (syllabusPath.isNotEmpty && coursePlanPath.isNotEmpty)
                const SizedBox(width: 8),
              if (coursePlanPath.isNotEmpty)
                Expanded(
                  child: _resourceButton(
                    label: 'Course plan',
                    icon: Icons.menu_book_outlined,
                    color: AppTheme.amberAccent,
                    onTap: _isDownloading
                        ? null
                        : () => _downloadMaterial(
                              coursePlanPath,
                              'CoursePlan.pdf',
                            ),
                  ),
                ),
              if (downloadAllPath.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _resourceButton(
                    label: 'All files',
                    icon: Icons.archive_outlined,
                    color: AppTheme.navy,
                    filled: true,
                    onTap: _isDownloading
                        ? null
                        : () => _downloadMaterial(
                              downloadAllPath,
                              'All_Materials.zip',
                            ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _resourceButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: filled ? color : color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: filled ? color : color.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: filled ? Colors.white : color,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: filled ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLectureHeader(int count) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lecture archive',
              style: GoogleFonts.dmSans(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Notes and reference materials',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppTheme.muted,
              ),
            ),
          ],
        ),
        const Spacer(),
        Text(
          '$count LECTURES',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
            letterSpacing: 0.7,
          ),
        ),
      ],
    );
  }

  Widget _buildLectureCard(dynamic lecture, int index, int total) {
    final materials =
        (lecture['reference_materials'] as List<dynamic>?) ?? [];
    final topic = lecture['topic']?.toString() ?? 'Lecture';
    final date = lecture['formatted_date']?.toString() ??
        lecture['date']?.toString() ??
        '';
    final serial = lecture['sl_no']?.toString() ?? '${index + 1}';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 13),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: index == 0
                      ? AppTheme.navy
                      : const Color(0xFFE8EEF9),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  serial,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color:
                        index == 0 ? Colors.white : AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LECTURE ${serial.padLeft(2, '0')}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      topic,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (date.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 1),
                  child: Text(
                    date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.muted,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 11),

          Row(
            children: [
              const Icon(
                Icons.folder_outlined,
                size: 14,
                color: AppTheme.muted,
              ),
              const SizedBox(width: 5),
              Text(
                materials.isEmpty
                    ? 'No attachments'
                    : '${materials.length} attachment${materials.length == 1 ? '' : 's'}',
                style: GoogleFonts.dmSans(
                  fontSize: 10.5,
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          if (materials.isNotEmpty) ...[
            const SizedBox(height: 11),
            Container(
              height: 1,
              color: AppTheme.cardBorderLight,
            ),
            const SizedBox(height: 7),
            Text(
              'ATTACHMENTS',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.muted,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 5),
            ...materials.map((material) {
              final label =
                  material['label']?.toString() ?? 'Material file';
              final path =
                  material['download_path']?.toString() ?? '';

              return Container(
                margin: const EdgeInsets.only(top: 5),
                padding: const EdgeInsets.fromLTRB(9, 7, 5, 7),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: AppTheme.cardBorderLight,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 15,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      icon: const Icon(
                        Icons.download_rounded,
                        size: 17,
                        color: AppTheme.primary,
                      ),
                      onPressed: _isDownloading
                          ? null
                          : () => _downloadMaterial(
                                path,
                                '$label.pdf',
                              ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildCoursesLoading() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 23,
              height: 23,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 13),
            Text(
              'Loading courses...',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseError(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_off_rounded,
                      color: AppTheme.error,
                      size: 29,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Couldn’t load courses',
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      height: 1.4,
                      color: AppTheme.muted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _loadCourses(forceRefresh: true));
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCourses() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EEF9),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: AppTheme.primary,
                      size: 31,
                    ),
                  ),
                  const SizedBox(height: 17),
                  Text(
                    'No courses found',
                    style: GoogleFonts.dmSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'No registered courses are available on the active Course Page.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      height: 1.4,
                      color: AppTheme.muted,
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

  Widget _buildNoSearchResults() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 28,
            color: AppTheme.muted,
          ),
          const SizedBox(height: 9),
          Text(
            'No matching courses',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Try another course code or name.',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: AppTheme.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailLoading() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Fetching lecture notes & files...',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoLectures() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.folder_off_outlined,
            size: 29,
            color: AppTheme.muted,
          ),
          const SizedBox(height: 9),
          Text(
            'No lecture materials yet',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Nothing has been uploaded for this faculty section.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: AppTheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}
