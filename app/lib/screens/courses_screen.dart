import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../utils/download_helper.dart';
import '../utils/error_formatter.dart';

class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  late Future<Map<String, dynamic>> _coursesFuture;

  // Selected Course
  Map<String, dynamic>? _selectedCourse;

  // Faculty class entries for the selected course
  List<dynamic> _classSections = [];
  bool _isLoadingSections = false;

  // Selected Slot filter (e.g. 'All', 'D1/TD1', 'D1/TDD1', etc.)
  String _selectedSlot = 'All';

  // Details for the currently viewed faculty section
  Map<String, dynamic>? _currentCourseDetail;
  bool _isLoadingDetail = false;
  bool _isDownloading = false;

  // Campus Editorial Palette
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
      _selectedSlot = 'All';
      _isLoadingSections = true;
      _currentCourseDetail = null;
    });

    try {
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingSections = false);
      _showMessage(ErrorFormatter.format(e, fallback: 'Unable to load course faculties. Please try again.'), color: _red);
    }
  }

  Future<void> _loadFacultyDetailAndOpenModal(dynamic section) async {
    final auth = ref.read(authProvider);
    final username = auth.username ?? '';
    final password = auth.password ?? '';
    final semId = auth.activeSemesterId ?? '';

    final erpId = section['erp_id']?.toString() ?? '';
    final classId = section['class_id']?.toString() ??
        (_selectedCourse?['value']?.toString() ?? '');

    setState(() {
      _isLoadingDetail = true;
      _currentCourseDetail = null;
    });

    // Open modal bottom sheet immediately with loading state
    _showFacultyWorkspaceBottomSheet(section);

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
      setState(() {
        _isLoadingDetail = false;
      });
      _showMessage(ErrorFormatter.format(e, fallback: 'Unable to load course materials. Please try again.'), color: _red);
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

      final cleanName = filename.isNotEmpty ? filename : 'Course_Material.pdf';
      await DownloadHelper.saveFile(
        context: context,
        fileName: cleanName,
        content: bytes,
        mimeType: 'application/pdf',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      _showMessage(ErrorFormatter.format(e, fallback: 'Download could not be completed. Please try again.'), color: _red);
    }
  }

  void _showMessage(String msg, {required Color color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          msg,
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  List<String> _extractSlots(List<dynamic> entries) {
    final List<String> slots = [];
    for (final e in entries) {
      final s = (e['slot']?.toString() ?? '').trim();
      if (s.isNotEmpty && !slots.contains(s)) {
        slots.add(s);
      }
    }
    return slots;
  }

  String _formatCourseDisplayTitle(Map<String, dynamic> course) {
    final title = (course['course_title']?.toString() ?? '').trim();
    final type = (course['course_type']?.toString() ?? '').trim();
    final label = (course['label']?.toString() ?? '').trim();

    if (title.isNotEmpty && type.isNotEmpty) {
      return '$title - $type';
    } else if (title.isNotEmpty) {
      return title;
    } else if (label.isNotEmpty) {
      return label;
    }
    return 'Choose a course';
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
            setState(() => _loadCourses(forceRefresh: true));
            await _coursesFuture;
          },
          child: FutureBuilder<Map<String, dynamic>>(
            future: _coursesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoading();
              }

              if (snapshot.hasError) {
                return _buildError(
                  ErrorFormatter.format(
                    snapshot.error,
                    fallback: 'Unable to load registered courses. Please check your connection and try again.',
                  ),
                );
              }

              final data = snapshot.data ?? {};
              final courses = (data['courses'] as List<dynamic>?) ?? [];

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 14),

                  // Top Course Selection Box (Image 1 & 3 Model)
                  _buildCourseSelectorBox(courses),
                  const SizedBox(height: 18),

                  // If no course is selected -> Show Center Empty State (Image 1)
                  if (_selectedCourse == null)
                    _buildInitialEmptyState()
                  else ...[
                    // When course is selected:
                    if (_isLoadingSections)
                      _buildSectionsLoading()
                    else ...[
                      // Horizontal Slot Filters (Image 3 Model)
                      _buildSlotFilterBar(),
                      const SizedBox(height: 20),

                      // Faculty Section Title
                      _buildFacultySectionHeader(),
                      const SizedBox(height: 12),

                      // Faculty List Cards (Image 3 Model)
                      _buildFacultyList(),
                    ],
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildHeader() {
    return Row(
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
                'Course Page',
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
          onTap: () => setState(() => _loadCourses(forceRefresh: true)),
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
    );
  }

  // ============================================================
  // TOP COURSE SELECTOR BOX (Images 1 & 3)
  // ============================================================
  Widget _buildCourseSelectorBox(List<dynamic> courses) {
    final isSelected = _selectedCourse != null;
    final displayTitle = isSelected
        ? _formatCourseDisplayTitle(_selectedCourse!)
        : 'Choose a course';

    return InkWell(
      onTap: () => _openCoursePickerBottomSheet(courses),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _navy : _line,
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x0A172B4D),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Course',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? _blue : _muted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_stories_outlined,
                    size: 17,
                    color: _navy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 14.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? _ink : _muted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _inkSoft,
                  size: 22,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY INITIAL STATE (Image 1)
  // ============================================================
  Widget _buildInitialEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 110, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
              border: Border.all(color: _line),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              size: 38,
              color: _muted,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Select a course',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _inkSoft,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap the course selector above to choose a subject',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: _muted,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ============================================================
  // COURSE PICKER BOTTOM SHEET (Image 2)
  // ============================================================
  void _openCoursePickerBottomSheet(List<dynamic> courses) {
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = courses.where((c) {
              final q = searchQuery.trim().toLowerCase();
              if (q.isEmpty) return true;
              final code = (c['course_code'] ?? '').toString().toLowerCase();
              final title = (c['course_title'] ?? c['label'] ?? '').toString().toLowerCase();
              final type = (c['course_type'] ?? '').toString().toLowerCase();
              return code.contains(q) || title.contains(q) || type.contains(q);
            }).toList();

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.78,
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header
                    Row(
                      children: [
                        Text(
                          'Choose Course',
                          style: GoogleFonts.dmSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _soft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${courses.length} COURSES',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: _navy,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Search input
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _soft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, size: 18, color: _muted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              autofocus: false,
                              onChanged: (val) {
                                setModalState(() => searchQuery = val);
                              },
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: _ink,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search course code or name...',
                                hintStyle: GoogleFonts.dmSans(
                                  fontSize: 12.5,
                                  color: _muted,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Course list (matching Image 2)
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No matching courses found',
                                style: GoogleFonts.dmSans(color: _muted, fontSize: 13),
                              ),
                            )
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) => const Divider(height: 1, color: _line),
                              itemBuilder: (context, index) {
                                final course = filtered[index];
                                final isChosen = _selectedCourse?['value'] == course['value'];
                                final title = _formatCourseDisplayTitle(course);
                                final code = course['course_code']?.toString() ?? '';

                                return InkWell(
                                  onTap: () {
                                    Navigator.of(modalCtx).pop();
                                    _selectCourse(course);
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (code.isNotEmpty)
                                                Text(
                                                  code.toUpperCase(),
                                                  style: GoogleFonts.spaceGrotesk(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: _blue,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              const SizedBox(height: 2),
                                              Text(
                                                title,
                                                style: GoogleFonts.dmSans(
                                                  fontSize: 14.5,
                                                  fontWeight:
                                                      isChosen ? FontWeight.w800 : FontWeight.w600,
                                                  color: isChosen ? _blue : _ink,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isChosen)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: _blue,
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // SLOT FILTER BAR (Image 3)
  // ============================================================
  Widget _buildSlotFilterBar() {
    final slots = _extractSlots(_classSections);
    final allSlots = ['All', ...slots];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: allSlots.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final slot = allSlots[index];
          final isSelected = _selectedSlot == slot;

          return InkWell(
            onTap: () => setState(() => _selectedSlot = slot),
            borderRadius: BorderRadius.circular(19),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
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
                  if (isSelected) ...[
                    const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    slot,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : _ink,
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

  // ============================================================
  // FACULTY SECTION HEADER (Image 3)
  // ============================================================
  Widget _buildFacultySectionHeader() {
    final filtered = _getFilteredFaculties();

    return Row(
      children: [
        Text(
          'Select Faculty',
          style: GoogleFonts.dmSans(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _soft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${filtered.length} FACULTIES',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),
        ),
      ],
    );
  }

  List<dynamic> _getFilteredFaculties() {
    if (_selectedSlot == 'All') {
      return _classSections;
    }
    return _classSections
        .where((s) => (s['slot']?.toString() ?? '').trim() == _selectedSlot)
        .toList();
  }

  // ============================================================
  // FACULTY LIST CARDS (Image 3)
  // ============================================================
  Widget _buildFacultyList() {
    final filtered = _getFilteredFaculties();

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
        ),
        child: Center(
          child: Text(
            'No faculty sections found for slot "$_selectedSlot".',
            style: GoogleFonts.dmSans(color: _muted, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: filtered.map((section) {
        final facultyName = section['faculty']?.toString() ?? 'Faculty';
        final courseCode = section['course_code']?.toString() ??
            _selectedCourse?['course_code']?.toString() ??
            '';
        final slot = section['slot']?.toString() ?? '';
        final subtitle = courseCode.isNotEmpty && slot.isNotEmpty
            ? '$courseCode - $slot'
            : (slot.isNotEmpty ? slot : courseCode);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _loadFacultyDetailAndOpenModal(section),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            facultyName,
                            style: GoogleFonts.dmSans(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _inkSoft,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ).animate().fadeIn(duration: 250.ms);
  }

  // ============================================================
  // FACULTY WORKSPACE MODAL (Syllabus, Notes, Reference Material)
  // ============================================================
  void _showFacultyWorkspaceBottomSheet(dynamic section) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final faculty = section['faculty']?.toString() ?? 'Faculty';
            final slot = section['slot']?.toString() ?? '';
            final courseCode = section['course_code']?.toString() ??
                _selectedCourse?['course_code']?.toString() ??
                '';
            final courseTitle = _selectedCourse?['course_title']?.toString() ??
                _formatCourseDisplayTitle(_selectedCourse ?? {});

            final syllabusPath =
                _currentCourseDetail?['syllabus_download_path']?.toString() ?? '';
            final coursePlanPath =
                _currentCourseDetail?['course_plan_download_path']?.toString() ?? '';
            final downloadGeneralPath =
                _currentCourseDetail?['download_general_materials_path']?.toString() ?? '';
            final downloadAllPath =
                _currentCourseDetail?['download_all_path']?.toString() ?? '';
            final lectures =
                (_currentCourseDetail?['lectures'] as List<dynamic>?) ?? [];

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.86,
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Faculty & Course Title Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _navy,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                courseCode.toUpperCase(),
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFBFD1FF),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const Spacer(),
                              if (slot.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    slot,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            courseTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.person_outline_rounded,
                                  size: 15, color: Color(0xFFD9E3FF)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  faculty,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Material / Download buttons
                    if (_isLoadingDetail)
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: _navy,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          children: [
                            // Quick Action Buttons
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (syllabusPath.isNotEmpty)
                                  _buildActionButton(
                                    icon: Icons.menu_book_outlined,
                                    label: 'Syllabus',
                                    color: _blue,
                                    onTap: () => _downloadMaterial(
                                        syllabusPath, '$courseCode-Syllabus.pdf'),
                                  ),
                                if (coursePlanPath.isNotEmpty)
                                  _buildActionButton(
                                    icon: Icons.calendar_today_outlined,
                                    label: 'Course Plan',
                                    color: _green,
                                    onTap: () => _downloadMaterial(
                                        coursePlanPath, '$courseCode-CoursePlan.pdf'),
                                  ),
                                if (downloadGeneralPath.isNotEmpty)
                                  _buildActionButton(
                                    icon: Icons.library_books_outlined,
                                    label: 'Ref Materials',
                                    color: const Color(0xFF6575C5),
                                    onTap: () => _downloadMaterial(
                                        downloadGeneralPath, '$courseCode-GeneralRef.zip'),
                                  ),
                                if (downloadAllPath.isNotEmpty)
                                  _buildActionButton(
                                    icon: Icons.folder_zip_outlined,
                                    label: 'Download All',
                                    color: _orange,
                                    onTap: () => _downloadMaterial(
                                        downloadAllPath, '$courseCode-Materials.zip'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Lecture Topics Header
                            Row(
                              children: [
                                Text(
                                  'LECTURE NOTES & TOPICS',
                                  style: _micro.copyWith(color: _ink),
                                ),
                                const Spacer(),
                                Text(
                                  '${lectures.length} SESSIONS',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Lectures List
                            if (lectures.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: _soft,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    'No lecture materials uploaded yet.',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12.5,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ...lectures.map((lec) => _buildLectureItem(lec)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isDownloading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLectureItem(dynamic lec) {
    final slNo = lec['sl_no']?.toString() ?? '';
    final date = (lec['formatted_date'] ?? lec['date'] ?? lec['class_date'] ?? '').toString();
    final topic = (lec['topic'] ?? 'Lecture Session').toString();
    
    final rawMaterials = lec['reference_materials'] ?? lec['materials'] ?? [];
    final List<dynamic> materials = rawMaterials is List ? rawMaterials : [];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (slNo.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _line),
                  ),
                  child: Text(
                    '#$slNo',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                ),
              const Spacer(),
              if (date.isNotEmpty)
                Text(
                  date,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _inkSoft,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            topic,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          if (materials.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: materials.map((m) {
                final matTitle = (m['label'] ?? m['material_title'] ?? m['title'] ?? 'Reference Material').toString();
                final downloadPath = (m['download_path'] ?? '').toString();
                final cleanExt = matTitle.toLowerCase().endsWith('.pdf') ? '' : '.pdf';
                final filename = (m['filename'] ?? '$matTitle$cleanExt').toString();

                if (downloadPath.isEmpty) return const SizedBox.shrink();

                return InkWell(
                  onTap: () => _downloadMaterial(downloadPath, filename),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFC7D7F8)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.download_rounded, size: 13, color: _blue),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            matTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // LOADERS & ERROR STATES
  // ============================================================
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
              color: _navy,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Loading course page...',
            style: GoogleFonts.dmSans(
              color: _muted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionsLoading() {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: Column(
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: _navy,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading faculty sections...',
            style: GoogleFonts.dmSans(
              color: _muted,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: Color(0xFFFCEDEA),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: _red, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              'Failed to Load Courses',
              style: GoogleFonts.dmSans(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: _muted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => setState(() => _loadCourses(forceRefresh: true)),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
