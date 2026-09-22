import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/download_helper.dart';
import '../utils/error_formatter.dart';

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
  bool _expansionInitialized = false;
  final Set<String> _loadingCourses = {};
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  void _loadAssignments({bool forceRefresh = false}) {
    setState(() {
      _assignmentsFuture = _getAssignmentsData(forceRefresh: forceRefresh);
    });
  }

  Future<List<dynamic>> _getAssignmentsData({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final mem = StorageService.getMemoryCache('assignments');
      if (mem is List && mem.isNotEmpty) {
        return List<dynamic>.from(mem);
      }
      final disk = await StorageService.getCache('assignments');
      if (disk is List && disk.isNotEmpty) {
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
        return fresh;
      }
    } catch (e) {
      debugPrint('AssignmentsScreen: Network fetch failed ($e). Checking offline cache...');
      final fallback = StorageService.getMemoryCache('assignments') ??
          await StorageService.getCache('assignments');
      if (fallback is List && fallback.isNotEmpty) {
        return List<dynamic>.from(fallback);
      }
      rethrow;
    }

    final fallback = StorageService.getMemoryCache('assignments') ??
        await StorageService.getCache('assignments');
    if (fallback is List && fallback.isNotEmpty) {
      return List<dynamic>.from(fallback);
    }
    return [];
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

      final cleanTitle = title.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
      await DownloadHelper.saveFile(
        context: context,
        fileName: 'Assignment_${cleanTitle}_$type.pdf',
        content: bytes,
        mimeType: 'application/pdf',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            ErrorFormatter.format(e, fallback: 'Failed to download assignment file. Please try again.'),
            style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white),
          ),
        ),
      );
    }
  }

  bool _isSubmitted(String status) {
    final s = status.toLowerCase();
    return s.contains('submitted') || s.contains('uploaded') || s.contains('completed');
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        title: Text(
          'Digital Assignments',
          style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4, color: _ink),
        ),
        backgroundColor: _paper,
        iconTheme: IconThemeData(color: _ink),
        elevation: 0,
        scrolledUnderElevation: 3.0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: const [],
        bottom: _isDownloading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  backgroundColor: _line,
                  color: _blue,
                  minHeight: 3,
                ),
              )
            : null,
      ),
      body: FutureBuilder<List<dynamic>>(
          future: _assignmentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildSkeletonLoading();
            }

            if (snapshot.hasError) {
              return RefreshIndicator(
                onRefresh: () async => _loadAssignments(forceRefresh: true),
                color: _blue,
                backgroundColor: _surface,
                child: ListView(
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
                                  color: _red.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.error_outline_rounded, size: 48, color: _red),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Failed to Load Assignments',
                                style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: _ink),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                ErrorFormatter.format(
                                  snapshot.error,
                                  fallback: 'Unable to load assignments. Please check your connection and try again.',
                                ),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.dmSans(fontSize: 12, color: _muted, height: 1.4),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => _loadAssignments(forceRefresh: true),
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _blue,
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
                ),
              );
            }

            final courses = snapshot.data ?? [];

            // Initialize the accordion once with every course collapsed.
            // Each course is opened independently when the user taps it.
            if (!_expansionInitialized) {
              _expandedCourses.clear();
              _expansionInitialized = true;
            }

            if (courses.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async => _loadAssignments(forceRefresh: true),
                color: _blue,
                backgroundColor: _surface,
                child: ListView(
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
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: _surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _blue.withValues(alpha: 0.3)),
                                ),
                                child: Icon(Icons.assignment_turned_in_rounded, size: 48, color: _blue),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No Assignments Found',
                                style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.bold, color: _ink),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No digital assignments have been posted for the active semester yet.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.dmSans(fontSize: 13, color: _muted, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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
              color: _blue,
              backgroundColor: _surface,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // 1. STATS METRICS GRID
                  _buildStatsGrid(totalAssignments, submittedCount, pendingCount),
                  const SizedBox(height: 18),

                  // 2. SEARCH & FILTER SECTION
                  _buildSearchAndFilters(),
                  const SizedBox(height: 18),

                  // 3. COURSE LIST ACCORDIONS
                  ...filteredCourses.map((course) => _buildCourseCard(course)),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
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
            color: _blue,
            bgGradient: [_surface, _surface],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            title: 'Submitted',
            value: submitted.toString(),
            icon: Icons.check_circle_outline_rounded,
            color: _green,
            bgGradient: [_surface, _surface],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            title: 'Pending',
            value: pending.toString(),
            icon: Icons.hourglass_top_rounded,
            color: _orange,
            bgGradient: [_surface, _surface],
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
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
            style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.bold, color: _ink, height: 1.0),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, color: _muted),
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
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: TextField(
            style: GoogleFonts.dmSans(color: _ink, fontSize: 13),
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search course code, name, or faculty...',
              hintStyle: GoogleFonts.dmSans(color: _muted, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: _muted, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, size: 18, color: _muted),
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
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                    decoration: BoxDecoration(
                      color: isSelected ? (_palette.isDark ? _palette.soft : _navy) : _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? (_palette.isDark ? _palette.line : _navy) : _line,
                      ),
                    ),
                    child: Text(
                      filter,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? (_palette.isDark ? _ink : Colors.white) : _muted,
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

    final isExpanded = _expandedCourses.contains(classId);
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
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExpanded ? _blue.withValues(alpha: 0.4) : _line,
        ),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.06),
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
                padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _blue.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            code,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _blue,
                            ),
                          ),
                        ),
                        if (type.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _paper,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              type,
                              style: GoogleFonts.dmSans(fontSize: 10.5, color: _muted),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Container(
                          constraints: const BoxConstraints(minWidth: 44),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _soft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${assignments.length} DA',
                            style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: _muted),
                          ),
                        ),
                        const SizedBox(width: 6),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          child: Icon(Icons.keyboard_arrow_down_rounded, color: _muted, size: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, color: _ink),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 14, color: _muted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            faculty,
                            style: GoogleFonts.dmSans(fontSize: 11.5, color: _muted),
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
            Divider(height: 1, color: _line),
            if (isLoading)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: _blue, strokeWidth: 2)),
              )
            else if (assignments.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: _muted),
                    const SizedBox(width: 8),
                    Text(
                      'No ${_selectedFilter == 'All' ? '' : _selectedFilter.toLowerCase()} assignments available',
                      style: GoogleFonts.dmSans(fontSize: 12, color: _muted),
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
        color: _soft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone ? _green.withValues(alpha: 0.3) : _line,
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
                  style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: _ink, height: 1.3),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDone ? _green.withValues(alpha: 0.10) : _orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDone ? _green : _orange,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  isDone ? 'Submitted' : 'Pending',
                  style: GoogleFonts.dmSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isDone ? _green : _orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _paper,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildInfoColumn(
                    'Due Date',
                    dueDate,
                    Icons.calendar_today_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoColumn(
                    'Max Marks',
                    maxMarks,
                    Icons.score_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoColumn(
                    'Weightage',
                    '$weightage%',
                    Icons.pie_chart_outline_rounded,
                  ),
                ),
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
                        foregroundColor: _blue,
                        side: BorderSide(color: _blue),
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
                        backgroundColor: _green,
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
            Icon(icon, size: 12, color: _muted),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: _muted)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
      ],
    );
  }

  // --- LOADING ---
  Widget _buildSkeletonLoading() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _blue,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'Loading assignments...',
              style: GoogleFonts.dmSans(
                color: _muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}