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
  final Set<String> _expandedCardIds = {};
  bool _isCompletedSectionExpanded = false;

  static const Color _background = Color(0xFFF4F2ED);
  static const Color _paper = Color(0xFFF4F2ED);
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
  static const Color _soft = Color(0xFFF0EEE8);

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

  void _toggleCardExpanded(String cardId) {
    setState(() {
      if (_expandedCardIds.contains(cardId)) {
        _expandedCardIds.remove(cardId);
      } else {
        _expandedCardIds.add(cardId);
      }
    });
  }

  String _getCardId(Map<String, dynamic> item, String day) {
    final code = item['course_code'] ?? '';
    final slot = item['slot'] ?? '';
    final time = item['time'] ?? '';
    final name = item['course_name'] ?? item['course_title'] ?? '';
    return '$day-$code-$slot-$time-$name';
  }

  double _calculateLiveProgress(String timeStr) {
    try {
      final range = VtopHelpers.parseTimeRange(timeStr);
      final startMin = range['start']!;
      final endMin = range['end']!;
      if (endMin <= startMin) return 0.0;

      final now = DateTime.now();
      final currentMin = now.hour * 60 + now.minute;

      if (currentMin < startMin) return 0.0;
      if (currentMin >= endMin) return 1.0;

      return (currentMin - startMin) / (endMin - startMin);
    } catch (_) {
      return 0.0;
    }
  }

  String _getCountdownText(String timeStr) {
    if (timeStr.isEmpty) return 'SCHEDULED';
    try {
      final range = VtopHelpers.parseTimeRange(timeStr);
      final startMin = range['start']!;
      final endMin = range['end']!;

      final now = DateTime.now();
      final currentMin = now.hour * 60 + now.minute;

      if (currentMin >= startMin && currentMin <= endMin) {
        final remaining = endMin - currentMin;
        return '$remaining MINS LEFT';
      } else if (currentMin < startMin) {
        final diff = startMin - currentMin;
        final h = diff ~/ 60;
        final m = diff % 60;
        if (h > 0) {
          return 'IN ${h}H ${m}M';
        } else {
          return 'IN ${m}M';
        }
      } else {
        return 'COMPLETED';
      }
    } catch (_) {
      return 'SCHEDULED';
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

    final todayName = DateFormat('EEEE').format(DateTime.now());
    final isToday = selectedDay == todayName;

    if (!isToday) {
      // Standard schedule list for other days
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

          final item = daySchedule[index - 1] as Map<String, dynamic>;
          return _buildClassCard(
            item,
            selectedDay,
            index - 1,
            isToday: false,
          );
        },
      );
    }

    // Today's schedule: Group into Live, Upcoming, Completed
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final List<Map<String, dynamic>> liveClasses = [];
    final List<Map<String, dynamic>> upcomingClasses = [];
    final List<Map<String, dynamic>> completedClasses = [];

    for (var c in daySchedule) {
      final item = c as Map<String, dynamic>;
      final range = VtopHelpers.parseTimeRange(item['time']?.toString() ?? '');
      final start = range['start']!;
      final end = range['end']!;

      if (currentMinutes >= start && currentMinutes <= end) {
        liveClasses.add(item);
      } else if (currentMinutes < start) {
        upcomingClasses.add(item);
      } else {
        completedClasses.add(item);
      }
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        _buildAgendaHeader(selectedDay, daySchedule.length),

        // 1. Live Now Section
        if (liveClasses.isNotEmpty) ...[
          _buildSubSectionTitle('HAPPENING NOW', _green),
          const SizedBox(height: 8),
          ...liveClasses.map((item) => _buildClassCard(
                item,
                selectedDay,
                0,
                isToday: true,
                isLive: true,
              )),
          const SizedBox(height: 16),
        ],

        // 2. Upcoming Classes Section
        if (upcomingClasses.isNotEmpty) ...[
          _buildSubSectionTitle('UPCOMING CLASSES', _orange),
          const SizedBox(height: 8),
          ...upcomingClasses.map((item) => _buildClassCard(
                item,
                selectedDay,
                0,
                isToday: true,
                isUpcoming: true,
              )),
          const SizedBox(height: 16),
        ],

        // 3. Completed Section (Moves completed classes here!)
        if (completedClasses.isNotEmpty) ...[
          InkWell(
            onTap: () {
              setState(() {
                _isCompletedSectionExpanded = !_isCompletedSectionExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: _green),
                  const SizedBox(width: 8),
                  Text(
                    'Completed Classes (${completedClasses.length})',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _inkSoft,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isCompletedSectionExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: _muted,
                  ),
                ],
              ),
            ),
          ),
          if (_isCompletedSectionExpanded) ...[
            const SizedBox(height: 8),
            ...completedClasses.map((item) => _buildClassCard(
                  item,
                  selectedDay,
                  0,
                  isToday: true,
                  isCompleted: true,
                )),
          ],
        ],
      ],
    );
  }

  Widget _buildSubSectionTitle(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 1.2,
          ),
        ),
      ],
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
                  'Day Agenda',
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
    Map<String, dynamic> item,
    String selectedDay,
    int index, {
    bool isToday = false,
    bool isLive = false,
    bool isUpcoming = false,
    bool isCompleted = false,
  }) {
    final cardId = _getCardId(item, selectedDay);
    final isExpanded = _expandedCardIds.contains(cardId);

    final courseName = item['course_name'] ?? item['course_title'] ?? 'Class';
    final courseCode = item['course_code'] ?? '';
    final time = item['time'] ?? '';
    final slot = item['slot'] ?? '';
    final venue = item['venue'] ?? item['room_no'] ?? 'TBA';
    final faculty = item['faculty'] ?? '';
    final courseType = item['course_type'] ?? '';

    final isLab = VtopHelpers.isLabCourse(
      courseType: courseType,
      courseSlot: slot,
    );

    final countdown = isToday ? _getCountdownText(time) : '';
    final progress = isLive ? _calculateLiveProgress(time) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      child: InkWell(
        onTap: () => _toggleCardExpanded(cardId),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isCompleted ? _paper : _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isLive ? _green.withValues(alpha: .5) : _line,
              width: isLive ? 1.4 : 1,
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
                      padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Meta Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _timeBlock(
                                time,
                                isLive
                                    ? _green
                                    : (isCompleted ? _muted : _navy),
                                isCompleted,
                              ),
                              const Spacer(),
                              if (isLive) ...[
                                _liveBadge(),
                                const SizedBox(width: 6),
                              ] else if (isUpcoming && countdown.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _orange.withValues(alpha: .12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    countdown,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      color: _orange,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ] else if (isCompleted) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _soft,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'COMPLETED',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              _courseTypeBadge(
                                isLab ? 'LAB' : 'THEORY',
                                isLab,
                                isCompleted,
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Course Title
                          Text(
                            courseName,
                            maxLines: isExpanded ? 4 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isCompleted ? _inkSoft : _ink,
                              height: 1.2,
                            ),
                          ),

                          // ========================================================
                          // LIVE PROGRESS BAR
                          // ========================================================
                          if (isLive) ...[
                            const SizedBox(height: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'CLASS PROGRESS',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: _green,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    Text(
                                      '${(progress * 100).toInt()}% • $countdown',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: _green,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: Stack(
                                    children: [
                                      Container(
                                        height: 5,
                                        width: double.infinity,
                                        color: _green.withValues(alpha: 0.15),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: progress.clamp(0.01, 1.0),
                                        child: Container(
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: _green,
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],

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
                            children: [
                              Expanded(
                                child: _detail(
                                  Icons.location_on_outlined,
                                  venue,
                                  isCompleted ? _muted : _navy,
                                ),
                              ),
                              if (faculty.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _detail(
                                    Icons.person_outline_rounded,
                                    faculty,
                                    _muted,
                                  ),
                                ),
                              ],
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: _muted,
                              ),
                            ],
                          ),

                          // Inline Expanded Extra Info
                          if (isExpanded) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _line),
                              ),
                              child: Column(
                                children: [
                                  _inlineRow(Icons.access_time_rounded, 'Timings', time),
                                  const Divider(height: 12, color: _line),
                                  _inlineRow(Icons.location_on_outlined, 'Room', venue),
                                  if (slot.isNotEmpty) ...[
                                    const Divider(height: 12, color: _line),
                                    _inlineRow(Icons.grid_view_rounded, 'Slot', slot),
                                  ],
                                  if (faculty.isNotEmpty) ...[
                                    const Divider(height: 12, color: _line),
                                    _inlineRow(Icons.person_outline_rounded, 'Faculty', faculty),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inlineRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 13, color: _navy),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: _inkSoft,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ),
      ],
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
        vertical: 4,
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
        vertical: 4,
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

  Widget _detail(
    IconData icon,
    String text,
    Color color,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color == _navy ? _inkSoft : color,
            ),
          ),
        ),
      ],
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
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'LOADING SCHEDULE',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: _navy,
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
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.sync_problem_rounded,
                color: _orange,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Couldn’t load schedule',
              style: GoogleFonts.dmSans(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                color: _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
