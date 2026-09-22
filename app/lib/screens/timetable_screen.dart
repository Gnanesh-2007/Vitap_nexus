import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/vtop_providers.dart';
import '../utils/vtop_helpers.dart';

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

  final List<String> _dayShortcuts = [
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  late TabController _tabController;

  static const Color _background = Color(0xFFF4F2ED);
  static const Color _surface = Color(0xFFFFFEFB);
  static const Color _ink = Color(0xFF17202A);
  static const Color _inkSoft = Color(0xFF59636E);
  static const Color _muted = Color(0xFF8B939B);
  static const Color _line = Color(0xFFDCD9D2);

  static const Color _navy = Color(0xFF172B4D);
  static const Color _blue = Color(0xFF356AE6);
  static const Color _orange = Color(0xFFE47543);
  static const Color _green = Color(0xFF23835B);
  static const Color _cream = Color(0xFFEAE5DA);

  @override
  void initState() {
    super.initState();

    final today = DateFormat('EEEE').format(DateTime.now());
    var initialIndex = _days.indexOf(today);

    if (initialIndex == -1) {
      initialIndex = 0;
    }

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

  DateTime? _parseTime(String timeStr, DateTime referenceDate) {
    final cleanStr = timeStr.trim().toUpperCase();
    final formats = [
      'HH:mm',
      'H:mm',
      'hh:mm a',
      'h:mm a',
      'hh:mm',
      'h:mm',
    ];

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

  Map<String, dynamic> _getClassTimingStatus(
    String timeSlot,
    String selectedDay,
  ) {
    final now = DateTime.now();
    final today = DateFormat('EEEE').format(now);

    if (selectedDay != today) {
      return {
        'status': 'UPCOMING',
        'color': _blue,
      };
    }

    try {
      final parts = timeSlot
          .split('-')
          .map((e) => e.trim())
          .toList();

      if (parts.length != 2) {
        return {
          'status': 'SCHEDULED',
          'color': _blue,
        };
      }

      final startTime = _parseTime(parts[0], now);
      final endTime = _parseTime(parts[1], now);

      if (startTime == null || endTime == null) {
        return {
          'status': 'SCHEDULED',
          'color': _blue,
        };
      }

      if (now.isAfter(startTime) && now.isBefore(endTime)) {
        return {
          'status': 'LIVE NOW',
          'color': _green,
        };
      }

      if (now.isAfter(endTime)) {
        return {
          'status': 'COMPLETED',
          'color': _muted,
        };
      }

      return {
        'status': 'UPCOMING',
        'color': _orange,
      };
    } catch (_) {
      return {
        'status': 'SCHEDULED',
        'color': _blue,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final timetableAsync = ref.watch(timetableProvider);
    final todayName = DateFormat('EEEE').format(DateTime.now());

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 70,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ACADEMICS',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: _orange,
                letterSpacing: 1.7,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Schedule',
              style: GoogleFonts.dmSans(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: _ink,
                letterSpacing: -.8,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 4),
          _buildDaySelector(todayName),
          Expanded(
            child: timetableAsync.when(
              data: (timetableData) {
                return TabBarView(
                  controller: _tabController,
                  children: _days.map((selectedDay) {
                    final rawSchedule =
                        (timetableData[selectedDay] as List<dynamic>?) ?? [];

                    final daySchedule =
                        VtopHelpers.sortTimetableList(rawSchedule);

                    return _buildDay(
                      selectedDay,
                      daySchedule,
                    );
                  }).toList(),
                );
              },
              loading: _buildLoading,
              error: (err, stack) => _buildError(err.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector(String todayName) {
    return Container(
      height: 70,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: _navy,
          borderRadius: BorderRadius.circular(13),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: _muted,
        labelStyle: GoogleFonts.spaceGrotesk(
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: GoogleFonts.spaceGrotesk(
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        padding: EdgeInsets.zero,
        labelPadding: EdgeInsets.zero,
        tabs: List.generate(_days.length, (index) {
          final isToday = _days[index] == todayName;

          return Tab(
            height: 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _dayShortcuts[index],
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isToday ? 5 : 3,
                  height: isToday ? 5 : 3,
                  decoration: BoxDecoration(
                    color: isToday ? _orange : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDay(
    String selectedDay,
    List<dynamic> daySchedule,
  ) {
    if (daySchedule.isEmpty) {
      return ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * .48,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: _cream,
                        borderRadius: BorderRadius.circular(21),
                      ),
                      child: const Icon(
                        Icons.free_breakfast_outlined,
                        size: 29,
                        color: _inkSoft,
                      ),
                    ),
                    const SizedBox(height: 17),
                    Text(
                      'No classes scheduled',
                      style: GoogleFonts.dmSans(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enjoy your free day on $selectedDay.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 11.5,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      itemCount: daySchedule.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildAgendaHeader(
            selectedDay,
            daySchedule.length,
          );
        }

        final item = daySchedule[index - 1];
        return _buildClassCard(
          item,
          selectedDay,
          index - 1,
        );
      },
    );
  }

  Widget _buildAgendaHeader(
    String selectedDay,
    int classCount,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(1, 5, 1, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedDay.toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: _orange,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Today’s agenda',
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                    letterSpacing: -.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _line),
            ),
            child: Text(
              '$classCount ${classCount == 1 ? 'CLASS' : 'CLASSES'}',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: _navy,
                letterSpacing: .8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(
    dynamic item,
    String selectedDay,
    int index,
  ) {
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

    final statusInfo = _getClassTimingStatus(
      time,
      selectedDay,
    );

    final status = statusInfo['status'] as String;
    final statusColor = statusInfo['color'] as Color;

    final isLive = status == 'LIVE NOW';
    final isCompleted = status == 'COMPLETED';

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLive
              ? statusColor.withValues(alpha: .45)
              : _line,
          width: isLive ? 1.3 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                color: isCompleted
                    ? _line
                    : isLive
                        ? _green
                        : isLab
                            ? _orange
                            : _blue,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    15,
                    15,
                    15,
                    14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _timeBlock(
                            time,
                            statusColor,
                            isCompleted,
                          ),
                          const Spacer(),
                          if (isLive) _liveBadge(),
                          const SizedBox(width: 7),
                          _courseTypeBadge(
                            isLab ? 'LAB' : 'THEORY',
                            isLab,
                            isCompleted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        courseName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isCompleted
                              ? _inkSoft
                              : _ink,
                          height: 1.2,
                        ),
                      ),
                      if (courseCode.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          courseCode,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: _muted,
                            letterSpacing: .7,
                          ),
                        ),
                      ],
                      const SizedBox(height: 13),
                      Container(
                        height: 1,
                        color: _line,
                      ),
                      const SizedBox(height: 11),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: _background,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _line),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 12,
                                  color: isCompleted ? _muted : _navy,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  venue,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: isCompleted ? _muted : _ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (faculty.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(
                                      Icons.person_outline_rounded,
                                      size: 13,
                                      color: _muted,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      faculty,
                                      maxLines: 2,
                                      softWrap: true,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: isCompleted ? _muted : _inkSoft,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                ],
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
      ),
    )
        .animate(delay: (35 * index).ms)
        .fadeIn(duration: 280.ms)
        .slideY(
          begin: .035,
          end: 0,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _timeBlock(
    String time,
    Color statusColor,
    bool completed,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          time,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: completed ? _muted : statusColor,
            letterSpacing: .15,
          ),
        ),
      ],
    );
  }

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: _green.withValues(alpha: .24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: _green,
              shape: BoxShape.circle,
            ),
          )
              .animate(
                onPlay: (controller) =>
                    controller.repeat(reverse: true),
              )
              .scale(
                begin: const Offset(.8, .8),
                end: const Offset(1.35, 1.35),
                duration: 800.ms,
              ),
          const SizedBox(width: 5),
          Text(
            'LIVE',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 7.5,
              fontWeight: FontWeight.w900,
              color: _green,
              letterSpacing: .7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _courseTypeBadge(
    String text,
    bool isLab,
    bool completed,
  ) {
    final color = completed
        ? _muted
        : isLab
            ? _orange
            : _blue;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 7.5,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: .7,
        ),
      ),
    );
  }



  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(17),
            ),
            padding: const EdgeInsets.all(13),
            child: const CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 17),
          Text(
            'LOADING SCHEDULE',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: _ink,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 28,
                color: _orange,
              ),
            ),
            const SizedBox(height: 17),
            Text(
              'Couldn’t load timetable',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                color: _muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 21),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await refreshTimetable(ref);
                } catch (_) {}
              },
              icon: const Icon(
                Icons.refresh_rounded,
                size: 17,
              ),
              label: Text(
                'TRY AGAIN',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 19,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
