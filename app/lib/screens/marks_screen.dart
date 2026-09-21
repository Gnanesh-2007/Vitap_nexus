import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/vtop_providers.dart';
import '../services/storage_service.dart';
import '../utils/vtop_helpers.dart';

class MarksScreen extends ConsumerStatefulWidget {
  const MarksScreen({super.key});

  @override
  ConsumerState<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends ConsumerState<MarksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _paper = Color(0xFFF4F2ED);
  static const _surface = Color(0xFFFFFEFB);
  static const _ink = Color(0xFF17202A);
  static const _navy = Color(0xFF172B4D);
  static const _blue = Color(0xFF356AE6);
  static const _orange = Color(0xFFE47543);
  static const _green = Color(0xFF278B68);
  static const _muted = Color(0xFF6E7681);
  static const _line = Color(0xFFE2DED5);
  static const _soft = Color(0xFFF0EEE8);

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

  TextStyle get _labelStyle => GoogleFonts.spaceGrotesk(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      );

  String _formatLastSynced(DateTime? timestamp) {
    if (timestamp == null) return 'Not Synced 💾';
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now 💾';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago 💾';
    if (diff.inHours < 24) return '${diff.inHours} hours ago 💾';
    return '${diff.inDays} days ago 💾';
  }

  TextStyle get _bodyStyle => GoogleFonts.dmSans();

  @override
  Widget build(BuildContext context) {
    final marksAsync = ref.watch(marksProvider);
    final lastSyncedTime = StorageService.getMemoryTimestamp('marks');

    return Scaffold(
      backgroundColor: _paper,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(146),
        child: AppBar(
          backgroundColor: _paper,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          toolbarHeight: 92,
          title: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('ACADEMICS', style: _labelStyle.copyWith(color: _orange)),
                      const SizedBox(height: 3),
                      Text(
                        'Marks & Assessments',
                        style: GoogleFonts.dmSans(
                          color: _ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Last Synced: ${_formatLastSynced(lastSyncedTime)}',
                        style: GoogleFonts.dmSans(
                          color: _muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: marksAsync.isLoading
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await refreshMarks(ref);
                            } catch (e) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Could not update marks: $e'),
                                  ),
                                );
                              }
                            }
                          },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _line),
                      ),
                      child: marksAsync.isLoading
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(_navy),
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.refresh_rounded,
                              color: _navy,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: _soft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _line),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: _muted,
                  labelStyle: GoogleFonts.spaceGrotesk(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .2,
                  ),
                  unselectedLabelStyle: GoogleFonts.spaceGrotesk(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                  indicator: BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  tabs: const [
                    Tab(text: 'THEORY'),
                    Tab(text: 'LAB / PRACTICAL'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: marksAsync.when(
              data: (marksList) {
                if (marksList.isEmpty) return _buildNoMarks();

                final theoryMarks = <dynamic>[];
                final labMarks = <dynamic>[];

                for (final item in marksList) {
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
              loading: _buildSkeletonLoading,
              error: (err, stack) => _buildError(err),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMarks() {
    return RefreshIndicator(
      onRefresh: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await refreshMarks(ref);
        } catch (e) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text('Could not update marks: $e')),
            );
          }
        }
      },
      color: _blue,
      backgroundColor: _surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * .55,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: _line),
                      ),
                      child: const Icon(
                        Icons.analytics_outlined,
                        color: _blue,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No Marks Released',
                      style: GoogleFonts.dmSans(
                        color: _ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'No marks have been uploaded for this semester yet.\nPull down to refresh.',
                      textAlign: TextAlign.center,
                      style: _bodyStyle.copyWith(
                        color: _muted,
                        fontSize: 13,
                        height: 1.45,
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

  Widget _buildError(Object err) {
    return RefreshIndicator(
      onRefresh: () async {
        try {
          await refreshMarks(ref);
        } catch (_) {}
      },
      color: _blue,
      backgroundColor: _surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * .55,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCEDEA),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE9C8C0)),
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        color: _orange,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to Load Marks',
                      style: GoogleFonts.dmSans(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      err.toString(),
                      textAlign: TextAlign.center,
                      style: _bodyStyle.copyWith(
                        color: _muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () async {
                        try {
                          await refreshMarks(ref);
                        } catch (_) {}
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: const Text('Try Again'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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

  Widget _buildSkeletonLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _blue,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Loading marks...',
            style: _bodyStyle.copyWith(
              color: _muted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarksList(
    List<dynamic> list, {
    required bool isLabTab,
  }) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await refreshMarks(ref);
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text('Could not update marks: $e')),
              );
            }
          }
        },
        color: _blue,
        backgroundColor: _surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * .5,
              child: Center(
                child: Text(
                  isLabTab
                      ? 'No lab assessments found.'
                      : 'No theory assessments found.',
                  style: _bodyStyle.copyWith(
                     fontSize: 13,
                     color: _muted,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await refreshMarks(ref);
        } catch (e) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text('Could not update marks: $e')),
            );
          }
        }
      },
      color: _blue,
      backgroundColor: _surface,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final subject = list[index];
          final courseTitle = subject['course_title'] ?? 'Course';
          final courseCode = subject['course_code'] ?? '';
          final faculty = subject['faculty'] ?? '';
          final slot = subject['slot'] ?? '';
          final details = (subject['details'] as List<dynamic>?) ?? [];

          double totalWeightage = 0;
          for (final d in details) {
            totalWeightage +=
                double.tryParse(d['weightage_mark']?.toString() ?? '') ?? 0;
          }

          return _buildCourseCard(
            courseTitle: courseTitle.toString(),
            courseCode: courseCode.toString(),
            faculty: faculty.toString(),
            slot: slot.toString(),
            details: details,
            totalWeightage: totalWeightage,
            isLabTab: isLabTab,
            index: index,
          );
        },
      ),
    );
  }

  Widget _buildCourseCard({
    required String courseTitle,
    required String courseCode,
    required String faculty,
    required String slot,
    required List<dynamic> details,
    required double totalWeightage,
    required bool isLabTab,
    required int index,
  }) {
    final accent = isLabTab ? _green : _blue;
    final accentSoft = isLabTab
        ? const Color(0xFFE8F4EF)
        : const Color(0xFFEAF0FD);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C17202A),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: accent.withValues(alpha: .05),
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(15, 8, 12, 8),
            childrenPadding: EdgeInsets.zero,
            backgroundColor: _surface,
            collapsedBackgroundColor: _surface,
            shape: const RoundedRectangleBorder(),
            collapsedShape: const RoundedRectangleBorder(),
            iconColor: _muted,
            collapsedIconColor: _muted,
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 46,
                  margin: const EdgeInsets.only(right: 12, top: 1),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: [
                          if (courseCode.isNotEmpty)
                            _MetaChip(
                              text: courseCode,
                              color: accent,
                              background: accentSoft,
                            ),
                          if (slot.isNotEmpty)
                            _MetaChip(
                              text: slot,
                              color: _muted,
                              background: _soft,
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        courseTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.18,
                        ),
                      ),
                      if (faculty.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline_rounded,
                              size: 13,
                              color: _muted,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                faculty,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _bodyStyle.copyWith(
                                  color: _muted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (totalWeightage > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, right: 4, top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          totalWeightage.toStringAsFixed(1),
                          style: GoogleFonts.dmSans(
                            color: accent,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'WEIGHTAGE',
                          style: _labelStyle.copyWith(
                            color: _muted,
                            fontSize: 7.5,
                            letterSpacing: .7,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            children: [
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F6F1),
                  border: Border(
                    top: BorderSide(color: _line),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(15, 14, 15, 16),
                child: details.isEmpty
                    ? Text(
                        'No individual assessment marks released yet.',
                        style: _bodyStyle.copyWith(
                          color: _muted,
                          fontSize: 12,
                        ),
                      )
                    : _buildDetailsTable(
                        details,
                        accent,
                      ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: (30 * index).ms)
        .fadeIn(duration: 300.ms)
        .slideY(begin: .035, end: 0);
  }

  Widget _buildDetailsTable(List<dynamic> details, Color accent) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                'ASSESSMENT',
                style: _labelStyle.copyWith(
                  color: _muted,
                  fontSize: 8.5,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'SCORED / MAX',
                textAlign: TextAlign.center,
                style: _labelStyle.copyWith(
                  color: _muted,
                  fontSize: 8.5,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'WEIGHTAGE',
                textAlign: TextAlign.right,
                style: _labelStyle.copyWith(
                  color: _muted,
                  fontSize: 8.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        const Divider(height: 1, color: _line),
        const SizedBox(height: 5),
        ...details.map((d) {
          final title = d['mark_title'] ?? 'Assessment';
          final scored = d['scored_mark'] ?? '-';
          final maxM = d['max_mark'] ?? '-';
          final weight = d['weightage_mark'] ?? '-';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    title.toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _bodyStyle.copyWith(
                      color: _ink,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '$scored / $maxM',
                    textAlign: TextAlign.center,
                    style: _bodyStyle.copyWith(
                      color: _navy,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    weight.toString(),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.dmSans(
                      color: accent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;

  const _MetaChip({
    required this.text,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: .45,
        ),
      ),
    );
  }
}
