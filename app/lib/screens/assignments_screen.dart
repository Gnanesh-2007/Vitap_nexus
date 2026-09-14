import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/mesh_ambient_background.dart';

class AssignmentsScreen extends ConsumerStatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  ConsumerState<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends ConsumerState<AssignmentsScreen> {
  late Future<List<dynamic>> _assignmentsFuture;
  String _selectedFilter = 'All'; // 'All', 'Pending', 'Submitted'
  String _searchQuery = '';
  final Set<String> _expandedCourses = {};
  final Map<String, List<dynamic>> _courseAssignmentsCache = {};
  final Set<String> _loadingCourses = {};
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  void _loadAssignments() {
    final auth = ref.read(authProvider);
    final username = auth.username ?? '';
    final password = auth.password ?? '';
    final semId = auth.activeSemesterId ?? '';

    setState(() {
      _assignmentsFuture = apiService.fetchDigitalAssignments(
        username: username,
        password: password,
        semSubId: semId,
      );
    });
  }

  Future<void> _fetchDetailsForCourse(String classId) async {
    if (_courseAssignmentsCache.containsKey(classId) || _loadingCourses.contains(classId)) {
      return;
    }

    final auth = ref.read(authProvider);
    final username = auth.username ?? '';
    final password = auth.password ?? '';

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

  Future<void> _downloadFile(String downloadUrl, String title, String type) async {
    if (downloadUrl.isEmpty) return;
    final auth = ref.read(authProvider);
    final username = auth.username ?? '';
    final password = auth.password ?? '';

    setState(() => _isDownloading = true);

    try {
      final bytes = await apiService.downloadAssignmentFile(
        username: username,
        password: password,
        downloadUrl: downloadUrl,
      );

      if (!mounted) return;
      setState(() => _isDownloading = false);

      final kb = (bytes.length / 1024).toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Downloaded $type for "$title" ($kb KB)',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Download failed: $e'),
        ),
      );
    }
  }

  bool _isSubmitted(String status) {
    final s = status.toLowerCase();
    return s.contains('submitted') || s.contains('uploaded') || s.contains('completed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Digital Assignments',
          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAssignments,
            tooltip: 'Refresh Assignments',
          ),
        ],
        bottom: _isDownloading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(
                  backgroundColor: AppTheme.surfaceLight,
                  color: AppTheme.primaryAccent,
                  minHeight: 2,
                ),
              )
            : null,
      ),
      body: MeshAmbientBackground(
        child: FutureBuilder<List<dynamic>>(
          future: _assignmentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildSkeletonLoading();
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 54, color: AppTheme.error),
                      const SizedBox(height: 14),
                      Text(
                        'Failed to Load Assignments',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _loadAssignments,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                      ),
                    ],
                  ),
                ),
              );
            }

            final courses = snapshot.data ?? [];

            if (courses.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.assignment_turned_in_rounded, size: 54, color: AppTheme.primaryAccent),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'No Assignments Found',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No digital assignments have been posted for the active semester yet.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8), height: 1.4),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Compute stats
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

            // Filter courses
            final filteredCourses = courses.where((c) {
              final code = (c['course_code'] ?? '').toString().toLowerCase();
              final title = (c['course_title'] ?? '').toString().toLowerCase();
              final faculty = (c['faculty'] ?? '').toString().toLowerCase();
              final q = _searchQuery.toLowerCase();
              if (q.isNotEmpty && !code.contains(q) && !title.contains(q) && !faculty.contains(q)) {
                return false;
              }
              return true;
            }).toList();

            return RefreshIndicator(
              onRefresh: () async => _loadAssignments(),
              color: AppTheme.primaryAccent,
              backgroundColor: AppTheme.surface,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                children: [
                  // Top Summary Card
                  _buildSummaryHeader(totalAssignments, submittedCount, pendingCount)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: -0.08, end: 0, curve: Curves.easeOutCubic),
                  const SizedBox(height: 18),

                  // Search Bar
                  _buildSearchBar()
                      .animate()
                      .fadeIn(duration: 350.ms, delay: 60.ms),
                  const SizedBox(height: 14),

                  // Filter Chips (All / Pending / Submitted)
                  _buildFilterChips()
                      .animate()
                      .fadeIn(duration: 350.ms, delay: 100.ms),
                  const SizedBox(height: 16),

                  // Course List with assignments
                  ...filteredCourses.asMap().entries.map((entry) {
                    final index = entry.key;
                    final course = entry.value;
                    return _buildCourseCard(course)
                        .animate(delay: (40 * index).ms)
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
                  }),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.cardBorder),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.cardBorder),
          ),
        ),
        const SizedBox(height: 20),
        ...List.generate(
          3,
          (i) => Container(
            margin: const EdgeInsets.only(bottom: 14),
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
          ),
        ),
      ],
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08));
  }

  Widget _buildSummaryHeader(int total, int submitted, int pending) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_rounded, color: Color(0xFF818CF8), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assignments Dashboard',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Fall Semester 2026-27',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _buildStatItem('Total', total.toString(), const Color(0xFF60A5FA))),
              Container(width: 1, height: 32, color: const Color(0xFF334155)),
              Expanded(child: _buildStatItem('Submitted', submitted.toString(), const Color(0xFF10B981))),
              Container(width: 1, height: 32, color: const Color(0xFF334155)),
              Expanded(child: _buildStatItem('Pending', pending.toString(), const Color(0xFFF59E0B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF24344D)),
      ),
      child: TextField(
        style: const TextStyle(color: Colors.white, fontSize: 13),
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Search course code, title, or faculty...',
          hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.white54),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Row(
      children: ['All', 'Pending', 'Submitted'].map((filter) {
        final isSelected = _selectedFilter == filter;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(filter),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) setState(() => _selectedFilter = filter);
            },
            backgroundColor: AppTheme.surface,
            selectedColor: AppTheme.primaryAccent.withValues(alpha: 0.25),
            labelStyle: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppTheme.cyanAccent : const Color(0xFF94A3B8),
            ),
            side: BorderSide(
              color: isSelected ? AppTheme.cyanAccent : const Color(0xFF24344D),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCourseCard(dynamic course) {
    final classId = course['class_id']?.toString() ?? '';
    final code = course['course_code']?.toString() ?? '';
    final title = course['course_title']?.toString() ?? '';
    final type = course['course_type']?.toString() ?? '';
    final faculty = course['faculty']?.toString() ?? '';

    final isExpanded = _expandedCourses.contains(classId) || _expandedCourses.isEmpty;
    final isLoading = _loadingCourses.contains(classId);

    // Get assignment list
    var assignments = _courseAssignmentsCache[classId] ?? (course['details'] as List<dynamic>? ?? []);

    // Apply filter
    if (_selectedFilter == 'Pending') {
      assignments = assignments.where((a) => !_isSubmitted(a['submission_status']?.toString() ?? '')).toList();
    } else if (_selectedFilter == 'Submitted') {
      assignments = assignments.where((a) => _isSubmitted(a['submission_status']?.toString() ?? '')).toList();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF24344D)),
      ),
      child: Column(
        children: [
          // Course Header (Tap to toggle)
          InkWell(
            onTap: () {
              setState(() {
                if (_expandedCourses.contains(classId)) {
                  _expandedCourses.remove(classId);
                } else {
                  _expandedCourses.add(classId);
                  _fetchDetailsForCourse(classId);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      code,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.cyanAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (type.isNotEmpty) ...[
                              Text(
                                type,
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                              ),
                              const Text(' • ', style: TextStyle(color: Colors.white24)),
                            ],
                            Expanded(
                              child: Text(
                                faculty,
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${assignments.length}',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Course Assignments List
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFF1E293B)),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2)),
              )
            else if (assignments.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(
                      'No ${_selectedFilter == 'All' ? '' : _selectedFilter.toLowerCase()} assignments for this course',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: assignments.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _buildAssignmentTile(assignments[index]);
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssignmentTile(dynamic a) {
    final title = a['assignment_title']?.toString() ?? 'Assignment';
    final maxMarks = a['max_assignment_mark']?.toString() ?? '-';
    final weightage = a['assignment_weightage_mark']?.toString() ?? '-';
    final dueDate = a['due_date']?.toString() ?? '';
    final status = a['submission_status']?.toString() ?? 'Not Uploaded';

    final isDone = _isSubmitted(status);

    final canQpDownload = a['can_qp_download'] == true;
    final qpUrl = a['qp_download_url']?.toString() ?? '';

    final canDaDownload = a['can_da_download'] == true;
    final daUrl = a['da_download_url']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone ? const Color(0xFF10B981).withValues(alpha: 0.25) : const Color(0xFF334155),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDone ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDone ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDone ? Icons.check_circle_rounded : Icons.schedule_rounded,
                      size: 11,
                      color: isDone ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isDone ? 'Submitted' : 'Pending',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDone ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Due Date + Marks
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (dueDate.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_outlined, size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      'Due: $dueDate',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.grade_outlined, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(
                    'Max: $maxMarks  •  Weight: $weightage%',
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),

          // Download Buttons (QP / Submitted DA)
          if (canQpDownload || canDaDownload) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (canQpDownload && qpUrl.isNotEmpty) ...[
                  ElevatedButton.icon(
                    onPressed: () => _downloadFile(qpUrl, title, 'Question Paper'),
                    icon: const Icon(Icons.file_download_outlined, size: 14),
                    label: const Text('Question Paper', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: AppTheme.cyanAccent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: Color(0xFF334155)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (canDaDownload && daUrl.isNotEmpty) ...[
                  ElevatedButton.icon(
                    onPressed: () => _downloadFile(daUrl, title, 'Submitted File'),
                    icon: const Icon(Icons.download_done_rounded, size: 14),
                    label: const Text('My Submission', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                      foregroundColor: const Color(0xFF10B981),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
}
