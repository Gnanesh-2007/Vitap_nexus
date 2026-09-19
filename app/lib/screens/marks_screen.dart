import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/vtop_providers.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/vtop_helpers.dart';
import '../widgets/last_synced_badge.dart';
import '../widgets/mesh_ambient_background.dart';

class MarksScreen extends ConsumerStatefulWidget {
  const MarksScreen({super.key});

  @override
  ConsumerState<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends ConsumerState<MarksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marksAsync = ref.watch(marksProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(98),
        child: AppBar(
          titleSpacing: 0,
          toolbarHeight: 48,
          backgroundColor: AppTheme.surface.withValues(alpha: 0.95),
          elevation: 0,
          scrolledUnderElevation: 1.0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'Marks & Assessments',
            style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          actions: const [],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(42),
            child: Container(
              height: 36,
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF24344D)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF94A3B8),
                labelStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Theory Assessments'),
                  Tab(text: 'Lab / Practicals'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: MeshAmbientBackground(
        child: Column(
          children: [
            LastSyncedBadge(
              lastSynced: StorageService.getMemoryTimestamp('marks'),
              isRefreshing: marksAsync.isLoading,
              onRefresh: () => ref.refresh(marksProvider.future),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
            Expanded(
              child: marksAsync.when(
          data: (marksList) {
            if (marksList.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primary.withValues(alpha: 0.2),
                              AppTheme.cyanAccent.withValues(alpha: 0.05),
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.analytics_outlined, size: 40, color: AppTheme.cyanAccent),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Marks Released',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'No marks uploaded for this semester yet.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              );
            }

            final theoryMarks = <dynamic>[];
            final labMarks = <dynamic>[];

            for (var item in marksList) {
              final isLab = VtopHelpers.isLabCourse(
                courseType: item['course_type']?.toString(),
                courseSlot: item['slot']?.toString(),
              );
              if (isLab) {
                labMarks.add(item);
              } else {
                theoryMarks.add(item);
              }
            }

            return TabBarView(
              controller: _tabController,
              children: [
                _buildMarksList(theoryMarks, isLabTab: false),
                _buildMarksList(labMarks, isLabTab: true),
              ],
            );
          },
          loading: () => _buildSkeletonLoading(),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.error_outline_rounded, size: 40, color: AppTheme.error),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Failed to Load Marks',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    err.toString(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white54, height: 1.3),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => ref.refresh(marksProvider.future),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
            ),
          ],
        ),
      ),
    );
  }

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
          Text('Loading marks...', style: TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildMarksList(List<dynamic> list, {required bool isLabTab}) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => ref.refresh(marksProvider.future),
        color: AppTheme.cyanAccent,
        backgroundColor: AppTheme.surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Text(
                  isLabTab ? 'No lab assessments found.' : 'No theory assessments found.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(marksProvider.future),
      color: AppTheme.cyanAccent,
      backgroundColor: AppTheme.surface,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final subject = list[index];
          final courseTitle = subject['course_title'] ?? 'Course';
          final courseCode = subject['course_code'] ?? '';
          final faculty = subject['faculty'] ?? '';
          final slot = subject['slot'] ?? '';
          final details = (subject['details'] as List<dynamic>?) ?? [];

          double totalWeightage = 0;
          for (var d in details) {
            final weight = double.tryParse(d['weightage_mark']?.toString() ?? '') ?? 0;
            totalWeightage += weight;
          }

          final themeColor = isLabTab ? const Color(0xFF10B981) : AppTheme.primaryAccent;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isLabTab
                    ? const Color(0xFF10B981).withValues(alpha: 0.25)
                    : const Color(0xFF24344D),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  childrenPadding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  collapsedBackgroundColor: Colors.transparent,
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          courseCode,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isLabTab ? AppTheme.cyanAccent : AppTheme.primaryAccent,
                          ),
                        ),
                      ),
                      if (slot.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            slot,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isLabTab ? AppTheme.cyanAccent : Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          courseTitle,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (faculty.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            faculty,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: const Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (totalWeightage > 0)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              totalWeightage.toStringAsFixed(1),
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.cyanAccent,
                              ),
                            ),
                            Text(
                              'Weightage',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        )
                      else
                        const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 20),
                    ],
                  ),
                  children: [
                    const Divider(height: 1, color: Color(0xFF1E293B)),
                    if (details.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'No individual assessment marks released yet.',
                          style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 11),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(10),
                        color: const Color(0xFF0F172A),
                        child: Column(
                          children: [
                            // Header Row
                            Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    'ASSESSMENT',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF64748B),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'SCORED / MAX',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF64748B),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'WEIGHTAGE',
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF64748B),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Color(0xFF1E293B), height: 12),
                            // Data Rows
                            ...details.map((d) {
                              final title = d['mark_title'] ?? 'Assessment';
                              final scored = d['scored_mark'] ?? '-';
                              final maxM = d['max_mark'] ?? '-';
                              final weight = d['weightage_mark'] ?? '-';

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        title,
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        '$scored / $maxM',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        weight,
                                        textAlign: TextAlign.right,
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.cyanAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          )
              .animate(delay: (30 * index).ms)
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.04, end: 0);
        },
      ),
    );
  }
}