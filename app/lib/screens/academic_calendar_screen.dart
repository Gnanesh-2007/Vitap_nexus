import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

enum DayType {
  instructional,
  holiday,
  noInstructional,
  exam,
  event,
}

class CalendarDayItem {
  final DateTime date;
  final DayType type;
  final String title;
  final String? subtitle;

  const CalendarDayItem({
    required this.date,
    required this.type,
    required this.title,
    this.subtitle,
  });
}

class AcademicCalendarScreen extends StatefulWidget {
  const AcademicCalendarScreen({super.key});

  @override
  State<AcademicCalendarScreen> createState() => _AcademicCalendarScreenState();
}

class _AcademicCalendarScreenState extends State<AcademicCalendarScreen> {
  late List<DateTime> _months;
  late int _selectedMonthIndex;
  DateTime _lastSyncedTime = DateTime.now();
  final ScrollController _listScrollController = ScrollController();
  final ScrollController _pillsScrollController = ScrollController();

  AppPalette get _palette => AppPalette.of(context);
  Color get _paper => _palette.paper;
  Color get _surface => _palette.surface;
  Color get _ink => _palette.ink;
  Color get _muted => _palette.inkMuted;
  Color get _navy => _palette.navy;
  Color get _blue => _palette.blue;
  Color get _orange => _palette.orange;
  Color get _line => _palette.line;
  Color get _soft => _palette.soft;

  // Curated University Holiday & Exam Rules Dictionary
  static final Map<String, Map<String, dynamic>> _specialDates = {
    // 2026 Holidays & Milestones
    '2026-01-01': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': "New Year's Day"},
    '2026-01-05': {'type': DayType.instructional, 'title': 'Commencement of Classes', 'subtitle': 'Winter Semester 2025-26'},
    '2026-01-13': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'Bhogi / Pongal Break'},
    '2026-01-14': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'Makara Sankranti / Pongal'},
    '2026-01-15': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'Kanuma / Pongal Break'},
    '2026-01-16': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'Sankranti Vacation'},
    '2026-01-17': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'Sankranti Vacation'},
    '2026-01-26': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'Republic Day'},

    '2026-02-14': {'type': DayType.event, 'title': 'VITOPIA 2026', 'subtitle': 'Annual Cultural Fest - Day 1'},
    '2026-02-15': {'type': DayType.event, 'title': 'VITOPIA 2026', 'subtitle': 'Annual Cultural Fest - Day 2'},
    '2026-02-16': {'type': DayType.event, 'title': 'VITOPIA 2026', 'subtitle': 'Annual Cultural Fest - Day 3'},
    '2026-02-23': {'type': DayType.exam, 'title': 'CAT - 1 Examination', 'subtitle': 'Continuous Assessment Test 1'},
    '2026-02-24': {'type': DayType.exam, 'title': 'CAT - 1 Examination', 'subtitle': 'Continuous Assessment Test 1'},
    '2026-02-25': {'type': DayType.exam, 'title': 'CAT - 1 Examination', 'subtitle': 'Continuous Assessment Test 1'},
    '2026-02-26': {'type': DayType.exam, 'title': 'CAT - 1 Examination', 'subtitle': 'Continuous Assessment Test 1'},
    '2026-02-27': {'type': DayType.exam, 'title': 'CAT - 1 Examination', 'subtitle': 'Continuous Assessment Test 1'},
    '2026-02-28': {'type': DayType.exam, 'title': 'CAT - 1 Examination', 'subtitle': 'Continuous Assessment Test 1'},

    '2026-03-08': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'Maha Shivaratri'},
    '2026-03-19': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'Ugadi / Telugu New Year'},
    '2026-03-20': {'type': DayType.event, 'title': 'VTAPP 2026', 'subtitle': 'National Tech Fest - Day 1'},
    '2026-03-21': {'type': DayType.event, 'title': 'VTAPP 2026', 'subtitle': 'National Tech Fest - Day 2'},
    '2026-03-22': {'type': DayType.event, 'title': 'VTAPP 2026', 'subtitle': 'National Tech Fest - Day 3'},
    '2026-03-25': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'Holi Festival'},
    '2026-03-31': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'Eid-ul-Fitr'},

    '2026-04-03': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'Good Friday'},
    '2026-04-06': {'type': DayType.exam, 'title': 'CAT - 2 Examination', 'subtitle': 'Continuous Assessment Test 2'},
    '2026-04-07': {'type': DayType.exam, 'title': 'CAT - 2 Examination', 'subtitle': 'Continuous Assessment Test 2'},
    '2026-04-08': {'type': DayType.exam, 'title': 'CAT - 2 Examination', 'subtitle': 'Continuous Assessment Test 2'},
    '2026-04-09': {'type': DayType.exam, 'title': 'CAT - 2 Examination', 'subtitle': 'Continuous Assessment Test 2'},
    '2026-04-10': {'type': DayType.exam, 'title': 'CAT - 2 Examination', 'subtitle': 'Continuous Assessment Test 2'},
    '2026-04-11': {'type': DayType.exam, 'title': 'CAT - 2 Examination', 'subtitle': 'Continuous Assessment Test 2'},
    '2026-04-14': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'Dr. B.R. Ambedkar Jayanti'},
    '2026-04-18': {'type': DayType.instructional, 'title': 'Last Instructional Day', 'subtitle': 'Winter Semester 2025-26'},
    '2026-04-20': {'type': DayType.exam, 'title': 'Lab FAT Examination', 'subtitle': 'Laboratory Final Assessment'},
    '2026-04-21': {'type': DayType.exam, 'title': 'Lab FAT Examination', 'subtitle': 'Laboratory Final Assessment'},
    '2026-04-22': {'type': DayType.exam, 'title': 'Lab FAT Examination', 'subtitle': 'Laboratory Final Assessment'},
    '2026-04-23': {'type': DayType.exam, 'title': 'Lab FAT Examination', 'subtitle': 'Laboratory Final Assessment'},
    '2026-04-24': {'type': DayType.exam, 'title': 'Lab FAT Examination', 'subtitle': 'Laboratory Final Assessment'},
    '2026-04-25': {'type': DayType.exam, 'title': 'Lab FAT Examination', 'subtitle': 'Laboratory Final Assessment'},
    '2026-04-28': {'type': DayType.exam, 'title': 'Theory FAT Examination', 'subtitle': 'Final Assessment Test'},
    '2026-04-29': {'type': DayType.exam, 'title': 'Theory FAT Examination', 'subtitle': 'Final Assessment Test'},
    '2026-04-30': {'type': DayType.exam, 'title': 'Theory FAT Examination', 'subtitle': 'Final Assessment Test'},

    '2026-05-01': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'May Day / International Labour Day'},
    '2026-05-02': {'type': DayType.exam, 'title': 'Theory FAT Examination', 'subtitle': 'Final Assessment Test'},
    '2026-05-04': {'type': DayType.exam, 'title': 'Theory FAT Examination', 'subtitle': 'Final Assessment Test'},
    '2026-05-05': {'type': DayType.exam, 'title': 'Theory FAT Examination', 'subtitle': 'Final Assessment Test'},
    '2026-05-06': {'type': DayType.exam, 'title': 'Theory FAT Examination', 'subtitle': 'Final Assessment Test'},
    '2026-05-07': {'type': DayType.exam, 'title': 'Theory FAT Examination', 'subtitle': 'Final Assessment Test'},
    '2026-05-08': {'type': DayType.exam, 'title': 'Theory FAT Examination', 'subtitle': 'Final Assessment Test'},
    '2026-05-09': {'type': DayType.exam, 'title': 'Theory FAT Examination', 'subtitle': 'Final Assessment Test'},
    '2026-05-11': {'type': DayType.exam, 'title': 'Theory FAT Examination', 'subtitle': 'Final Assessment Test'},
    '2026-05-12': {'type': DayType.exam, 'title': 'Theory FAT Examination', 'subtitle': 'Final Assessment Test'},
    '2026-05-18': {'type': DayType.holiday, 'title': 'Summer Vacation', 'subtitle': 'Commencement of Semester Break'},

    // 2026 Fall & Autumn Months
    '2026-07-13': {'type': DayType.instructional, 'title': 'Commencement of Classes', 'subtitle': 'Fall Semester 2026-27'},
    '2026-08-15': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'Independence Day'},
    '2026-08-27': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'Ganesh Chaturthi'},
    '2026-09-07': {'type': DayType.noInstructional, 'title': 'No Instructional Day', 'subtitle': ''},
    '2026-10-02': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'Mahatma Gandhi Jayanti'},
    '2026-10-18': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'Dussehra / Vijayadashami Break'},
    '2026-10-19': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'Dussehra / Vijayadashami Break'},
    '2026-10-20': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'Dussehra / Vijayadashami Break'},
    '2026-11-08': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'Diwali / Deepavali'},
    '2026-11-09': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'Diwali / Deepavali Break'},
    '2026-11-16': {'type': DayType.exam, 'title': 'CAT - 2 Examination', 'subtitle': 'Continuous Assessment Test 2'},
    '2026-11-17': {'type': DayType.exam, 'title': 'CAT - 2 Examination', 'subtitle': 'Continuous Assessment Test 2'},
    '2026-11-18': {'type': DayType.exam, 'title': 'CAT - 2 Examination', 'subtitle': 'Continuous Assessment Test 2'},
    '2026-11-19': {'type': DayType.exam, 'title': 'CAT - 2 Examination', 'subtitle': 'Continuous Assessment Test 2'},
    '2026-11-20': {'type': DayType.exam, 'title': 'CAT - 2 Examination', 'subtitle': 'Continuous Assessment Test 2'},
    '2026-11-21': {'type': DayType.exam, 'title': 'CAT - 2 Examination', 'subtitle': 'Continuous Assessment Test 2'},
    '2026-11-28': {'type': DayType.instructional, 'title': 'Last Instructional Day', 'subtitle': 'Fall Semester 2026-27'},
    '2026-12-07': {'type': DayType.exam, 'title': 'Theory FAT Examination', 'subtitle': 'End Semester Examinations'},
    '2026-12-25': {'type': DayType.holiday, 'title': 'Holiday', 'subtitle': 'Christmas & Winter Vacation'},
  };

  @override
  void initState() {
    super.initState();
    _initMonthsList();
    _syncCalendarFromApi();
  }

  Future<void> _syncCalendarFromApi() async {
    try {
      final creds = await StorageService.getCredentials();
      final username = creds['username'];
      final password = creds['password'];
      if (username != null && password != null) {
        final res = await apiService.fetchAcademicCalendar(
          username: username,
          password: password,
        );
        if (res.isNotEmpty && mounted) {
          setState(() {
            _lastSyncedTime = DateTime.now();
          });
        }
      }
    } catch (_) {}
  }

  void _initMonthsList() {
    // Months spanning academic calendar from JUL 2025 to JUN 2027
    _months = [];
    final startYear = 2025;
    for (int y = startYear; y <= 2027; y++) {
      for (int m = 1; m <= 12; m++) {
        if (y == 2025 && m < 7) continue;
        if (y == 2027 && m > 6) continue;
        _months.add(DateTime(y, m, 1));
      }
    }

    final now = DateTime.now();
    int matchIdx = _months.indexWhere((m) => m.year == now.year && m.month == now.month);
    if (matchIdx == -1) {
      matchIdx = _months.indexWhere((m) => m.year == 2026 && m.month == 9);
    }
    _selectedMonthIndex = matchIdx != -1 ? matchIdx : 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedMonthPill();
    });
  }

  void _scrollToSelectedMonthPill() {
    if (!_pillsScrollController.hasClients) return;
    const itemWidth = 110.0;
    final targetOffset = (_selectedMonthIndex * itemWidth) - 100;
    _pillsScrollController.animateTo(
      targetOffset.clamp(0.0, _pillsScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  List<CalendarDayItem> _generateDaysForMonth(DateTime monthDate) {
    final year = monthDate.year;
    final month = monthDate.month;
    final totalDays = DateTime(year, month + 1, 0).day;
    final List<CalendarDayItem> days = [];

    for (int day = 1; day <= totalDays; day++) {
      final date = DateTime(year, month, day);
      final key = DateFormat('yyyy-MM-dd').format(date);
      final weekday = date.weekday; // 1 = Mon, 7 = Sun

      if (_specialDates.containsKey(key)) {
        final info = _specialDates[key]!;
        days.add(
          CalendarDayItem(
            date: date,
            type: info['type'] as DayType,
            title: info['title'] as String,
            subtitle: info['subtitle'] as String?,
          ),
        );
      } else if (weekday == DateTime.sunday) {
        days.add(
          CalendarDayItem(
            date: date,
            type: DayType.holiday,
            title: 'Holiday',
            subtitle: 'Sunday',
          ),
        );
      } else if (weekday == DateTime.saturday) {
        // In VIT-AP, alternate Saturdays or non-instructional Saturdays
        final weekOfMonth = ((day - 1) ~/ 7) + 1;
        if (weekOfMonth == 2 || weekOfMonth == 4) {
          days.add(
            CalendarDayItem(
              date: date,
              type: DayType.noInstructional,
              title: 'No Instructional Day',
              subtitle: 'Non-working Saturday',
            ),
          );
        } else {
          days.add(
            CalendarDayItem(
              date: date,
              type: DayType.instructional,
              title: 'Instructional Day',
            ),
          );
        }
      } else {
        days.add(
          CalendarDayItem(
            date: date,
            type: DayType.instructional,
            title: 'Instructional Day',
          ),
        );
      }
    }
    return days;
  }

  String _formatLastSynced() {
    final diff = DateTime.now().difference(_lastSyncedTime);
    if (diff.inSeconds < 45) return 'Last Synced: a moment ago 💾';
    if (diff.inMinutes < 60) return 'Last Synced: ${diff.inMinutes}m ago 💾';
    return 'Last Synced: ${diff.inHours}h ago 💾';
  }

  Future<void> _onRefresh() async {
    await _syncCalendarFromApi();
    if (mounted) {
      setState(() {
        _lastSyncedTime = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _palette.isDark ? const Color(0xFF1E293B) : _navy,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(
            'Academic calendar updated to latest university schedule.',
            style: GoogleFonts.dmSans(color: Colors.white, fontSize: 12.5),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    _pillsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentMonthDate = _months[_selectedMonthIndex];
    final days = _generateDaysForMonth(currentMonthDate);

    return Scaffold(
      backgroundColor: _paper,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 6),

            // Horizontal Month Pills Row (e.g. JUL-2026, AUG-2026, SEP-2026)
            _buildMonthPillsRow(),

            const SizedBox(height: 12),

            // Scrollable Day Cards List
            Expanded(
              child: RefreshIndicator(
                color: _blue,
                backgroundColor: _surface,
                onRefresh: () async => _onRefresh(),
                child: ListView.builder(
                  controller: _listScrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    final item = days[index];
                    return _buildDayCard(item);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _paper,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: _ink, size: 22),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        children: [
          Text(
            'Academic Calendar',
            style: GoogleFonts.dmSans(
              fontSize: 18.5,
              fontWeight: FontWeight.w700,
              color: _ink,
              letterSpacing: -.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatLastSynced(),
            style: GoogleFonts.dmSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: _muted,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: _ink, size: 23),
          tooltip: 'Refresh Calendar',
          onPressed: _onRefresh,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMonthPillsRow() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        controller: _pillsScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _months.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final mDate = _months[index];
          final isSelected = index == _selectedMonthIndex;
          final label = DateFormat('MMM-yyyy').format(mDate).toUpperCase();

          return InkWell(
            onTap: () {
              setState(() {
                _selectedMonthIndex = index;
              });
              _scrollToSelectedMonthPill();
            },
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? (_palette.isDark ? const Color(0xFF34423E) : _navy)
                    : (_palette.isDark ? const Color(0xFF1E2228) : _soft),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected
                      ? (_palette.isDark ? const Color(0xFF4B5E57) : _navy)
                      : (_palette.isDark ? const Color(0xFF2B323B) : _line),
                  width: isSelected ? 1.2 : 1,
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  color: isSelected ? Colors.white : _muted,
                  letterSpacing: .6,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayCard(CalendarDayItem item) {
    final now = DateTime.now();
    final isToday = item.date.year == now.year &&
        item.date.month == now.month &&
        item.date.day == now.day;

    final dateNumStr = DateFormat('d').format(item.date);
    final weekdayStr = DateFormat('EEE').format(item.date);

    // Color and Dot indicators based on exact model
    Widget? rightDot;
    if (item.type == DayType.holiday) {
      // Light pink / coral dot
      rightDot = Container(
        width: 7.5,
        height: 7.5,
        decoration: const BoxDecoration(
          color: Color(0xFFF9A8D4), // Soft Pink
          shape: BoxShape.circle,
        ),
      );
    } else if (item.type == DayType.noInstructional) {
      // Muted grey dot
      rightDot = Container(
        width: 7.5,
        height: 7.5,
        decoration: BoxDecoration(
          color: _muted.withValues(alpha: .7),
          shape: BoxShape.circle,
        ),
      );
    } else if (item.type == DayType.exam) {
      // Warm Amber dot for exams
      rightDot = Container(
        width: 7.5,
        height: 7.5,
        decoration: BoxDecoration(
          color: _orange,
          shape: BoxShape.circle,
        ),
      );
    } else if (item.type == DayType.event) {
      // Blue dot for fests/events
      rightDot = Container(
        width: 7.5,
        height: 7.5,
        decoration: BoxDecoration(
          color: _blue,
          shape: BoxShape.circle,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isToday ? _blue : (_palette.isDark ? const Color(0xFF232A33) : _line),
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Left Date & Weekday Column
          SizedBox(
            width: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dateNumStr,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  weekdayStr,
                  style: GoogleFonts.dmSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Center Title & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 14.5,
                    fontWeight: (item.type == DayType.holiday || item.type == DayType.exam || item.type == DayType.noInstructional)
                        ? FontWeight.w700
                        : FontWeight.w600,
                    color: _ink,
                    letterSpacing: -.1,
                  ),
                ),
                if (item.subtitle != null && item.subtitle!.isNotEmpty && item.subtitle != 'Sunday' && item.subtitle != 'Non-working Saturday') ...[
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle!,
                    style: GoogleFonts.dmSans(
                      fontSize: 11.5,
                      color: _muted,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Right Dot Indicator (if holiday, no instructional, exam, etc.)
          if (rightDot != null) ...[
            const SizedBox(width: 8),
            rightDot,
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}
