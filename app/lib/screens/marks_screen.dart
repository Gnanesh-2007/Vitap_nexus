import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/vtop_providers.dart';
import '../theme/app_theme.dart';
import '../utils/vtop_helpers.dart';
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
      appBar: AppBar(
        title: Text(
          'Marks & Assessments',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.refresh(marksProvider),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF94A3B8),
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Theory Assessments'),
                Tab(text: 'Lab / Practicals'),
              ],
            ),
          ),
        ),
      ),
      body: MeshAmbientBackground(
        child: marksAsync.when(
          data: (marksList) {
            if (marksList.isEmpty) {
              return Center(
                child: Text(
                  'No marks uploaded for this semester yet.',
                  style: GoogleFonts.inter(color: Colors.white70),
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
                  const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                  const SizedBox(height: 16),
                  Text('Failed to load marks', style: GoogleFonts.outfit(fontSize: 18, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(err.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => ref.refresh(marksProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 110,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08));
  }

  Widget _buildMarksList(List<dynamic> list, {required bool isLabTab}) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          isLabTab ? 'No lab assessments found.' : 'No theory assessments found.',
          style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(marksProvider.future),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final subject = list[index];
          final courseTitle = subject['course_title'] ?? 'Course';
          final courseCode = subject['course_code'] ?? '';
          final faculty = subject['faculty'] ?? '';
          final slot = subject['slot'] ?? '';
          final details = (subject['details'] as List<dynamic>?) ?? [];

          // Calculate total weightage
          double totalWeightage = 0;
          for (var d in details) {
            final weight = double.tryParse(d['weightage_mark']?.toString() ?? '') ?? 0;
            totalWeightage += weight;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isLabTab
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : AppTheme.cardBorder,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                backgroundColor: Colors.transparent,
                collapsedBackgroundColor: Colors.transparent,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        courseCode,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isLabTab ? AppTheme.cyanAccent : AppTheme.primaryAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (slot.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isLabTab
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          slot,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isLabTab ? AppTheme.cyanAccent : Colors.white70,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        courseTitle,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (faculty.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          faculty,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing: totalWeightage > 0
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            totalWeightage.toStringAsFixed(1),
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.cyanAccent,
                            ),
                          ),
                          Text(
                            'Weightage',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      )
                    : const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
                children: [
                  if (details.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No individual assessment marks released yet.',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // Table Header
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Assessment',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Scored / Max',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Weightage',
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Color(0xFF30363D), height: 16),

                          // Rows
                          ...details.map((d) {
                            final title = d['mark_title'] ?? 'Assessment';
                            final scored = d['scored_mark'] ?? '-';
                            final maxM = d['max_mark'] ?? '-';
                            final weight = d['weightage_mark'] ?? '-';

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      title,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '$scored / $maxM',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      weight,
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
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
          )
              .animate(delay: (35 * index).ms)
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.06, end: 0);
        },
      ),
    );
  }
}
