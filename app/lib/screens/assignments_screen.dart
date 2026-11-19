import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../widgets/nexus_app_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_formatter.dart';
import '../widgets/shadcn/shadcn_ui.dart';
import '../widgets/motion/nexus_motion.dart';

// ============================================================================
// DIGITAL ASSIGNMENTS SCREEN (REDESIGNED FOR NEXUS)
// ============================================================================

class AssignmentsScreen extends ConsumerStatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  ConsumerState<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends ConsumerState<AssignmentsScreen> {
  late Future<List<dynamic>> _assignmentsFuture;
  List<dynamic>? _cachedAssignments;
  String _selectedFilter = 'All'; // 'All', 'Pending', 'Submitted'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedCourses = {};
  final Map<String, List<dynamic>> _courseAssignmentsCache = {};
  final Set<String> _loadingCourses = {};
  final Set<String> _uploadingKeys = {};
  final Set<String> _downloadingKeys = {};

  static const int _maxUploadSizeBytes = 4 * 1024 * 1024;
  static const List<String> _allowedExtensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final mem = StorageService.getMemoryCache('assignments');
    if (mem is List && mem.isNotEmpty) {
      _cachedAssignments = List<dynamic>.from(mem);
      _prefillCourseCaches(_cachedAssignments!);
    }
    _loadAssignments();
  }

  void _loadAssignments({bool forceRefresh = false}) {
    _assignmentsFuture = _getAssignmentsData(forceRefresh: forceRefresh).then((data) {
      if (mounted && data.isNotEmpty) {
        setState(() => _cachedAssignments = data);
      }
      return data;
    });
  }

  Future<List<dynamic>> _getAssignmentsData({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final mem = StorageService.getMemoryCache('assignments');
      if (mem is List && mem.isNotEmpty) {
        _prefillCourseCaches(mem);
        return List<dynamic>.from(mem);
      }
      final disk = await StorageService.getCache('assignments');
      if (disk is List && disk.isNotEmpty) {
        _prefillCourseCaches(disk);
        return List<dynamic>.from(disk);
      }
    }

    final auth = ref.read(authProvider);
    final creds = await StorageService.getCredentials();
    final username = auth.username ?? creds['username'] ?? '';
    final password = auth.password ?? creds['password'] ?? '';
    final semId = auth.activeSemesterId ?? creds['semesterId'] ?? '';

    try {
      final fresh = await apiService.fetchDigitalAssignments(
        username: username,
        password: password,
        semSubId: semId,
      );
      if (fresh.isNotEmpty) {
        await StorageService.setCache('assignments', fresh);
        _prefillCourseCaches(fresh);
        return fresh;
      }
    } catch (e) {
      debugPrint('AssignmentsScreen: Network fetch failed ($e). Checking offline cache...');
      final fallback = StorageService.getMemoryCache('assignments') ??
          await StorageService.getCache('assignments');
      if (fallback is List && fallback.isNotEmpty) {
        _prefillCourseCaches(fallback);
        return List<dynamic>.from(fallback);
      }
      rethrow;
    }

    final fallback = StorageService.getMemoryCache('assignments') ??
        await StorageService.getCache('assignments');
    if (fallback is List && fallback.isNotEmpty) {
      _prefillCourseCaches(fallback);
      return List<dynamic>.from(fallback);
    }
    return [];
  }

  void _prefillCourseCaches(List<dynamic> courses) {
    for (final c in courses) {
      if (c is Map) {
        final classId = c['class_id']?.toString() ?? '';
        final details = c['details'];
        if (classId.isNotEmpty && details is List && details.isNotEmpty) {
          _courseAssignmentsCache[classId] = details;
        }
      }
    }
  }

  Future<void> _fetchDetailsForCourse(String classId) async {
    if (_courseAssignmentsCache.containsKey(classId) || _loadingCourses.contains(classId)) {
      return;
    }

    final auth = ref.read(authProvider);
    final creds = await StorageService.getCredentials();
    final username = auth.username ?? creds['username'] ?? '';
    final password = auth.password ?? creds['password'] ?? '';

    setState(() => _loadingCourses.add(classId));

    try {
      final details = await apiService.fetchCourseAssignments(
        username: username,
        password: password,
        classId: classId,
      );

      if (!mounted) return;
      setState(() {
        _courseAssignmentsCache[classId] = details;
        _loadingCourses.remove(classId);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCourses.remove(classId));
    }
  }

  bool _isSubmitted(String status) {
    final s = status.toLowerCase();
    return s.contains('submitted') || s.contains('uploaded') || s.contains('completed') || s.contains('yes');
  }

  DateTime? _parseDueDate(String dueDateStr) {
    if (dueDateStr.trim().isEmpty || dueDateStr == '-') return null;
    try {
      // VTOP format: "15-Oct-2026 23:59:00" or "15-10-2026" or "15-Oct-2026"
      final clean = dueDateStr.trim();
      final formats = [
        'dd-MMM-yyyy HH:mm:ss',
        'dd-MMM-yyyy',
        'dd-MM-yyyy HH:mm:ss',
        'dd-MM-yyyy',
        'yyyy-MM-dd HH:mm:ss',
        'yyyy-MM-dd',
      ];
      for (final fmt in formats) {
        try {
          return DateFormat(fmt).parse(clean);
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  String _formatDueDateDisplay(String rawDate) {
    final dt = _parseDueDate(rawDate);
    if (dt == null) return rawDate.isNotEmpty ? rawDate : 'No due date set';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  Map<String, dynamic> _getDueDateStatus(String rawDate, bool isSubmitted, AppPalette palette) {
    if (isSubmitted) {
      return {
        'label': 'SUBMITTED',
        'color': palette.green,
        'icon': Icons.check_circle_rounded,
      };
    }

    final dt = _parseDueDate(rawDate);
    if (dt == null) {
      return {
        'label': 'PENDING',
        'color': palette.orange,
        'icon': Icons.hourglass_empty_rounded,
      };
    }

    final now = DateTime.now();
    final diff = dt.difference(now);

    if (diff.isNegative) {
      return {
        'label': 'OVERDUE',
        'color': palette.red,
        'icon': Icons.error_outline_rounded,
      };
    } else if (diff.inDays == 0) {
      return {
        'label': 'DUE TODAY',
        'color': palette.red,
        'icon': Icons.timer_rounded,
      };
    } else if (diff.inDays == 1) {
      return {
        'label': 'DUE TOMORROW',
        'color': palette.orange,
        'icon': Icons.alarm_rounded,
      };
    } else {
      return {
        'label': 'DUE IN ${diff.inDays} DAYS',
        'color': palette.blue,
        'icon': Icons.calendar_today_rounded,
      };
    }
  }

  Future<void> _onRefresh(Color snackbarBg) async {
    try {
      final fresh = await _getAssignmentsData(forceRefresh: true);
      if (mounted && fresh.isNotEmpty) {
        setState(() => _cachedAssignments = fresh);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No internet connection. Showing saved data.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: snackbarBg,
        ),
      );
    }
  }

  // ==========================================================================
  // BUILD METHOD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: NexusAppBar(
        title: 'Assignments',
        subtitle: 'Deadlines and submissions',
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, size: 20, color: palette.inkSoft),
            tooltip: 'Refresh Assignments',
            onPressed: () {
              HapticFeedback.selectionClick();
              _onRefresh(palette.navy);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _onRefresh(palette.navy),
        color: palette.blue,
        backgroundColor: palette.surface,
        child: FutureBuilder<List<dynamic>>(
          future: _assignmentsFuture,
          builder: (context, snapshot) {
            final courses = _cachedAssignments ?? snapshot.data;
            if (courses != null && courses.isNotEmpty) {
              return _buildAssignmentsContent(courses, palette);
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildSkeletonLoading(palette);
            }

            if (snapshot.hasError) {
              return _buildErrorState(palette, snapshot.error);
            }

            return _buildAssignmentsContent(courses ?? [], palette);
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(AppPalette palette, Object? error) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: palette.red.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.error_outline_rounded, size: 44, color: palette.red),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to Load Assignments',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ErrorFormatter.format(
                      error,
                      fallback: 'Unable to load digital assignments. Please check your connection and try again.',
                    ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(fontSize: 12, color: palette.inkMuted, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _loadAssignments(forceRefresh: true),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('RETRY'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildAssignmentsContent(List<dynamic> courses, AppPalette palette) {
    if (courses.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.line),
                      ),
                      child: Icon(Icons.assignment_turned_in_rounded, size: 44, color: palette.blue),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'No Assignments Found',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No digital assignments are registered for the active semester.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(fontSize: 13, color: palette.inkMuted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

          // Compute comprehensive stats
          int totalAssignments = 0;
          int submittedCount = 0;
          int pendingCount = 0;

          for (final c in courses) {
            final classId = c['class_id']?.toString() ?? '';
            final list = _courseAssignmentsCache[classId] ?? (c['details'] as List<dynamic>? ?? []);
            for (final a in list) {
              totalAssignments++;
              if (_isSubmitted(a['submission_status']?.toString() ?? '')) {
                submittedCount++;
              } else {
                pendingCount++;
              }
            }
          }

          // Filter courses based on search and selected filter
          final filteredCourses = courses.where((c) {
            final code = (c['course_code'] ?? '').toString().toLowerCase();
            final title = (c['course_title'] ?? '').toString().toLowerCase();
            final faculty = (c['faculty'] ?? '').toString().toLowerCase();
            final q = _searchQuery.toLowerCase();

            if (q.isNotEmpty && !code.contains(q) && !title.contains(q) && !faculty.contains(q)) {
              return false;
            }

            if (_selectedFilter != 'All') {
              final classId = c['class_id']?.toString() ?? '';
              final list = _courseAssignmentsCache[classId] ?? (c['details'] as List<dynamic>? ?? []);
              if (list.isNotEmpty) {
                if (_selectedFilter == 'Pending') {
                  final hasPending = list.any((a) => !_isSubmitted(a['submission_status']?.toString() ?? ''));
                  if (!hasPending) return false;
                } else if (_selectedFilter == 'Submitted') {
                  final hasSubmitted = list.any((a) => _isSubmitted(a['submission_status']?.toString() ?? ''));
                  if (!hasSubmitted) return false;
                }
              }
            }

            return true;
          }).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. STATS HERO BANNER
        _buildStatsHeroBanner(totalAssignments, submittedCount, pendingCount, palette),
        const SizedBox(height: 12),

        // 1B. UPLOAD GUIDELINES BANNER
        _buildUploadGuidelinesBanner(palette),
        const SizedBox(height: 14),

        // 2. SEARCH & FILTER CHIPS
        _buildSearchAndFilters(palette),
        const SizedBox(height: 16),

        // 3. COURSE ASSIGNMENTS ACCORDION LIST
        ...filteredCourses.asMap().entries.map((entry) => AnimeStaggerItem(
              index: entry.key,
              child: _buildCourseCard(entry.value, palette),
            )),
        const SizedBox(height: 32),
      ],
    );
  }

  // ==========================================================================
  // 1. STATS HERO BANNER
  // ==========================================================================

  Widget _buildStatsHeroBanner(int total, int submitted, int pending, AppPalette palette) {
    final double progress = total > 0 ? (submitted / total).clamp(0.0, 1.0) : 0.0;
    final hsl = HSLColor.fromColor(palette.blue);
    final top = hsl.withLightness(hsl.lightness.clamp(0.0, 0.42)).withSaturation(hsl.saturation.clamp(0.5, 1.0)).toColor();
    final bottom = Color.lerp(top, const Color(0xFF16102E), 0.72)!;

    Widget stat(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                Text(value, style: GoogleFonts.bricolageGrotesque(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
                const SizedBox(height: 3),
                Text(label.toUpperCase(),
                    style: GoogleFonts.dmSans(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: Colors.white70)),
              ],
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [top, bottom]),
        boxShadow: [BoxShadow(color: top.withValues(alpha: 0.3), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: v,
                          strokeWidth: 7,
                          strokeCap: StrokeCap.round,
                          backgroundColor: Colors.white.withValues(alpha: 0.22),
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                      Text('${(v * 100).round()}%',
                          style: GoogleFonts.bricolageGrotesque(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pending == 0 ? 'All caught up' : '$pending to go',
                        style: GoogleFonts.bricolageGrotesque(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, height: 1.05, letterSpacing: -0.5)),
                    Text('$submitted of $total digital assignments submitted',
                        style: GoogleFonts.dmSans(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.8))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              stat(total.toString(), 'Total'),
              const SizedBox(width: 8),
              stat(submitted.toString(), 'Done'),
              const SizedBox(width: 8),
              stat(pending.toString(), 'Pending'),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 2. SEARCH & FILTER CHIPS
  // ==========================================================================

  Widget _buildSearchAndFilters(AppPalette palette) {
    return Column(
      children: [
        // Nexus Search Bar
        NexusSearchBar(
          controller: _searchController,
          hintText: 'Search by course code, title, faculty...',
          onChanged: (val) => setState(() => _searchQuery = val),
          onClear: () {
            _searchController.clear();
            setState(() => _searchQuery = '');
          },
        ),
        const SizedBox(height: 10),

        // Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: ['All', 'Pending', 'Submitted'].map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: NexusFilterChip(
                  label: filter == 'All' ? 'ALL COURSES' : filter.toUpperCase(),
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedFilter = filter),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // 3. COURSE CARD WITH ASSIGNMENT ACCORDION
  // ==========================================================================

  Widget _buildCourseCard(Map<String, dynamic> course, AppPalette palette) {
    final classId = course['class_id']?.toString() ?? '';
    final courseCode = course['course_code']?.toString() ?? '';
    final courseTitle = course['course_title']?.toString() ?? 'Course';
    final courseType = course['course_type']?.toString() ?? '';
    final faculty = course['faculty']?.toString() ?? '';

    final isExpanded = _expandedCourses.contains(classId);
    final isLoadingDetails = _loadingCourses.contains(classId);
    final assignments = _courseAssignmentsCache[classId] ?? (course['details'] as List<dynamic>? ?? []);

    // Count pending vs submitted
    int pendingInCourse = 0;
    for (final a in assignments) {
      if (!_isSubmitted(a['submission_status']?.toString() ?? '')) {
        pendingInCourse++;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isExpanded ? palette.blue.withValues(alpha: 0.3) : palette.line,
          width: isExpanded ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Course Header (Tappable Accordion Header)
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (isExpanded) {
                  _expandedCourses.remove(classId);
                } else {
                  _expandedCourses.add(classId);
                  _fetchDetailsForCourse(classId);
                }
              });
            },
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Course Code Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: palette.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: palette.blue.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          courseType.isNotEmpty ? '$courseCode • $courseType' : courseCode,
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: palette.blue,
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Status Badge
                      if (assignments.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (pendingInCourse > 0 ? palette.orange : palette.green).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: pendingInCourse > 0 ? palette.orange : palette.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                pendingInCourse > 0 ? '$pendingInCourse DUE' : 'ALL DONE',
                                style: GoogleFonts.bricolageGrotesque(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: pendingInCourse > 0 ? palette.orange : palette.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),

                      // Chevron
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: palette.inkSoft,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Course Title
                  Text(
                    courseTitle,
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: palette.ink,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Faculty & Class ID
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 14, color: palette.inkMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          faculty.isNotEmpty ? faculty : 'Faculty not specified',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: palette.inkSoft,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (classId.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          'ID: $classId',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 10,
                            color: palette.inkMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded Assignments Details
          if (isExpanded) ...[
            Divider(height: 1, color: palette.line),
            if (isLoadingDetails)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: palette.blue),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Fetching assignment details...',
                        style: GoogleFonts.dmSans(fontSize: 12, color: palette.inkMuted),
                      ),
                    ],
                  ),
                ),
              )
            else if (assignments.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No individual digital assignments posted for this course.',
                    style: GoogleFonts.dmSans(fontSize: 12, color: palette.inkMuted),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: assignments.map<Widget>((a) {
                    return _buildAssignmentItemCard(course, a, palette);
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // 4. INDIVIDUAL ASSIGNMENT ITEM CARD + UPLOAD / OTP / DOWNLOAD
  // ==========================================================================

  Widget _buildUploadGuidelinesBanner(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: palette.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.cloud_upload_outlined,
              size: 16,
              color: palette.blue,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'VTOP Upload Limit: Max 4 MB • Allowed formats: PDF, DOC, DOCX, XLS, XLSX',
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: palette.inkSoft,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentItemCard(
    Map<String, dynamic> course,
    dynamic assignment,
    AppPalette palette,
  ) {
    final classId = course['class_id']?.toString() ?? '';
    final courseCode = course['course_code']?.toString() ?? 'DA';
    final serialNo = assignment['serial_number']?.toString() ?? '1';
    final title =
        assignment['assignment_title']?.toString() ?? 'Digital Assignment';
    final maxMarks = assignment['max_assignment_mark']?.toString() ?? '-';
    final weightage =
        assignment['assignment_weightage_mark']?.toString() ?? '-';
    final rawDueDate = assignment['due_date']?.toString() ?? '';
    final status =
        assignment['submission_status']?.toString() ?? 'Not Uploaded';
    final mcode = assignment['mcode']?.toString() ?? '';
    final isSub = _isSubmitted(status);
    final canUpdate = assignment['can_update'] == true;
    final canQpDownload = assignment['can_qp_download'] == true;
    final qpUrl = assignment['qp_download_url']?.toString() ?? '';
    final canDaDownload = assignment['can_da_download'] == true;
    final daUrl = assignment['da_download_url']?.toString() ?? '';

    final dueStatus = _getDueDateStatus(rawDueDate, isSub, palette);
    final isOverdue = dueStatus['label'] == 'OVERDUE';
    final canUploadWork =
        mcode.isNotEmpty && (canUpdate || (!isSub && !isOverdue));

    final itemKey = '${classId}_${serialNo}_$mcode';
    final isUploading = _uploadingKeys.contains(itemKey);
    final isDownloadingQp = _downloadingKeys.contains('${itemKey}_qp');
    final isDownloadingDa = _downloadingKeys.contains('${itemKey}_da');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Due Status Chip
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: palette.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Due status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (dueStatus['color'] as Color).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (dueStatus['color'] as Color).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      dueStatus['icon'] as IconData,
                      size: 12,
                      color: dueStatus['color'] as Color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dueStatus['label'] as String,
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: dueStatus['color'] as Color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Marks & Weightage Chips
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (maxMarks != '-')
                _buildInfoPill(
                  'Max Marks: $maxMarks',
                  Icons.grade_rounded,
                  palette,
                ),
              if (weightage != '-')
                _buildInfoPill(
                  'Weight: $weightage%',
                  Icons.pie_chart_outline_rounded,
                  palette,
                ),
              if (status.isNotEmpty && status != '-')
                _buildInfoPill(
                  status,
                  isSub
                      ? Icons.task_alt_rounded
                      : Icons.pending_actions_rounded,
                  palette,
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Due Date String
          Row(
            children: [
              Icon(Icons.event_rounded, size: 14, color: palette.inkMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Due: ${_formatDueDateDisplay(rawDueDate)}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: palette.inkSoft,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          // Action Buttons Row (Question Paper, My Submission, Submit / Update Work)
          if ((canQpDownload && qpUrl.isNotEmpty) ||
              (canDaDownload && daUrl.isNotEmpty) ||
              canUploadWork) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: palette.line),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canQpDownload && qpUrl.isNotEmpty)
                  _buildActionButton(
                    palette: palette,
                    label: isDownloadingQp ? 'Downloading...' : 'Question Paper',
                    icon: Icons.description_outlined,
                    color: palette.blue,
                    isLoading: isDownloadingQp,
                    onTap: isDownloadingQp
                        ? null
                        : () => _handleDownloadFile(
                              key: '${itemKey}_qp',
                              url: qpUrl,
                              baseName: '${courseCode}_QP_$serialNo',
                              palette: palette,
                            ),
                  ),
                if (canDaDownload && daUrl.isNotEmpty)
                  _buildActionButton(
                    palette: palette,
                    label: isDownloadingDa ? 'Downloading...' : 'My Submission',
                    icon: Icons.download_done_rounded,
                    color: palette.green,
                    isLoading: isDownloadingDa,
                    onTap: isDownloadingDa
                        ? null
                        : () => _handleDownloadFile(
                              key: '${itemKey}_da',
                              url: daUrl,
                              baseName: '${courseCode}_DA_$serialNo',
                              palette: palette,
                            ),
                  ),
                if (canUploadWork)
                  _buildActionButton(
                    palette: palette,
                    label: isUploading
                        ? 'Uploading...'
                        : (isSub ? 'Update Work' : 'Submit Work'),
                    icon: isSub
                        ? Icons.edit_document
                        : Icons.upload_file_rounded,
                    color: palette.navy,
                    filled: true,
                    isLoading: isUploading,
                    onTap: isUploading
                        ? null
                        : () => _handleUploadAssignment(
                              itemKey: itemKey,
                              classId: classId,
                              mcode: mcode,
                              assignmentTitle: title,
                              palette: palette,
                            ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required AppPalette palette,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    bool filled = false,
    bool isLoading = false,
  }) {
    return Material(
      color: filled ? color : palette.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: filled ? color : color.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: filled ? palette.onNavy : color,
                  ),
                )
              else
                Icon(
                  icon,
                  size: 14,
                  color: filled ? palette.onNavy : color,
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: filled ? palette.onNavy : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDownloadFile({
    required String key,
    required String url,
    required String baseName,
    required AppPalette palette,
  }) async {
    setState(() => _downloadingKeys.add(key));
    try {
      final auth = ref.read(authProvider);
      final creds = await StorageService.getCredentials();
      final username = auth.username ?? creds['username'] ?? '';
      final password = auth.password ?? creds['password'] ?? '';

      final bytes = await apiService.downloadAssignmentFile(
        username: username,
        password: password,
        downloadUrl: url,
      );

      if (bytes.isEmpty) {
        throw Exception('Empty file returned by VTOP.');
      }

      String ext = 'pdf';
      if (bytes.length >= 4) {
        if (bytes[0] == 0x25 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x44 &&
            bytes[3] == 0x46) {
          ext = 'pdf';
        } else if (bytes[0] == 0x50 && bytes[1] == 0x4B) {
          ext = 'docx';
        } else if (bytes[0] == 0xD0 && bytes[1] == 0xCF) {
          ext = 'doc';
        }
      }

      final dir = await getTemporaryDirectory();
      final sanitized = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final file = File('${dir.path}/$sanitized.$ext');
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      await OpenFilex.open(file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorFormatter.format(
              e,
              fallback: 'Could not download file from VTOP.',
            ),
          ),
          backgroundColor: palette.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _downloadingKeys.remove(key));
      }
    }
  }

  Future<void> _handleUploadAssignment({
    required String itemKey,
    required String classId,
    required String mcode,
    required String assignmentTitle,
    required AppPalette palette,
  }) async {
    try {
      final pickedFile = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
      );
      if (pickedFile == null) return;

      final fileName = pickedFile.name;
      final ext = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : '';
      if (!_allowedExtensions.contains(ext)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unsupported file format (.$ext). Allowed: PDF, DOC, DOCX, XLS, XLSX.',
            ),
            backgroundColor: palette.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final fileBytes = await pickedFile.readAsBytes();
      if (fileBytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Selected file is empty.'),
            backgroundColor: palette.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (fileBytes.length > _maxUploadSizeBytes) {
        final mb = (fileBytes.length / (1024 * 1024)).toStringAsFixed(2);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'File is too large ($mb MB). VTOP maximum allowed size is 4.00 MB.',
            ),
            backgroundColor: palette.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() => _uploadingKeys.add(itemKey));

      final auth = ref.read(authProvider);
      final creds = await StorageService.getCredentials();
      final username = auth.username ?? creds['username'] ?? '';
      final password = auth.password ?? creds['password'] ?? '';

      try {
        await apiService.uploadDigitalAssignment(
          username: username,
          password: password,
          classId: classId,
          mode: mcode,
          fileName: fileName,
          fileBytes: fileBytes,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded "$fileName" for $assignmentTitle!'),
            backgroundColor: palette.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _courseAssignmentsCache.remove(classId);
        await _fetchDetailsForCourse(classId);
        await _onRefresh(palette.navy);
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('DA_OTP_REQUIRED')) {
          if (!mounted) return;
          final verified = await _showDaOtpBottomSheet(
            palette: palette,
            assignmentTitle: assignmentTitle,
            fileName: fileName,
            username: username,
            password: password,
          );
          if (verified && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'OTP verified & "$fileName" updated for $assignmentTitle!',
                ),
                backgroundColor: palette.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
            _courseAssignmentsCache.remove(classId);
            await _fetchDetailsForCourse(classId);
            await _onRefresh(palette.navy);
          }
        } else {
          rethrow;
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorFormatter.format(
              e,
              fallback: 'Failed to upload assignment to VTOP.',
            ),
          ),
          backgroundColor: palette.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingKeys.remove(itemKey));
      }
    }
  }

  Future<bool> _showDaOtpBottomSheet({
    required AppPalette palette,
    required String assignmentTitle,
    required String fileName,
    required String username,
    required String password,
  }) async {
    final otpCtrl = TextEditingController();
    bool isSubmitting = false;
    String? errorText;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Container(
              padding: EdgeInsets.fromLTRB(22, 22, 22, 24 + bottomInset),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(color: palette.line, width: 1.2),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirm Assignment Re-Upload',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'VTOP sent a 6-digit OTP to your university email to confirm overwriting "$assignmentTitle" with "$fileName".',
                      style: GoogleFonts.dmSans(
                        fontSize: 13.5,
                        color: palette.inkSoft,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: otpCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                        color: palette.ink,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '6-DIGIT OTP',
                        hintStyle: GoogleFonts.bricolageGrotesque(
                          fontSize: 13,
                          letterSpacing: 2,
                          color: palette.inkMuted,
                        ),
                        filled: true,
                        fillColor: palette.soft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: palette.line),
                        ),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
                        style: GoogleFonts.dmSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: palette.red,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.of(sheetCtx).pop(false),
                              child: const Text('Cancel'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: FilledButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      final code = otpCtrl.text.trim();
                                      if (code.length < 6) {
                                        setSheetState(
                                          () => errorText =
                                              'Please enter all 6 digits.',
                                        );
                                        return;
                                      }
                                      setSheetState(() {
                                        isSubmitting = true;
                                        errorText = null;
                                      });
                                      try {
                                        await apiService
                                            .uploadDigitalAssignmentWithOtp(
                                              username: username,
                                              password: password,
                                              otpEmail: code,
                                            );
                                        if (sheetCtx.mounted) {
                                          Navigator.of(sheetCtx).pop(true);
                                        }
                                      } catch (err) {
                                        setSheetState(() {
                                          isSubmitting = false;
                                          errorText = ErrorFormatter.format(
                                            err,
                                            fallback:
                                                'Incorrect OTP. Please try again.',
                                          );
                                        });
                                      }
                                    },
                              style: FilledButton.styleFrom(
                                backgroundColor: palette.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Verify & Upload'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    return result == true;
  }

  Widget _buildInfoPill(String text, IconData icon, AppPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: palette.inkMuted),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: palette.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SKELETON LOADING
  // ==========================================================================

  Widget _buildSkeletonLoading(AppPalette palette) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.line),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.line),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(3, (i) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 90,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.line),
            ),
          );
        }),
      ],
    );
  }
}
