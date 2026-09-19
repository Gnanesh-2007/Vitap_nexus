import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/vtop_providers.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/vtop_helpers.dart';
import '../widgets/last_synced_badge.dart';
import '../widgets/mesh_ambient_background.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final List<String> _dayShortcuts = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final today = DateFormat('EEEE').format(DateTime.now());
    int initialIndex = _days.indexOf(today);
    if (initialIndex == -1) initialIndex = 0;

    _tabController = TabController(
      length: _days.length,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Safely parses time string using multiple format fallbacks
  DateTime? _parseTime(String timeStr, DateTime referenceDate) {
    final cleanStr = timeStr.trim().toUpperCase();
    final formats = ['HH:mm', 'H:mm', 'hh:mm a', 'h:mm a', 'hh:mm', 'h:mm'];

    for (final format in formats) {
      try {
        final parsed = DateFormat(format).parse(cleanStr);
        return DateTime(
          referenceDate.year,
          referenceDate.month,
          referenceDate.day,
          parsed.hour,
          parsed.minute,
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Determines class timing state (LIVE, UPCOMING, COMPLETED)
  Map<String, dynamic> _getClassTimingStatus(String timeSlot, String selectedDay) {
    final now = DateTime.now();
    final today = DateFormat('EEEE').format(now);

    if (selectedDay != today) {
      return {'status': 'UPCOMING', 'color': AppTheme.primaryAccent};
    }

    try {
      final parts = timeSlot.split('-').map((e) => e.trim()).toList();
      if (parts.length != 2) return {'status': 'SCHEDULED', 'color': AppTheme.primaryAccent};

      final startTime = _parseTime(parts[0], now);
      final endTime = _parseTime(parts[1], now);

      if (startTime == null || endTime == null) {
        return {'status': 'SCHEDULED', 'color': AppTheme.primaryAccent};
      }

      if (now.isAfter(startTime) && now.isBefore(endTime)) {
        return {'status': 'LIVE NOW', 'color': const Color(0xFF10B981)};
      } else if (now.isAfter(endTime)) {
        return {'status': 'COMPLETED', 'color': const Color(0xFF64748B)};
      } else {
        return {'status': 'UPCOMING', 'color': AppTheme.cyanAccent};
      }
    } catch (_) {
      return {'status': 'SCHEDULED', 'color': AppTheme.primaryAccent};
    }
  }

  @override
  Widget build(BuildContext context) {
    final timetableAsync = ref.watch(timetableProvider);
    final todayName = DateFormat('EEEE').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Schedule',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            fontSize: 28,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.white),
              onPressed: () => ref.refresh(timetableProvider.future),
            ),
          ),
        ],
      ),
      body: MeshAmbientBackground(
        child: Column(
          children: [
            LastSyncedBadge(
              lastSynced: StorageService.getMemoryTimestamp('timetable'),
              isRefreshing: timetableAsync.isLoading,
              onRefresh: () => ref.refresh(timetableProvider.future),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
            // Single-Line Tab Bar (Fits all 7 days without scrolling)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: false, // Fits all 7 items cleanly within screen width
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF94A3B8),
                labelStyle: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                padding: EdgeInsets.zero,
                labelPadding: EdgeInsets.zero,
                tabs: List.generate(_days.length, (index) {
                  final dayName = _days[index];
                  final isToday = dayName == todayName;

                  return Tab(
                    height: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isToday)
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.only(right: 3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.cyanAccent,
                            ),
                          ),
                        Text(_dayShortcuts[index]),
                      ],
                    ),
                  );
                }),
              ),
            ),

            // TabBarView Enables Horizontal Swiping/Sliding Between Days
            Expanded(
              child: timetableAsync.when(
                data: (timetableData) {
                  return TabBarView(
                    controller: _tabController,
                    children: _days.map((selectedDay) {
                      final rawSchedule =
                          (timetableData[selectedDay] as List<dynamic>?) ?? [];
                      final daySchedule = VtopHelpers.sortTimetableList(rawSchedule);

                      if (daySchedule.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.08)),
                                ),
                                child: const Icon(
                                  Icons.wb_sunny_rounded,
                                  size: 48,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No Classes Scheduled',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Enjoy your free day on $selectedDay!',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ).animate().fadeIn(duration: 300.ms),
                        );
                      }

                      return RefreshIndicator(
                        color: AppTheme.cyanAccent,
                        backgroundColor: AppTheme.surface,
                        onRefresh: () async => ref.refresh(timetableProvider.future),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: daySchedule.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                    bottom: 16, top: 4, left: 4, right: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '$selectedDay\'s Agenda',
                                      style: GoogleFonts.outfit(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.1)),
                                      ),
                                      child: Text(
                                        '${daySchedule.length} ${daySchedule.length == 1 ? 'Class' : 'Classes'}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.cyanAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final item = daySchedule[index - 1];
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

                            final statusInfo =
                                _getClassTimingStatus(time, selectedDay);
                            final isLive = statusInfo['status'] == 'LIVE NOW';
                            final isCompleted = statusInfo['status'] == 'COMPLETED';
                            final statusColor = statusInfo['color'] as Color;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: isLive
                                        ? statusColor.withValues(alpha: 0.2)
                                        : Colors.black.withValues(alpha: 0.25),
                                    blurRadius: isLive ? 20 : 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isLive
                                            ? [
                                                statusColor.withValues(alpha: 0.15),
                                                AppTheme.surface.withValues(alpha: 0.8),
                                              ]
                                            : [
                                                Colors.white.withValues(alpha: 0.07),
                                                Colors.white.withValues(alpha: 0.03),
                                              ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: isLive
                                            ? statusColor.withValues(alpha: 0.8)
                                            : isLab
                                                ? AppTheme.cyanAccent.withValues(alpha: 0.3)
                                                : Colors.white.withValues(alpha: 0.1),
                                        width: isLive ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: statusColor,
                                                      boxShadow: isLive
                                                          ? [
                                                              BoxShadow(
                                                                color: statusColor
                                                                    .withValues(
                                                                        alpha: 0.8),
                                                                blurRadius: 6,
                                                                spreadRadius: 2,
                                                              )
                                                            ]
                                                          : [],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    time,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w700,
                                                      color: isCompleted
                                                          ? const Color(0xFF94A3B8)
                                                          : statusColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  if (isLive) ...[
                                                    Container(
                                                      margin: const EdgeInsets.only(
                                                          right: 8),
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 10, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: statusColor
                                                            .withValues(alpha: 0.15),
                                                        borderRadius:
                                                            BorderRadius.circular(20),
                                                        border: Border.all(
                                                            color: statusColor.withValues(
                                                                alpha: 0.6)),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Container(
                                                            width: 6,
                                                            height: 6,
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              color: statusColor,
                                                            ),
                                                          )
                                                              .animate(
                                                                  onPlay: (c) =>
                                                                      c.repeat(reverse: true))
                                                              .scale(
                                                                  begin:
                                                                      const Offset(0.8, 0.8),
                                                                  end:
                                                                      const Offset(1.4, 1.4))
                                                              .fade(begin: 0.4, end: 1.0),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            'LIVE NOW',
                                                            style: GoogleFonts.inter(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w900,
                                                              letterSpacing: 0.5,
                                                              color: statusColor,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 9, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: isLab
                                                          ? AppTheme.cyanAccent
                                                              .withValues(alpha: 0.12)
                                                          : Colors.white
                                                              .withValues(alpha: 0.06),
                                                      borderRadius:
                                                          BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: isLab
                                                            ? AppTheme.cyanAccent
                                                                .withValues(alpha: 0.3)
                                                            : Colors.white
                                                                .withValues(alpha: 0.08),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      slot,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w700,
                                                        color: isLab
                                                            ? AppTheme.cyanAccent
                                                            : Colors.white70,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            courseName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.outfit(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                              color: isCompleted
                                                  ? Colors.white70
                                                  : Colors.white,
                                              height: 1.25,
                                            ),
                                          ),
                                          if (courseCode.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              courseCode,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.cyanAccent
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: AppTheme.cyanAccent
                                                        .withValues(alpha: 0.25),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.location_on_rounded,
                                                      size: 14,
                                                      color: AppTheme.cyanAccent,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      venue,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w700,
                                                        color: AppTheme.cyanAccent,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Spacer(),
                                              if (faculty.isNotEmpty) ...[
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.person_outline_rounded,
                                                      size: 15,
                                                      color: Color(0xFF94A3B8),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    ConstrainedBox(
                                                      constraints: const BoxConstraints(
                                                          maxWidth: 140),
                                                      child: Text(
                                                        faculty,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: GoogleFonts.inter(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                          color: const Color(0xFF94A3B8),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                                .animate(delay: (40 * index).ms)
                                .fadeIn(duration: 300.ms)
                                .slideY(
                                    begin: 0.08, end: 0, curve: Curves.easeOutCubic);
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      SizedBox(height: 16),
                      Text('Loading timetable...', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_rounded,
                            size: 52, color: AppTheme.error),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to Load Timetable',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          err.toString(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => ref.refresh(timetableProvider),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
}