import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/vtop_providers.dart';
import '../theme/app_theme.dart';
import '../utils/vtop_helpers.dart';
import '../widgets/mesh_ambient_background.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  late String _selectedDay;

  @override
  void initState() {
    super.initState();
    final today = DateFormat('EEEE').format(DateTime.now());
    _selectedDay = _days.contains(today) ? today : 'Monday';
  }

  @override
  Widget build(BuildContext context) {
    final timetableAsync = ref.watch(timetableProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Timetable',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.refresh(timetableProvider),
          ),
        ],
      ),
      body: MeshAmbientBackground(
        child: Column(
          children: [
            // Day Selector Tabs
            Container(
            height: 52,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _days.length,
              itemBuilder: (context, index) {
                final day = _days[index];
                final isSelected = day == _selectedDay;
                final isToday = day == DateFormat('EEEE').format(DateTime.now());

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDay = day;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary
                          : isToday
                              ? AppTheme.surfaceLight
                              : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryAccent
                            : isToday
                                ? AppTheme.cyanAccent.withValues(alpha: 0.5)
                                : const Color(0xFF24344D),
                        width: isSelected || isToday ? 1.5 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: Row(
                        children: [
                          if (isToday) ...[
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.cyanAccent,
                              ),
                            ),
                          ],
                          Text(
                            day.substring(0, 3),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Morning to Evening Chronological List
          Expanded(
            child: timetableAsync.when(
              data: (timetableData) {
                final rawSchedule = (timetableData[_selectedDay] as List<dynamic>?) ?? [];
                // Sort chronologically from morning (08:00) to evening (18:00)
                final daySchedule = VtopHelpers.sortTimetableList(rawSchedule);

                if (daySchedule.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.weekend_outlined, size: 56, color: Colors.white24),
                        const SizedBox(height: 12),
                        Text(
                          'No classes scheduled for $_selectedDay',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(timetableProvider.future),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: daySchedule.length,
                    itemBuilder: (context, index) {
                      final item = daySchedule[index];
                      final courseName = item['course_name'] ?? 'Class';
                      final courseCode = item['course_code'] ?? '';
                      final time = item['time'] ?? '';
                      final slot = item['slot'] ?? '';
                      final venue = item['venue'] ?? 'TBA';
                      final faculty = item['faculty'] ?? '';
                      final courseType = item['course_type'] ?? '';

                      final isLab = VtopHelpers.isLabCourse(
                        courseType: courseType,
                        courseSlot: slot,
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isLab
                                ? AppTheme.cyanAccent.withValues(alpha: 0.35)
                                : AppTheme.cardBorder,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Left Accent Strip (Green for Lab, Blue for Theory)
                              Container(
                                width: 5,
                                decoration: BoxDecoration(
                                  color: isLab ? AppTheme.cyanAccent : AppTheme.primary,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top Row: Time Range + Slot Badge + Type
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.schedule_rounded,
                                                size: 15,
                                                color: isLab ? AppTheme.cyanAccent : AppTheme.primaryAccent,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                time,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: isLab ? AppTheme.cyanAccent : AppTheme.primaryAccent,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  slot,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isLab
                                                      ? AppTheme.cyanAccent.withValues(alpha: 0.15)
                                                      : AppTheme.primary.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: isLab
                                                        ? AppTheme.cyanAccent.withValues(alpha: 0.5)
                                                        : AppTheme.primary.withValues(alpha: 0.5),
                                                  ),
                                                ),
                                                child: Text(
                                                  courseType,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: isLab ? AppTheme.cyanAccent : AppTheme.primaryAccent,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // Course Title
                                      Text(
                                        courseName,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (courseCode.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          courseCode,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),

                                      // Venue & Faculty
                                      Row(
                                        children: [
                                          Icon(Icons.room_rounded, size: 15, color: AppTheme.cyanAccent),
                                          const SizedBox(width: 4),
                                          Text(
                                            venue,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.cyanAccent,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (faculty.isNotEmpty) ...[
                                            const Icon(Icons.person_outline, size: 14, color: Color(0xFF94A3B8)),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                faculty,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color: const Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                          .animate(delay: (35 * index).ms)
                          .fadeIn(duration: 350.ms)
                          .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
                    },
                  ),
                );
              },
              loading: () => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: 5,
                itemBuilder: (context, index) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08)),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                      const SizedBox(height: 16),
                      Text('Failed to load timetable', style: GoogleFonts.outfit(fontSize: 18, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text(err.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => ref.refresh(timetableProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
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
}
