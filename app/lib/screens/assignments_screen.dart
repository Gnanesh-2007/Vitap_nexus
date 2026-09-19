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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Downloaded $type for "$title" ($kb KB)',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text('Download failed: $e', style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
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
          style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4),
        ),
        backgroundColor: AppTheme.surface.withValues(alpha: 0.9),
        elevation: 0,
        scrolledUnderElevation: 3.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: _loadAssignments,
            tooltip: 'Refresh Assignments',
          ),
        ],
        bottom: _isDownloading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(
                  backgroundColor: Color(0xFF1E293B),
                  color: AppTheme.cyanAccent,
                  minHeight: 3,
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
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.error),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Failed to Load Assignments',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white54, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadAssignments,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
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
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primary.withValues(alpha: 0.2),
                              AppTheme.cyanAccent.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.assignment_turned_in_rounded, size: 48, color: AppTheme.cyanAccent),
                      ),
                      const SizedBox(height: 20),
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
              color: AppTheme.cyanAccent,
              backgroundColor: AppTheme.surface,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // 1. STATS METRICS GRID
                  _buildStatsGrid(totalAssignments, submittedCount, pendingCount)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: -0.05, end: 0, curve: Curves.easeOutCubic),
                  const SizedBox(height: 18),

                  // 2. SEARCH & FILTER SECTION
                  _buildSearchAndFilters()
                      .animate()
                      .fadeIn(duration: 350.ms, delay: 60.ms),
                  const SizedBox(height: 18),

                  // 3. COURSE LIST ACCORDIONS
                  ...filteredCourses.asMap().entries.map((entry) {
                    final index = entry.key;
                    final course = entry.value;
                    return _buildCourseCard(course)
                        .animate(delay: (40 * index).ms)
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
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

  // --- 1. STATS METRICS GRID ---
  Widget _buildStatsGrid(int total, int submitted, int pending) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: 'Total DA',
            value: total.toString(),
            icon: Icons.assignment_outlined,
            color: const Color(0xFF60A5FA),
            bgGradient: const [Color(0xFF1E3A8A), Color(0xFF0F172A)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            title: 'Submitted',
            value: submitted.toString(),
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF10B981),
            bgGradient: const [Color(0xFF064E3B), Color(0xFF0F172A)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            title: 'Pending',
            value: pending.toString(),
            icon: Icons.hourglass_top_rounded,
            color: const Color(0xFFF59E0B),
            bgGradient: const [Color(0xFF78350F), Color(0xFF0F172A)],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required List<Color> bgGradient,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bgGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, height: 1.0),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  // --- 2. SEARCH & FILTER CONTROLS ---
  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF24344D)),
          ),
          child: TextField(
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search course code, name, or faculty...',
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
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Pending', 'Submitted'].map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() => _selectedFilter = filter),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: 200.ms,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.cyanAccent : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.cyanAccent : const Color(0xFF24344D),
                      ),
                    ),
                    child: Text(
                      filter,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- 3. COURSE ACCORDION CARD ---
  Widget _buildCourseCard(dynamic course) {
    final classId = course['class_id']?.toString() ?? '';
    final code = course['course_code']?.toString() ?? '';
    final title = course['course_title']?.toString() ?? '';
    final type = course['course_type']?.toString() ?? '';
    final faculty = course['faculty']?.toString() ?? '';

    final isExpanded = _expandedCourses.contains(classId) || _expandedCourses.isEmpty;
    final isLoading = _loadingCourses.contains(classId);

    var assignments = _courseAssignmentsCache[classId] ?? (course['details'] as List<dynamic>? ?? []);

    if (_selectedFilter == 'Pending') {
      assignments = assignments.where((a) => !_isSubmitted(a['submission_status']?.toString() ?? '')).toList();
    } else if (_selectedFilter == 'Submitted') {
      assignments = assignments.where((a) => _isSubmitted(a['submission_status']?.toString() ?? '')).toList();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExpanded ? AppTheme.primary.withValues(alpha: 0.4) : const Color(0xFF24344D),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
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
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            code,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.cyanAccent,
                            ),
                          ),
                        ),
                        if (type.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              type,
                              style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${assignments.length} DA',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                        ),
                        const SizedBox(width: 6),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0.0,
                          duration: 250.ms,
                          child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            faculty,
                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Assignments List Content
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFF1E293B)),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: AppTheme.cyanAccent, strokeWidth: 2)),
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
                      'No ${_selectedFilter == 'All' ? '' : _selectedFilter.toLowerCase()} assignments available',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: assignments.map<Widget>((a) => _buildAssignmentCard(a)).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // --- 4. INDIVIDUAL ASSIGNMENT ITEM CARD ---
  Widget _buildAssignmentCard(dynamic a) {
    final title = a['assignment_title']?.toString() ?? 'Assignment';
    final maxMarks = a['max_assignment_mark']?.toString() ?? '-';
    final weightage = a['assignment_weightage_mark']?.toString() ?? '-';
    final dueDate = a['due_date']?.toString() ?? 'N/A';
    final status = a['submission_status']?.toString() ?? 'Not Uploaded';

    final isDone = _isSubmitted(status);
    final canQpDownload = a['can_qp_download'] == true;
    final qpUrl = a['qp_download_url']?.toString() ?? '';
    final canDaDownload = a['can_da_download'] == true;
    final daUrl = a['da_download_url']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFF334155),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDone ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDone ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  isDone ? 'Submitted' : 'Pending',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isDone ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn('Due Date', dueDate, Icons.calendar_today_rounded),
                _buildInfoColumn('Max Marks', maxMarks, Icons.score_rounded),
                _buildInfoColumn('Weightage', '$weightage%', Icons.pie_chart_outline_rounded),
              ],
            ),
          ),
          if (canQpDownload || canDaDownload) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (canQpDownload && qpUrl.isNotEmpty) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _downloadFile(qpUrl, title, 'Question Paper'),
                      icon: const Icon(Icons.download_rounded, size: 14),
                      label: const Text('QP File'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.cyanAccent,
                        side: const BorderSide(color: AppTheme.cyanAccent),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
                if (canQpDownload && canDaDownload) const SizedBox(width: 10),
                if (canDaDownload && daUrl.isNotEmpty) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _downloadFile(daUrl, title, 'Submitted File'),
                      icon: const Icon(Icons.remove_red_eye_rounded, size: 14),
                      label: const Text('My Work'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
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

  Widget _buildInfoColumn(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
      ],
    );
  }

  // --- LOADING ---
  Widget _buildSkeletonLoading() {
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
          Text('Loading assignments...', style: TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}