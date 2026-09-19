import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mesh_ambient_background.dart';

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
    if (index >= _classSections.length) return;
    final section = _classSections[index];
    final auth = ref.read(authProvider);
    final username = auth.username ?? '';
    final password = auth.password ?? '';
    final semId = auth.activeSemesterId ?? '';

    final erpId = section['erp_id']?.toString() ?? '';
    final classId = section['class_id']?.toString() ?? (_selectedCourse?['value']?.toString() ?? '');

    setState(() {
      _selectedSectionIndex = index;
      _isLoadingDetail = true;
    });

    try {
      final detail = await apiService.fetchCourseDetail(
        username: username,
        password: password,
        semSubId: semId,
        erpId: erpId,
        classId: classId,
      );

      if (!mounted) return;
      setState(() {
        _currentCourseDetail = detail;
        _isLoadingDetail = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingDetail = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppTheme.error, content: Text('Error loading course materials: $e')),
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
          backgroundColor: const Color(0xFF10B981),
          content: Text(
            'Downloaded "$filename" (${(bytes.length / 1024).toStringAsFixed(1)} KB)',
            style: GoogleFonts.inter(color: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _selectedCourse == null ? 'Course Materials' : (_selectedCourse!['course_code'] ?? 'Course Detail'),
          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (_selectedCourse != null) {
              setState(() {
                _selectedCourse = null;
                _classSections = [];
                _currentCourseDetail = null;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          if (_selectedCourse == null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => setState(() => _loadCourses()),
            ),
        ],
      ),
      body: MeshAmbientBackground(
        child: _selectedCourse == null ? _buildCoursesList() : _buildCourseDetailView(),
      ),
    );
  }

  Widget _buildCoursesSkeleton() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(height: 16),
          Text('Loading courses...', style: TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCoursesList() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _coursesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCoursesSkeleton();
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 48),
                  const SizedBox(height: 12),
                  Text('Failed to load courses', style: GoogleFonts.outfit(fontSize: 18, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _loadCourses(forceRefresh: true)),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final courses = (data['courses'] as List<dynamic>?) ?? [];

        if (courses.isEmpty) {
          return Center(
            child: Text('No registered courses found on Course Page.', style: GoogleFonts.inter(color: Colors.white60)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: courses.length,
          itemBuilder: (context, index) {
            final c = courses[index];
            final code = c['course_code'] ?? '';
            final title = c['course_title'] ?? c['label'] ?? 'Course';
            final type = c['course_type'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _selectCourse(c),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.menu_book_rounded, color: AppTheme.primaryAccent, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (code.isNotEmpty)
                              Text(
                                code,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryAccent,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              title,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            if (type.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(type, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
            )
                .animate(delay: (30 * index).ms)
                .fadeIn(duration: 350.ms)
                .slideY(begin: 0.05, end: 0);
          },
        );
      },
    );
  }

  Widget _buildCourseDetailView() {
    if (_isLoadingSections) {
      return _buildCoursesSkeleton();
    }

    final activeSection = _classSections.isNotEmpty && _selectedSectionIndex < _classSections.length
        ? _classSections[_selectedSectionIndex]
        : null;

    final syllabusPath = _currentCourseDetail?['syllabus_download_path']?.toString() ?? '';
    final coursePlanPath = _currentCourseDetail?['course_plan_download_path']?.toString() ?? '';
    final downloadAllPath = _currentCourseDetail?['download_all_path']?.toString() ?? '';
    final lectures = (_currentCourseDetail?['lectures'] as List<dynamic>?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        // ─── Multiple Faculty / Section Selector ─────────────────────────────
        if (_classSections.length > 1) ...[
          Text(
            'Select Faculty / Section (${_classSections.length} Available)',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_classSections.length, (idx) {
                final sec = _classSections[idx];
                final isSelected = idx == _selectedSectionIndex;
                final facultyName = sec['faculty']?.toString() ?? 'Faculty';
                final slot = sec['slot']?.toString() ?? '';
                final type = sec['course_type']?.toString() ?? '';

                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: FilterChip(
                    selected: isSelected,
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.surface,
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? AppTheme.primaryAccent : const Color(0xFF24344D),
                    ),
                    label: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$type ($slot)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppTheme.cyanAccent,
                          ),
                        ),
                        Text(
                          facultyName,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: isSelected ? Colors.white70 : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    onSelected: (_) => _loadSectionDetail(idx),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ─── Active Faculty Card ─────────────────────────────────────────────
        if (activeSection != null)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      activeSection['course_code'] ?? _selectedCourse?['course_code'] ?? '',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryAccent),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        activeSection['course_type'] ?? 'Course',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cyanAccent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  activeSection['course_title'] ?? _selectedCourse?['course_title'] ?? 'Course Detail',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.person_pin_rounded, size: 16, color: AppTheme.cyanAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        activeSection['faculty'] ?? 'Assigned Faculty',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                    const Icon(Icons.schedule_rounded, size: 14, color: AppTheme.cyanAccent),
                    const SizedBox(width: 4),
                    Text(
                      'Slot: ${activeSection['slot'] ?? ''}',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),

        if (_isLoadingDetail) ...[
          const SizedBox(height: 40),
          const Center(
            child: Column(
              children: [
                CircularProgressIndicator(color: AppTheme.primary),
                SizedBox(height: 12),
                Text('Fetching lecture notes & files...', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ] else ...[
          // ─── Quick Download Buttons Row ────────────────────────────────────
          Row(
            children: [
              if (syllabusPath.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isDownloading ? null : () => _downloadMaterial(syllabusPath, 'Syllabus.pdf'),
                    icon: const Icon(Icons.download_rounded, size: 16, color: AppTheme.cyanAccent),
                    label: const Text('Syllabus', style: TextStyle(color: AppTheme.cyanAccent, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.cyanAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              if (syllabusPath.isNotEmpty && coursePlanPath.isNotEmpty)
                const SizedBox(width: 8),
              if (coursePlanPath.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isDownloading ? null : () => _downloadMaterial(coursePlanPath, 'CoursePlan.pdf'),
                    icon: const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFFF59E0B)),
                    label: const Text('Course Plan', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              if (downloadAllPath.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isDownloading ? null : () => _downloadMaterial(downloadAllPath, 'All_Materials.zip'),
                    icon: const Icon(Icons.archive_rounded, size: 16),
                    label: const Text('Download All', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // ─── Lectures & Materials List ─────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lectures & Materials',
                style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                '${lectures.length} Lectures',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (lectures.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
              child: Center(
                child: Text(
                  'No uploaded lecture materials found for this faculty section.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white60),
                ),
              ),
            )
          else
            ...lectures.map((lec) {
              final mats = (lec['reference_materials'] as List<dynamic>?) ?? [];
              final topic = lec['topic']?.toString() ?? 'Lecture';
              final date = lec['formatted_date'] ?? lec['date'] ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF24344D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lecture #${lec['sl_no'] ?? ''}',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryAccent),
                        ),
                        if (date.isNotEmpty)
                          Text(date, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(topic, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white)),
                    if (mats.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Divider(color: Color(0xFF24344D), height: 1),
                      const SizedBox(height: 8),
                      Text('Downloadable Attachments:', style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
                      const SizedBox(height: 6),
                      ...mats.map((m) {
                        final matLabel = m['label']?.toString() ?? 'Material File';
                        final dPath = m['download_path']?.toString() ?? '';

                        return Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFFEC4899)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  matLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.download_rounded, size: 18, color: AppTheme.cyanAccent),
                                onPressed: _isDownloading ? null : () => _downloadMaterial(dPath, '$matLabel.pdf'),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              );
            }),
        ],
      ],
    );
  }
}
