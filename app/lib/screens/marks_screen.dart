import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/nexus_app_bar.dart';
import '../widgets/nexus_segmented.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../providers/vtop_providers.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_formatter.dart';
import '../widgets/shadcn/shadcn_ui.dart';

/// Helper to categorize courses into Theory, Lab, Project, etc.
class CourseTypeHelper {
  static const String theory = 'Theory';
  static const String lab = 'Lab';
  static const String project = 'Project';

  static String getCourseCategory(String courseType) {
    final lower = courseType.toLowerCase().trim();
    final upper = courseType.toUpperCase().trim();

    if (upper == 'ETH' || upper == 'TH') return theory;
    if (upper == 'ELA' || upper == 'LO') return lab;
    if (upper == 'EPJ' || upper == 'PJ') return project;

    if (lower.contains('theory')) return theory;
    if (lower.contains('lab')) return lab;
    if (lower.contains('project')) return project;

    return courseType.isEmpty ? theory : courseType;
  }

  static List<String> getUniqueCourseCategories(List<String> courseTypes) {
    final Set<String> categories = {};
    for (final type in courseTypes) {
      categories.add(getCourseCategory(type));
    }

    final ordered = <String>[];
    if (categories.contains(theory)) {
      ordered.add(theory);
      categories.remove(theory);
    }
    if (categories.contains(lab)) {
      ordered.add(lab);
      categories.remove(lab);
    }
    if (categories.contains(project)) {
      ordered.add(project);
      categories.remove(project);
    }
    ordered.addAll(categories.toList()..sort());
    return ordered;
  }

  static bool matchesCategory(String courseType, String category) {
    return getCourseCategory(courseType) == category;
  }
}

class MarksScreen extends ConsumerStatefulWidget {
  const MarksScreen({super.key});

  @override
  ConsumerState<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends ConsumerState<MarksScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  List<String> _courseCategories = [];
  final Set<String> _expanded = {};

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _initTabController(List<String> categories) {
    if (_courseCategories.length != categories.length ||
        !_courseCategories.every((e) => categories.contains(e))) {
      _tabController?.dispose();
      _courseCategories = categories;
      _tabController = TabController(length: categories.length, vsync: this);
    }
  }

  Future<void> _onRefresh() async {
    final messenger = ScaffoldMessenger.of(context);
    final cs = Theme.of(context).colorScheme;
    try {
      await refreshMarks(ref);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: cs.primaryContainer,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            content: Text(
              'Marks synced with VTOP',
              style: TextStyle(
                color: cs.onPrimaryContainer,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: cs.errorContainer,
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Offline mode: showing saved marks data.',
              style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
            ),
          ),
        );
      }
    }
  }

  List<dynamic> _resolveMarksList(AsyncValue<List<dynamic>> marksAsync) {
    final val = marksAsync.valueOrNull;
    if (val != null && val.isNotEmpty) return val;
    final mem = StorageService.getMemoryCache('marks');
    if (mem is List && mem.isNotEmpty) return List<dynamic>.from(mem);
    return val ?? const <dynamic>[];
  }

  /// (earned, max) weightage across a course's assessments.
  ({double earned, double max}) _totals(Map course) {
    double earned = 0, max = 0;
    for (final d in (course['details'] as List<dynamic>? ?? const [])) {
      if (d is Map) {
        earned += double.tryParse((d['weightage_mark'] ?? '').toString()) ?? 0;
        max += double.tryParse((d['weightage'] ?? '').toString()) ?? 0;
      }
    }
    return (earned: earned, max: max);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final marksAsync = ref.watch(marksProvider);
    final lastSyncedTime = StorageService.getMemoryTimestamp('marks');
    final marksList = _resolveMarksList(marksAsync);

    final courseTypes = marksList
        .whereType<Map>()
        .map((m) => (m['course_type'] ?? '').toString())
        .toList();
    final categories = CourseTypeHelper.getUniqueCourseCategories(courseTypes);
    if (categories.isNotEmpty) {
      _initTabController(categories);
    }

    return Scaffold(
      backgroundColor: p.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Marks',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: p.ink,
                            height: 1.05,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          StorageService.formatLastSynced(lastSyncedTime),
                          style: GoogleFonts.dmSans(fontSize: 12.5, color: p.inkMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: 'Refresh marks',
                    child: GestureDetector(
                      onTap: marksAsync.isLoading ? null : _onRefresh,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: p.soft, shape: BoxShape.circle),
                        child: Icon(Icons.refresh_rounded, size: 20, color: p.ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_tabController != null && _courseCategories.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _buildSegmented(p),
              ),
            Expanded(
              child: marksList.isNotEmpty
                  ? _buildMarksBody(marksList)
                  : marksAsync.when(
                      data: _buildMarksBody,
                      loading: () => const NexusLoadingState(title: 'Loading marks...'),
                      error: (err, _) => _buildErrorView(err.toString()),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmented(AppPalette p) {
    final c = _tabController!;
    return AnimatedBuilder(
      animation: c.animation!,
      builder: (context, _) => NexusSegmented(
        labels: _courseCategories,
        position: c.animation!.value,
        onSelect: (i) => c.animateTo(i),
      ),
    );
  }

  Widget _buildMarksBody(List<dynamic> marksList) {
    if (_tabController != null && _courseCategories.isNotEmpty) {
      return TabBarView(
        controller: _tabController,
        children: _courseCategories
            .map((cat) => _buildCategoryList(marksList, cat))
            .toList(),
      );
    }
    return _buildCategoryList(marksList, '');
  }

  Widget _buildCategoryList(List<dynamic> marksList, String categoryFilter) {
    final filtered = marksList.whereType<Map>().where((m) {
      if (categoryFilter.isEmpty) return true;
      final type = (m['course_type'] ?? '').toString();
      return CourseTypeHelper.matchesCategory(type, categoryFilter);
    }).toList();

    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: NexusEmptyState(
                icon: Icons.assignment_turned_in_rounded,
                title: categoryFilter.isEmpty
                    ? 'No marks found'
                    : 'No $categoryFilter courses found',
                description: 'Pull down to sync with VTOP.',
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 90),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final course = Map<String, dynamic>.from(filtered[index]);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildCourseCard(course),
          );
        },
      ),
    );
  }

  String _w(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  Color _tone(AppPalette p, double ratio) =>
      ratio >= 0.75 ? p.green : (ratio >= 0.5 ? p.blue : p.orange);

  /// Score tile + one bar per assessment; tap to open each assessment's numbers.
  Widget _buildCourseCard(Map<String, dynamic> course) {
    final p = AppPalette.of(context);
    final title = (course['course_title'] ?? 'Course').toString().trim();
    final faculty = (course['faculty'] ?? '').toString().trim();
    final code = (course['course_code'] ?? '').toString().trim();
    final type = CourseTypeHelper.getCourseCategory(
      (course['course_type'] ?? '').toString(),
    );
    final grade = (course['grade'] ?? '').toString().trim();
    final hasGrade = grade.isNotEmpty && grade != '-';
    final details = (course['details'] as List<dynamic>?) ?? const [];
    final t = _totals(course);
    final ratio = t.max > 0 ? (t.earned / t.max).clamp(0.0, 1.0) : 0.0;
    final tone = _tone(p, ratio);
    final key = '$code-$title';
    final open = _expanded.contains(key);

    // One mini bar per assessment, height = how well it went.
    final bars = <double>[];
    for (final raw in details.whereType<Map>()) {
      final sc = double.tryParse((raw['scored_mark'] ?? raw['scored'] ?? '').toString());
      final mx = double.tryParse((raw['max_mark'] ?? raw['max_marks'] ?? '').toString());
      if (sc != null && mx != null && mx > 0) bars.add((sc / mx).clamp(0.0, 1.0));
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: p.line),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => open ? _expanded.remove(key) : _expanded.add(key));
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                height: 1.12,
                                letterSpacing: -0.3,
                                color: p.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [if (code.isNotEmpty) code, type].join('  ·  '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: p.inkMuted),
                            ),
                            if (faculty.isNotEmpty)
                              Text(
                                faculty,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(fontSize: 11.5, color: p.inkMuted),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: tone.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          children: [
                            Text(
                              t.max > 0 ? _w(t.earned) : '—',
                              style: GoogleFonts.bricolageGrotesque(fontSize: 24, fontWeight: FontWeight.w800, height: 1, color: tone),
                            ),
                            if (t.max > 0)
                              Text('of ${_w(t.max)}',
                                  style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w700, color: p.inkMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (bars.isNotEmpty)
                        SizedBox(
                          height: 34,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final b in bars.take(14))
                                Container(
                                  width: 9,
                                  height: 6 + 28 * b,
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: _tone(p, b),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                            ],
                          ),
                        )
                      else
                        Text('No scores yet', style: GoogleFonts.dmSans(fontSize: 12, color: p.inkMuted)),
                      const Spacer(),
                      if (hasGrade)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(12)),
                          child: Text('Grade $grade',
                              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: p.ink)),
                        ),
                      const SizedBox(width: 6),
                      Icon(open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 24, color: p.inkMuted),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    decoration: BoxDecoration(
                      color: p.soft,
                      border: Border(top: BorderSide(color: p.line)),
                    ),
                    child: _buildTable(details, t),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  /// Each assessment as a row with its own bar, plus the running total.
  Widget _buildTable(List<dynamic> details, ({double earned, double max}) t) {
    final p = AppPalette.of(context);
    if (details.isEmpty) {
      return Text(
        'No individual assessments uploaded yet.',
        style: GoogleFonts.dmSans(fontSize: 12.5, color: p.inkMuted),
      );
    }
    final rows = <Widget>[];
    for (final raw in details.whereType<Map>()) {
      final d = Map<String, dynamic>.from(raw);
      final name = (d['mark_title'] ?? d['title'] ?? 'Assessment').toString().trim();
      final sc = double.tryParse((d['scored_mark'] ?? d['scored'] ?? '').toString());
      final mx = double.tryParse((d['max_mark'] ?? d['max_marks'] ?? '').toString());
      final wm = double.tryParse((d['weightage_mark'] ?? '').toString());
      final r = (sc != null && mx != null && mx > 0) ? (sc / mx).clamp(0.0, 1.0) : 0.0;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.ink)),
                ),
                Text('${sc == null ? '–' : _w(sc)} / ${mx == null ? '–' : _w(mx)}',
                    style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w800, color: p.ink)),
                if (wm != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: _tone(p, r).withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
                    child: Text('+${_w(wm)}',
                        style: GoogleFonts.dmSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: _tone(p, r))),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: r),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 7,
                  backgroundColor: p.line,
                  valueColor: AlwaysStoppedAnimation(_tone(p, r)),
                ),
              ),
            ),
          ],
        ),
      ));
    }
    rows.add(Row(
      children: [
        Text('Total', style: GoogleFonts.bricolageGrotesque(fontSize: 15, fontWeight: FontWeight.w800, color: p.ink)),
        const Spacer(),
        Text('${_w(t.earned)} / ${_w(t.max)}',
            style: GoogleFonts.bricolageGrotesque(fontSize: 15, fontWeight: FontWeight.w800, color: p.ink)),
      ],
    ));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _buildErrorView(String error) {
    return NexusErrorState(
      message: ErrorFormatter.format(error),
      retryLabel: 'Try Again',
      onRetry: _onRefresh,
    );
  }
}

/// Matches the reference app's `MarkDetailPage`:
/// HeaderCard with cs.surfaceContainerHighest (28dp corners), _GradeBadge,
/// _WeightageRow with Gained (cs.tertiaryContainer) & Lost (cs.errorContainer),
/// Assessment breakdown list, and Class mean/SD stats!
class MarkDetailPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> course;

  const MarkDetailPage({super.key, required this.course});

  @override
  ConsumerState<MarkDetailPage> createState() => _MarkDetailPageState();
}

class _MarkDetailPageState extends ConsumerState<MarkDetailPage> {
  Map<String, dynamic>? _stats;
  bool _loadingStats = false;
  bool _statsError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStatsIfNeeded();
    });
  }

  Future<void> _loadStatsIfNeeded() async {
    final course = widget.course;
    final cached = course['grade_stats_json']?.toString();
    if (cached != null && cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is Map && mounted) {
          setState(() => _stats = Map<String, dynamic>.from(decoded));
          return;
        }
      } catch (_) {}
    }

    final grade = (course['grade'] ?? '').toString().trim();
    final gradeCourseId = (course['grade_course_id'] ?? '').toString().trim();
    if (grade.isEmpty || grade == '-' || gradeCourseId.isEmpty) return;

    setState(() {
      _loadingStats = true;
      _statsError = false;
    });

    try {
      final auth = ref.read(authProvider);
      final creds = await StorageService.getCredentials();
      final username = auth.username ?? creds['username'] ?? '';
      final password = auth.password ?? creds['password'] ?? '';
      final semSubId = auth.activeSemesterId ?? creds['semesterId'] ?? '';

      if (username.isEmpty || password.isEmpty || semSubId.isEmpty) {
        if (mounted) setState(() => _loadingStats = false);
        return;
      }

      final detail = await apiService.fetchGradeViewDetail(
        username: username,
        password: password,
        semSubId: semSubId,
        courseId: gradeCourseId,
      );

      final statsMap = detail['statistics'];
      if (statsMap is Map && mounted) {
        final typed = Map<String, dynamic>.from(statsMap);
        course['grade_stats_json'] = jsonEncode(typed);
        setState(() {
          _stats = typed;
          _loadingStats = false;
        });
      } else if (mounted) {
        setState(() => _loadingStats = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingStats = false;
          _statsError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final course = widget.course;
    final courseCode = (course['course_code'] ?? 'Course').toString().trim();
    final grade = (course['grade'] ?? '').toString().trim();
    final hasGrade = grade.isNotEmpty && grade != '-';
    final details = (course['details'] as List<dynamic>?) ?? const [];

    return Scaffold(
      appBar: NexusAppBar(title: courseCode, subtitle: 'Assessment details'),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 36),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _buildHeaderCard(course, hasGrade: hasGrade),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildWeightageRow(details),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 10),
            child: Text(
              'Assessment breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
          if (details.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Text(
                'No individual assessments uploaded yet.',
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
              ),
            )
          else
            ...details.whereType<Map>().map(
                  (d) => _buildBreakdownTile(Map<String, dynamic>.from(d)),
                ),
          if (hasGrade) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 10),
              child: Text(
                'Grades',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildGradesSection(grade),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
    Map<String, dynamic> course, {
    required bool hasGrade,
  }) {
    final cs = Theme.of(context).colorScheme;
    final courseTitle = (course['course_title'] ?? 'Course').toString().trim();
    final courseCode = (course['course_code'] ?? '').toString().trim();
    final courseType = (course['course_type'] ?? '').toString().trim();
    final faculty = (course['faculty'] ?? '').toString().trim();
    final grade = (course['grade'] ?? '').toString().trim();
    final grandTotal = (course['grand_total'] ?? '').toString().trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courseTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [courseCode, courseType]
                      .where((s) => s.isNotEmpty)
                      .join(' · '),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (faculty.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    faculty,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasGrade) ...[
            const SizedBox(width: 16),
            Container(
              width: 84,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    grade,
                    style: TextStyle(
                      fontSize: 32,
                      color: cs.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (grandTotal.isNotEmpty && grandTotal != '-')
                    Text(
                      '$grandTotal / 100',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onPrimary.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeightageRow(List<dynamic> details) {
    final cs = Theme.of(context).colorScheme;
    double gained = 0;
    double lost = 0;
    for (final raw in details) {
      if (raw is! Map) continue;
      final detail = Map<String, dynamic>.from(raw);
      gained +=
          double.tryParse((detail['weightage_mark'] ?? '').toString()) ?? 0;
      final maxMark =
          double.tryParse((detail['max_mark'] ?? '').toString()) ?? 0;
      final scoredMark =
          double.tryParse((detail['scored_mark'] ?? '').toString()) ?? 0;
      final weightage =
          double.tryParse((detail['weightage'] ?? '').toString()) ?? 0;
      if (maxMark > 0) {
        lost += (maxMark - scoredMark) * weightage / maxMark;
      }
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            value: gained.toStringAsFixed(1),
            label: 'Gained weightage',
            fill: cs.tertiaryContainer,
            onFill: cs.onTertiaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            value: lost.toStringAsFixed(1),
            label: 'Lost weightage',
            fill: cs.errorContainer,
            onFill: cs.onErrorContainer,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required Color fill,
    required Color onFill,
  }) {
    return Container(
      height: 96,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              color: onFill,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: onFill,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownTile(Map<String, dynamic> detail) {
    final cs = Theme.of(context).colorScheme;
    final markTitle = (detail['mark_title'] ?? detail['title'] ?? 'Assessment')
        .toString()
        .trim();
    final weightage = (detail['weightage'] ?? '0').toString().trim();
    final scoredMark = (detail['scored_mark'] ?? detail['scored'] ?? '0')
        .toString()
        .trim();
    final maxMark = (detail['max_mark'] ?? detail['max_marks'] ?? '0')
        .toString()
        .trim();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      title: Text(
        markTitle,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
      subtitle: Text(
        'Weightage $weightage%',
        style: TextStyle(
          fontSize: 13,
          color: cs.onSurfaceVariant,
        ),
      ),
      trailing: Text(
        '$scoredMark / $maxMark',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
    );
  }

  Widget _buildGradesSection(String myGrade) {
    final cs = Theme.of(context).colorScheme;

    if (_loadingStats) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
        ),
      );
    }

    if (_statsError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          "Couldn't load class statistics.",
          style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
        ),
      );
    }

    final stats = _stats;
    if (stats == null) return const SizedBox.shrink();

    final mean = (stats['mean'] ?? '').toString().trim();
    final sd = (stats['sd'] ?? '').toString().trim();
    final gradeRanges = (stats['grade_ranges'] as List<dynamic>?) ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(label: 'Class mean', value: mean),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(label: 'Std deviation', value: sd),
            ),
          ],
        ),
        if (gradeRanges.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Grade cutoffs',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ...gradeRanges.whereType<Map>().map((raw) {
            final r = Map<String, dynamic>.from(raw);
            final rGrade = (r['grade'] ?? '').toString().trim();
            final rRange = (r['range'] ?? '').toString().trim();
            return _buildCutoffRow(
              grade: rGrade,
              range: rRange,
              isMine: rGrade == myGrade,
            );
          }),
        ],
      ],
    );
  }

  Widget _buildMetricTile({required String label, required String value}) {
    final cs = Theme.of(context).colorScheme;
    final parsed = double.tryParse(value);
    final display = parsed != null
        ? parsed.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')
        : value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            display.isEmpty ? '—' : display,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCutoffRow({
    required String grade,
    required String range,
    required bool isMine,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMine ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              grade,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isMine ? cs.onPrimaryContainer : cs.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              range
                  .replaceAll('#', '')
                  .replaceAll('>=', '≥ ')
                  .replaceAll('<', '< ')
                  .replaceAll(' and ', ', ')
                  .trim(),
              style: TextStyle(
                fontSize: 14,
                color: isMine ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                fontWeight: isMine ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (isMine)
            Text(
              'You',
              style: TextStyle(
                fontSize: 13,
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}
