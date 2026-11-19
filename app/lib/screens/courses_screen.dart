import 'dart:io';

import 'package:flutter/material.dart';
import '../widgets/nexus_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/download_helper.dart';
import '../utils/error_formatter.dart';
import '../widgets/motion/nexus_motion.dart';
import '../widgets/shadcn/shadcn_ui.dart';

String _extractFacultyName(String faculty) {
  final parts = faculty.split(' - ');
  if (parts.length >= 2) {
    return parts[1].trim();
  }
  return faculty.trim();
}

String _getCourseTypeLabel(String type) {
  switch (type.toUpperCase().trim()) {
    case 'ETH':
    case 'TH':
      return 'Theory';
    case 'ELA':
    case 'LO':
      return 'Lab';
    case 'EPJ':
      return 'Project';
    case 'SS':
      return 'Soft Skill';
    default:
      return type;
  }
}

class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  late Future<Map<String, dynamic>> _coursesFuture;
  Map<String, dynamic>? _cachedData;

  // Selected Course
  Map<String, dynamic>? _selectedCourse;

  // Faculty class entries for the selected course
  List<dynamic> _classSections = [];
  bool _isLoadingSections = false;

  // Selected Base Slot filter (e.g. 'All', 'A1', 'B1', 'D1', 'E1', etc.)
  String _selectedSlot = 'All';

  // Campus Editorial Palette
  AppPalette get _palette => AppPalette.of(context);
  Color get _paper => _palette.paper;
  Color get _surface => _palette.surface;
  Color get _ink => _palette.ink;
  Color get _inkSoft => _palette.inkSoft;
  Color get _navy => _palette.navy;
  Color get _blue => _palette.blue;
  Color get _red => _palette.red;
  Color get _muted => _palette.inkMuted;
  Color get _line => _palette.line;
  Color get _soft => _palette.soft;

  @override
  void initState() {
    super.initState();
    final mem = StorageService.getMemoryCache('courses');
    if (mem is Map && mem.isNotEmpty) {
      _cachedData = Map<String, dynamic>.from(mem);
    }
    _loadCourses();
  }

  void _loadCourses({bool forceRefresh = false}) {
    _coursesFuture = _getCoursesData(forceRefresh: forceRefresh).then((data) {
      if (mounted && data.isNotEmpty) {
        setState(() => _cachedData = data);
      }
      return data;
    });
  }

  Future<Map<String, dynamic>> _getCoursesData({
    bool forceRefresh = false,
  }) async {
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
      debugPrint(
        'CoursesScreen: Courses fetch failed ($e). Checking offline cache...',
      );
      final fallback =
          StorageService.getMemoryCache('courses') ??
          await StorageService.getCache('courses');
      if (fallback is Map && fallback.isNotEmpty) {
        return Map<String, dynamic>.from(fallback);
      }
      rethrow;
    }

    final fallback =
        StorageService.getMemoryCache('courses') ??
        await StorageService.getCache('courses');
    if (fallback is Map && fallback.isNotEmpty) {
      return Map<String, dynamic>.from(fallback);
    }
    return {};
  }

  Future<void> _selectCourse(Map<String, dynamic> course) async {
    final auth = ref.read(authProvider);
    final creds = await StorageService.getCredentials();
    final username = auth.username ?? creds['username'] ?? '';
    final password = auth.password ?? creds['password'] ?? '';
    final semId = auth.activeSemesterId ?? creds['semesterId'] ?? '';
    final courseValue = course['value']?.toString() ?? '';

    setState(() {
      _selectedCourse = course;
      _classSections = [];
      _selectedSlot = 'All';
      _isLoadingSections = true;
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
      _showMessage(
        ErrorFormatter.format(
          e,
          fallback: 'Unable to load course faculties. Please try again.',
        ),
        color: _red,
      );
    }
  }

  void _openLecturesPage(dynamic section) {
    final erpId = section['erp_id']?.toString() ?? '';
    final classId =
        section['class_id']?.toString() ??
        (_selectedCourse?['value']?.toString() ?? '');
    final faculty = section['faculty']?.toString() ?? 'Faculty';
    final slot = section['slot']?.toString() ?? '';
    final courseCode =
        section['course_code']?.toString() ??
        _selectedCourse?['course_code']?.toString() ??
        '';
    final courseType =
        section['course_type']?.toString() ??
        _selectedCourse?['course_type']?.toString() ??
        '';
    final courseTitle =
        section['course_title']?.toString() ??
        _selectedCourse?['course_title']?.toString() ??
        _formatCourseDisplayTitle(_selectedCourse ?? {});

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CourseLecturesScreen(
          courseTitle: courseTitle,
          courseCode: courseCode,
          courseType: courseType,
          slot: slot,
          faculty: faculty,
          erpId: erpId,
          classId: classId,
        ),
      ),
    );
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

  /// Extracts unique base slots modeled after vitap_student_app_ref/course_page.dart
  List<String> _extractUniqueSlots(List<dynamic> entries) {
    final slotSet = <String>{};
    for (final entry in entries) {
      final rawSlot = (entry['slot']?.toString() ?? '').trim();
      if (rawSlot.isEmpty) continue;
      final parts = rawSlot.split('+');
      for (final part in parts) {
        final cleaned = part.trim().replaceAll(RegExp(r'^T'), '');
        if (cleaned.isNotEmpty) {
          slotSet.add(cleaned);
        }
      }
    }

    final sortedSlots = slotSet.toList()
      ..sort((a, b) {
        final regex = RegExp(r'^([A-Z]+)(\d+)$');
        final matchA = regex.firstMatch(a);
        final matchB = regex.firstMatch(b);

        if (matchA != null && matchB != null) {
          final prefixCompare = matchA.group(1)!.compareTo(matchB.group(1)!);
          if (prefixCompare != 0) return prefixCompare;
          return int.parse(
            matchA.group(2)!,
          ).compareTo(int.parse(matchB.group(2)!));
        }
        return a.compareTo(b);
      });

    return ['All', ...sortedSlots];
  }

  String _formatCourseDisplayTitle(Map<String, dynamic> course) {
    final title = (course['course_title']?.toString() ?? '').trim();
    final type = (course['course_type']?.toString() ?? '').trim();
    final label = (course['label']?.toString() ?? '').trim();

    if (title.isNotEmpty && type.isNotEmpty) {
      return '$title - ${_getCourseTypeLabel(type)}';
    } else if (title.isNotEmpty) {
      return title;
    } else if (label.isNotEmpty) {
      return label;
    }
    return 'Choose a course';
  }

  Future<void> _onRefresh() async {
    try {
      final fresh = await _getCoursesData(forceRefresh: true);
      if (mounted && fresh.isNotEmpty) {
        setState(() => _cachedData = fresh);
      }
      if (_selectedCourse != null) {
        await _selectCourse(_selectedCourse!);
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
            future: _coursesFuture,
            builder: (context, snapshot) {
              final data = _cachedData ?? snapshot.data;
              if (data != null && data.isNotEmpty) {
                return _buildCoursesContent(data);
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoading();
              }

              if (snapshot.hasError) {
                return _buildError(
                  ErrorFormatter.format(
                    snapshot.error,
                    fallback:
                        'Unable to load registered courses. Please check your connection and try again.',
                  ),
                );
              }

              return _buildCoursesContent(data ?? {});
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCoursesContent(Map<String, dynamic> data) {
    final courses = (data['courses'] as List<dynamic>?) ?? [];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _buildHeader(),
        const SizedBox(height: 16),

        // Course Selector Box (modeled after vitap_student_app_ref/course_page.dart)
        _buildCourseSelectorBox(courses),
        const SizedBox(height: 16),

        if (_selectedCourse == null)
          _buildInitialEmptyState()
        else ...[
          if (_isLoadingSections)
            _buildSectionsLoading()
          else ...[
            if (_classSections.isNotEmpty) ...[
              _buildSlotFilterBar(),
              const SizedBox(height: 18),
            ],
            _buildFacultySectionHeader(),
            const SizedBox(height: 12),
            _buildFacultyList(),
          ],
        ],
      ],
    );
  }

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildHeader() {
    return NexusAppBar(
      title: 'Courses',
      subtitle: 'Faculty, lectures and materials',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => setState(() => _loadCourses(forceRefresh: true)),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  // ============================================================
  // TOP COURSE SELECTOR BOX
  // ============================================================
  Widget _buildCourseSelectorBox(List<dynamic> courses) {
    final isSelected = _selectedCourse != null;
    final displayTitle = isSelected
        ? _formatCourseDisplayTitle(_selectedCourse!)
        : 'Choose a course';
    final hsl = HSLColor.fromColor(_navy);
    final top = hsl.withLightness(hsl.lightness.clamp(0.0, 0.42)).withSaturation(hsl.saturation.clamp(0.5, 1.0)).toColor();
    final bottom = Color.lerp(top, const Color(0xFF16102E), 0.7)!;

    return GestureDetector(
      onTap: () => _openCoursePickerBottomSheet(courses),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [top, bottom]),
          boxShadow: [BoxShadow(color: top.withValues(alpha: 0.3), blurRadius: 22, offset: const Offset(0, 10))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSelected ? 'COURSE' : 'START HERE',
                    style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayTitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.bricolageGrotesque(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white, height: 1.12, letterSpacing: -0.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.unfold_more_rounded, color: Colors.white, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY INITIAL STATE
  // ============================================================
  Widget _buildInitialEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80, horizontal: 20),
      child: NexusEmptyState(
        title: 'Select a course',
        description: 'Choose a course from the dropdown above',
        icon: Icons.school_outlined,
      ),
    );
  }

  // ============================================================
  // COURSE PICKER BOTTOM SHEET
  // ============================================================
  void _openCoursePickerBottomSheet(List<dynamic> courses) {
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = courses.where((c) {
              final q = searchQuery.trim().toLowerCase();
              if (q.isEmpty) return true;
              final code = (c['course_code'] ?? '').toString().toLowerCase();
              final title =
                  (c['course_title'] ?? c['label'] ?? '')
                      .toString()
                      .toLowerCase();
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
                    Row(
                      children: [
                        Text(
                          'Select Course',
                          style: GoogleFonts.dmSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _soft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${courses.length} COURSES',
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: _navy,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _soft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _line),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, size: 18, color: _muted),
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
                                hintText: 'Search course code or title...',
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
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No matching courses found',
                                style: GoogleFonts.dmSans(
                                  color: _muted,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  Divider(height: 1, color: _line),
                              itemBuilder: (context, index) {
                                final course =
                                    Map<String, dynamic>.from(
                                      filtered[index] as Map,
                                    );
                                final isChosen =
                                    _selectedCourse?['value'] ==
                                    course['value'];
                                final title = _formatCourseDisplayTitle(course);
                                final code =
                                    course['course_code']?.toString() ?? '';

                                return InkWell(
                                  onTap: () {
                                    Navigator.of(modalCtx).pop();
                                    _selectCourse(course);
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (code.isNotEmpty)
                                                Text(
                                                  code.toUpperCase(),
                                                  style:
                                                      GoogleFonts.bricolageGrotesque(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: _blue,
                                                        letterSpacing: 0.5,
                                                      ),
                                                ),
                                              const SizedBox(height: 2),
                                              Text(
                                                title,
                                                style: GoogleFonts.dmSans(
                                                  fontSize: 14.5,
                                                  fontWeight: isChosen
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                  color: isChosen
                                                      ? _blue
                                                      : _ink,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isChosen)
                                          Icon(
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
  // BASE SLOT FILTER BAR (modeled after vitap_student_app_ref/course_page.dart)
  // ============================================================
  Widget _buildSlotFilterBar() {
    final allSlots = _extractUniqueSlots(_classSections);

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: allSlots.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final slot = allSlots[index];
          final isSelected = _selectedSlot == slot;

          return NexusFilterChip(
            label: slot,
            isSelected: isSelected,
            onTap: () => setState(() => _selectedSlot = slot),
          );
        },
      ),
    );
  }

  List<dynamic> _getFilteredFaculties() {
    if (_selectedSlot == 'All') {
      return _classSections;
    }
    return _classSections
        .where((s) => (s['slot']?.toString() ?? '').contains(_selectedSlot))
        .toList();
  }

  // ============================================================
  // FACULTY SECTION HEADER
  // ============================================================
  Widget _buildFacultySectionHeader() {
    return Text(
      'Pick a faculty',
      style: GoogleFonts.bricolageGrotesque(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: _ink,
        letterSpacing: -0.5,
      ),
    );
  }

  // ============================================================
  // FACULTY LIST CARDS
  // ============================================================
  Widget _buildFacultyList() {
    final filtered = _getFilteredFaculties();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: NexusEmptyState(
          title: 'No faculty sections found',
          description: _selectedSlot == 'All'
              ? 'No class sections available for this course.'
              : 'No faculty sections found for slot "$_selectedSlot".',
          icon: Icons.inbox_outlined,
        ),
      );
    }

    const tints = [
      Color(0xFF6C7CFF), Color(0xFF14B8A6), Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFF22C55E), Color(0xFF8B5CF6),
    ];

    return Column(
      children: filtered.asMap().entries.map((entry) {
        final index = entry.key;
        final section = entry.value;
        final rawFaculty = section['faculty']?.toString() ?? 'Faculty';
        final facultyName = _extractFacultyName(rawFaculty);
        final courseCode =
            section['course_code']?.toString() ??
            _selectedCourse?['course_code']?.toString() ??
            '';
        final slot = section['slot']?.toString() ?? '';
        final tint = tints[index % tints.length];
        final initial = facultyName.trim().isEmpty ? '?' : facultyName.trim()[0].toUpperCase();

        return AnimeStaggerItem(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => _openLecturesPage(section),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: _line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: tint.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(18)),
                      alignment: Alignment.center,
                      child: Text(initial, style: GoogleFonts.bricolageGrotesque(fontSize: 22, fontWeight: FontWeight.w800, color: tint)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            facultyName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.bricolageGrotesque(fontSize: 16.5, fontWeight: FontWeight.w800, color: _ink, height: 1.12, letterSpacing: -0.2),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (slot.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                  decoration: BoxDecoration(color: tint.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                                  child: Text(slot, style: GoogleFonts.dmSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: tint)),
                                ),
                              if (courseCode.isNotEmpty)
                                Text(courseCode, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _inkSoft)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: _inkSoft, size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
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
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _navy),
          ),
          const SizedBox(height: 14),
          Text(
            'Loading course page...',
            style: GoogleFonts.dmSans(color: _muted, fontSize: 13),
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
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: _navy),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading faculty sections...',
            style: GoogleFonts.dmSans(color: _muted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildError(dynamic error) {
    final cleanMessage = ErrorFormatter.format(
      error,
      fallback: 'Unable to load courses right now. Pull down or tap retry.',
    );

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _loadCourses(forceRefresh: true));
      },
      color: _blue,
      backgroundColor: _surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: _red,
                    size: 28,
                  ),
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
                const SizedBox(height: 8),
                Text(
                  cleanMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    color: _muted,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () =>
                      setState(() => _loadCourses(forceRefresh: true)),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: _palette.isDark
                        ? const Color(0xFF0F172A)
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
}

// ============================================================================
// DEDICATED LECTURES SCREEN (Modeled after vitap_student_app_ref/lectures_page.dart)
// ============================================================================
class CourseLecturesScreen extends ConsumerStatefulWidget {
  final String courseTitle;
  final String courseCode;
  final String courseType;
  final String slot;
  final String faculty;
  final String erpId;
  final String classId;

  const CourseLecturesScreen({
    super.key,
    required this.courseTitle,
    required this.courseCode,
    required this.courseType,
    required this.slot,
    required this.faculty,
    required this.erpId,
    required this.classId,
  });

  @override
  ConsumerState<CourseLecturesScreen> createState() =>
      _CourseLecturesScreenState();
}

class _CourseLecturesScreenState extends ConsumerState<CourseLecturesScreen> {
  Map<String, dynamic>? _courseDetail;
  bool _isLoading = true;
  String? _errorMessage;

  // Tracks which material/action is currently downloading or opening:
  // e.g. 'view_syllabus', 'dl_syllabus', 'dl_all', 'view_<path>', 'dl_<path>'
  String? _busyKey;

  AppPalette get _palette => AppPalette.of(context);
  Color get _paper => _palette.paper;
  Color get _surface => _palette.surface;
  Color get _ink => _palette.ink;
  Color get _navy => _palette.navy;
  Color get _blue => _palette.blue;
  Color get _green => _palette.green;
  Color get _red => _palette.red;
  Color get _muted => _palette.inkMuted;
  Color get _line => _palette.line;
  Color get _soft => _palette.soft;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    final auth = ref.read(authProvider);
    final creds = await StorageService.getCredentials();
    final username = auth.username ?? creds['username'] ?? '';
    final password = auth.password ?? creds['password'] ?? '';
    final semId = auth.activeSemesterId ?? creds['semesterId'] ?? '';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail = await apiService.fetchCourseDetail(
        username: username,
        password: password,
        semSubId: semId,
        erpId: widget.erpId,
        classId: widget.classId,
      );

      if (!mounted) return;
      setState(() {
        _courseDetail = detail;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ErrorFormatter.format(
          e,
          fallback: 'Unable to load lectures and materials. Please try again.',
        );
        _isLoading = false;
      });
    }
  }

  /// Resolves authentic file extension based on magic bytes and fallback filename
  String _resolveFileNameWithMagicBytes(
    List<int> bytes,
    String desiredName, {
    String defaultExt = 'pdf',
  }) {
    String cleanName = desiredName.trim().isNotEmpty
        ? desiredName.trim()
        : 'material.$defaultExt';

    if (bytes.length >= 4) {
      if (bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46) {
        // %PDF
        final base = cleanName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
        return '$base.pdf';
      } else if (bytes[0] == 0x50 &&
          bytes[1] == 0x4B &&
          bytes[2] == 0x03 &&
          bytes[3] == 0x04) {
        // PK.. (ZIP or Office Open XML .docx / .pptx / .xlsx)
        final lower = cleanName.toLowerCase();
        if (lower.endsWith('.docx') ||
            lower.endsWith('.pptx') ||
            lower.endsWith('.xlsx') ||
            lower.endsWith('.zip')) {
          return cleanName;
        }
        final base = cleanName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
        return '$base.$defaultExt';
      }
    }

    if (!cleanName.contains('.')) {
      return '$cleanName.$defaultExt';
    }
    return cleanName;
  }

  Future<void> _handleMaterialAction({
    required String key,
    required String downloadPath,
    required String suggestedFileName,
    required bool openOnly,
    String defaultExt = 'pdf',
  }) async {
    if (downloadPath.isEmpty || _busyKey != null) return;

    final auth = ref.read(authProvider);
    final creds = await StorageService.getCredentials();
    final username = auth.username ?? creds['username'] ?? '';
    final password = auth.password ?? creds['password'] ?? '';

    setState(() => _busyKey = key);
    try {
      final bytes = await apiService.downloadCourseMaterial(
        username: username,
        password: password,
        downloadPath: downloadPath,
      );

      if (!mounted) return;

      if (bytes.isEmpty) {
        throw Exception(
          'The requested material file is empty or unavailable on VTOP.',
        );
      }

      if (bytes.length < 1000) {
        final text = String.fromCharCodes(bytes);
        if (text.contains('<html') ||
            text.contains('<!DOCTYPE') ||
            text.contains('Session expired') ||
            text.contains('Invalid session')) {
          throw Exception(
            'VTOP session expired or file not reachable. Please refresh and try again.',
          );
        }
      }

      final resolvedName = _resolveFileNameWithMagicBytes(
        bytes,
        suggestedFileName,
        defaultExt: defaultExt,
      );
      final sanitizedName = resolvedName.replaceAll(
        RegExp(r'[\\/:*?"<>|]'),
        '_',
      );

      if (openOnly) {
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/$sanitizedName';
        final file = File(tempPath);
        await file.writeAsBytes(bytes, flush: true);
        if (mounted) {
          setState(() => _busyKey = null);
        }
        await DownloadHelper.openFile(tempPath);
      } else {
        final ext = sanitizedName.contains('.')
            ? sanitizedName.split('.').last.toLowerCase()
            : defaultExt;
        final mimeType = ext == 'zip'
            ? 'application/zip'
            : (ext == 'pdf'
                  ? 'application/pdf'
                  : 'application/octet-stream');

        if (mounted) {
          setState(() => _busyKey = null);
        }
        if (!mounted) return;
        await DownloadHelper.saveFile(
          context: context,
          fileName: sanitizedName,
          content: bytes,
          mimeType: mimeType,
          openImmediately: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyKey = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(
            ErrorFormatter.format(
              e,
              fallback: 'Unable to download material. Please try again.',
            ),
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final syllabusPath =
        _courseDetail?['syllabus_download_path']?.toString() ?? '';
    final downloadAllPath =
        _courseDetail?['download_all_path']?.toString() ??
        _courseDetail?['download_general_materials_path']?.toString() ??
        '';
    final lectures = (_courseDetail?['lectures'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: _paper,
      appBar: NexusAppBar(
        title: widget.courseTitle,
        subtitle: 'Course page',
        actions: [
          IconButton(
            onPressed: _fetchDetail,
            icon: Icon(Icons.refresh_rounded, color: _navy, size: 20),
          ),
        ],
      ),
      body: Column(
        children: [
          // Course Info Header + DownloadActionsRow (modeled after lectures_page.dart)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              border: Border(
                top: BorderSide(color: _line),
                bottom: BorderSide(color: _line),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _extractFacultyName(widget.faculty),
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.courseCode.isNotEmpty)
                      _buildInfoChip(widget.courseCode, _blue),
                    if (widget.courseType.isNotEmpty)
                      _buildInfoChip(widget.courseType, _palette.orange),
                    if (widget.slot.isNotEmpty)
                      _buildInfoChip(widget.slot, _green),
                  ],
                ),
                if (syllabusPath.isNotEmpty || downloadAllPath.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildDownloadActionsRow(
                    syllabusPath: syllabusPath,
                    downloadAllPath: downloadAllPath,
                  ),
                ],
              ],
            ),
          ),

          // Lectures List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _navy,
                    ),
                  )
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 42,
                            color: _red,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 13.5,
                              color: _muted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _fetchDetail,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Retry'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _navy,
                              foregroundColor: _palette.isDark
                                  ? const Color(0xFF0F172A)
                                  : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : lectures.isEmpty
                ? const Center(
                    child: NexusEmptyState(
                      title: 'No lectures found',
                      description:
                          'No lecture sessions or reference materials uploaded yet.',
                      icon: Icons.event_note_outlined,
                    ),
                  )
                : RefreshIndicator(
                    color: _blue,
                    backgroundColor: _surface,
                    onRefresh: _fetchDetail,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.all(16),
                      itemCount: lectures.length,
                      itemBuilder: (context, index) {
                        final lecture = lectures[index];
                        return AnimeStaggerItem(
                          index: index,
                          child: _buildLectureCard(lecture),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.bricolageGrotesque(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  /// DownloadActionsRow modeled after vitap_student_app_ref/download_actions_row.dart
  Widget _buildDownloadActionsRow({
    required String syllabusPath,
    required String downloadAllPath,
  }) {
    final isViewingSyllabus = _busyKey == 'view_syllabus';
    final isDownloadingSyllabus = _busyKey == 'dl_syllabus';
    final isDownloadingAll = _busyKey == 'dl_all';
    final isAnyBusy = _busyKey != null;

    return Column(
      children: [
        if (syllabusPath.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: _buildHeaderActionButton(
                  icon: Icons.visibility_outlined,
                  label: 'View Syllabus',
                  isLoading: isViewingSyllabus,
                  isDisabled: isAnyBusy,
                  onPressed: () => _handleMaterialAction(
                    key: 'view_syllabus',
                    downloadPath: syllabusPath,
                    suggestedFileName: '${widget.courseCode}_syllabus.docx',
                    openOnly: true,
                    defaultExt: 'docx',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildHeaderActionButton(
                  icon: Icons.download_rounded,
                  label: 'Syllabus',
                  isLoading: isDownloadingSyllabus,
                  isDisabled: isAnyBusy,
                  onPressed: () => _handleMaterialAction(
                    key: 'dl_syllabus',
                    downloadPath: syllabusPath,
                    suggestedFileName: '${widget.courseCode}_syllabus.docx',
                    openOnly: false,
                    defaultExt: 'docx',
                  ),
                ),
              ),
            ],
          ),
        if (syllabusPath.isNotEmpty && downloadAllPath.isNotEmpty)
          const SizedBox(height: 8),
        if (downloadAllPath.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: _buildHeaderActionButton(
              icon: Icons.folder_zip_outlined,
              label: 'Download All',
              isLoading: isDownloadingAll,
              isDisabled: isAnyBusy,
              onPressed: () => _handleMaterialAction(
                key: 'dl_all',
                downloadPath: downloadAllPath,
                suggestedFileName: '${widget.courseCode}_all_materials.zip',
                openOnly: false,
                defaultExt: 'zip',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String label,
    required bool isLoading,
    required bool isDisabled,
    required VoidCallback onPressed,
  }) {
    final fg = _palette.isDark ? const Color(0xFF0F172A) : Colors.white;
    return FilledButton.tonal(
      onPressed: isDisabled ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _navy,
        foregroundColor: fg,
        disabledBackgroundColor: _soft,
        disabledForegroundColor: _muted,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            )
          else
            Icon(icon, size: 17),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// LectureCard modeled after vitap_student_app_ref/lecture_card.dart
  Widget _buildLectureCard(dynamic lec) {
    final slNo = lec['sl_no']?.toString() ?? '';
    final formattedDate =
        (lec['formatted_date'] ?? lec['date'] ?? lec['class_date'] ?? '')
            .toString();
    final rawDate = (lec['date'] ?? formattedDate).toString().replaceAll(
      '-',
      '_',
    );
    final day = (lec['day'] ?? '').toString();
    final topic = (lec['topic'] ?? '').toString().trim();

    final rawMaterials = lec['reference_materials'] ?? lec['materials'] ?? [];
    final List<dynamic> materials = rawMaterials is List ? rawMaterials : [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Date + Day on left, Material Count Badge on right
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (day.isNotEmpty)
                      Text(
                        day,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _muted,
                        ),
                      ),
                  ],
                ),
              ),
              if (materials.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 14,
                        color: _blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${materials.length}',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _blue,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Topic
          Text(
            topic.isEmpty ? 'No topic specified' : topic,
            style: GoogleFonts.dmSans(
              fontSize: 14.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: topic.isEmpty ? _muted : _ink,
              fontStyle: topic.isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),

          // Reference Materials Rows (each with View & Download buttons)
          if (materials.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: _line),
            const SizedBox(height: 10),
            ...materials.asMap().entries.map((entry) {
              final idx = entry.key;
              final m = entry.value;
              final label =
                  (m['label'] ??
                          m['material_title'] ??
                          m['title'] ??
                          'Reference Material ${idx + 1}')
                      .toString();
              final downloadPath = (m['download_path'] ?? '').toString();
              if (downloadPath.isEmpty) return const SizedBox.shrink();

              final viewKey = 'view_$downloadPath';
              final dlKey = 'dl_$downloadPath';
              final isThisBusy = _busyKey == viewKey || _busyKey == dlKey;
              final isAnyBusy = _busyKey != null;

              final sanitizedLabel = label.replaceAll(' ', '_');
              final filename =
                  '${widget.courseCode}_lecture_${slNo}_${rawDate}_$sanitizedLabel.pdf';

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: isThisBusy
                          ? Padding(
                              padding: const EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _blue,
                              ),
                            )
                          : Icon(
                              Icons.insert_drive_file_outlined,
                              size: 16,
                              color: _blue,
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildSmallActionButton(
                      icon: Icons.visibility_outlined,
                      tooltip: 'View',
                      onTap: isAnyBusy
                          ? null
                          : () => _handleMaterialAction(
                              key: viewKey,
                              downloadPath: downloadPath,
                              suggestedFileName: filename,
                              openOnly: true,
                            ),
                    ),
                    const SizedBox(width: 6),
                    _buildSmallActionButton(
                      icon: Icons.download_rounded,
                      tooltip: 'Download',
                      onTap: isAnyBusy
                          ? null
                          : () => _handleMaterialAction(
                              key: dlKey,
                              downloadPath: downloadPath,
                              suggestedFileName: filename,
                              openOnly: false,
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

  Widget _buildSmallActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDisabled ? _soft : _blue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isDisabled ? _muted : _blue,
          ),
        ),
      ),
    );
  }
}
