import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

enum CalendarCategory {
  all,
  holiday,
  exam,
  academic,
  event,
}

class AcademicEvent {
  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime? endDate;
  final CalendarCategory category;
  final String semester;
  final String? location;
  final bool isInstructional;

  const AcademicEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    this.endDate,
    required this.category,
    required this.semester,
    this.location,
    this.isInstructional = true,
  });

  bool get isMultiDay =>
      endDate != null &&
      (endDate!.year != startDate.year ||
          endDate!.month != startDate.month ||
          endDate!.day != startDate.day);
}

class AcademicCalendarScreen extends StatefulWidget {
  const AcademicCalendarScreen({super.key});

  @override
  State<AcademicCalendarScreen> createState() => _AcademicCalendarScreenState();
}

class _AcademicCalendarScreenState extends State<AcademicCalendarScreen> {
  CalendarCategory _selectedCategory = CalendarCategory.all;
  String _selectedSemester = 'Winter 2025-26';
  bool _isCalendarView = false;
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDate;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  AppPalette get _palette => AppPalette.of(context);
  Color get _paper => _palette.paper;
  Color get _surface => _palette.surface;
  Color get _ink => _palette.ink;
  Color get _inkSoft => _palette.inkSoft;
  Color get _muted => _palette.inkMuted;
  Color get _navy => _palette.navy;
  Color get _blue => _palette.blue;
  Color get _orange => _palette.orange;
  Color get _green => _palette.green;
  Color get _red => _palette.red;
  Color get _line => _palette.line;
  Color get _soft => _palette.soft;

  // Curated VIT-AP Academic Schedule
  final List<AcademicEvent> _allEvents = [
    // Winter 2025-26
    AcademicEvent(
      id: 'w26_start',
      title: 'Commencement of Classes (Winter Sem)',
      description: 'Instructional semester begins for all UG/PG undergraduate and postgraduate batches.',
      startDate: DateTime(2026, 1, 5),
      category: CalendarCategory.academic,
      semester: 'Winter 2025-26',
    ),
    AcademicEvent(
      id: 'w26_add_drop',
      title: 'Course Add / Drop Window',
      description: 'Online portal open for course adjustments, slot swaps, and registration modification.',
      startDate: DateTime(2026, 1, 8),
      endDate: DateTime(2026, 1, 12),
      category: CalendarCategory.academic,
      semester: 'Winter 2025-26',
    ),
    AcademicEvent(
      id: 'w26_sankranti',
      title: 'Pongal / Sankranti Holidays',
      description: 'University closed for Sankranti / Pongal festivities. Non-instructional break.',
      startDate: DateTime(2026, 1, 13),
      endDate: DateTime(2026, 1, 17),
      category: CalendarCategory.holiday,
      semester: 'Winter 2025-26',
      isInstructional: false,
    ),
    AcademicEvent(
      id: 'w26_republic',
      title: 'Republic Day',
      description: 'National holiday. Flag hoisting ceremony at University Central Plaza at 08:30 AM.',
      startDate: DateTime(2026, 1, 26),
      category: CalendarCategory.holiday,
      semester: 'Winter 2025-26',
      location: 'Central Plaza',
      isInstructional: false,
    ),
    AcademicEvent(
      id: 'w26_vitopia',
      title: 'VITOPIA 2026 (Annual Cultural Fest)',
      description: 'Annual inter-university cultural & arts carnival featuring music, dance, and pro-shows.',
      startDate: DateTime(2026, 2, 14),
      endDate: DateTime(2026, 2, 16),
      category: CalendarCategory.event,
      semester: 'Winter 2025-26',
      location: 'University Grounds',
    ),
    AcademicEvent(
      id: 'w26_cat1',
      title: 'Continuous Assessment Test 1 (CAT - 1)',
      description: 'First centralized written assessment for all theory courses across regular slots.',
      startDate: DateTime(2026, 2, 23),
      endDate: DateTime(2026, 2, 28),
      category: CalendarCategory.exam,
      semester: 'Winter 2025-26',
    ),
    AcademicEvent(
      id: 'w26_shivaratri',
      title: 'Maha Shivaratri',
      description: 'University holiday on occasion of Maha Shivaratri.',
      startDate: DateTime(2026, 3, 8),
      category: CalendarCategory.holiday,
      semester: 'Winter 2025-26',
      isInstructional: false,
    ),
    AcademicEvent(
      id: 'w26_vtapp',
      title: 'VTAPP 2026 (National Tech Fest)',
      description: 'Premier national technical symposium, 36-hour hackathon, robotics, and paper presentations.',
      startDate: DateTime(2026, 3, 20),
      endDate: DateTime(2026, 3, 22),
      category: CalendarCategory.event,
      semester: 'Winter 2025-26',
      location: 'Academic Blocks & Auditoriums',
    ),
    AcademicEvent(
      id: 'w26_holi',
      title: 'Holi Festival',
      description: 'University closed for the festival of colors.',
      startDate: DateTime(2026, 3, 25),
      category: CalendarCategory.holiday,
      semester: 'Winter 2025-26',
      isInstructional: false,
    ),
    AcademicEvent(
      id: 'w26_eid',
      title: 'Eid-ul-Fitr',
      description: 'University holiday observing Eid-ul-Fitr.',
      startDate: DateTime(2026, 3, 31),
      category: CalendarCategory.holiday,
      semester: 'Winter 2025-26',
      isInstructional: false,
    ),
    AcademicEvent(
      id: 'w26_cat2',
      title: 'Continuous Assessment Test 2 (CAT - 2)',
      description: 'Second centralized mid-term evaluation covering unit modules 3 to 5.',
      startDate: DateTime(2026, 4, 6),
      endDate: DateTime(2026, 4, 11),
      category: CalendarCategory.exam,
      semester: 'Winter 2025-26',
    ),
    AcademicEvent(
      id: 'w26_ambedkar',
      title: 'Dr. B.R. Ambedkar Jayanti / Tamil New Year',
      description: 'National and regional holiday. Non-instructional day.',
      startDate: DateTime(2026, 4, 14),
      category: CalendarCategory.holiday,
      semester: 'Winter 2025-26',
      isInstructional: false,
    ),
    AcademicEvent(
      id: 'w26_last_day',
      title: 'Last Instructional Day (Winter Sem)',
      description: 'Official conclusion of regular classroom teaching. Attendance cutoff locked.',
      startDate: DateTime(2026, 4, 18),
      category: CalendarCategory.academic,
      semester: 'Winter 2025-26',
    ),
    AcademicEvent(
      id: 'w26_lab_fat',
      title: 'Laboratory Final Assessment Tests (Lab FAT)',
      description: 'Practical exams and coding lab final assessments conducted across department laboratories.',
      startDate: DateTime(2026, 4, 20),
      endDate: DateTime(2026, 4, 25),
      category: CalendarCategory.exam,
      semester: 'Winter 2025-26',
    ),
    AcademicEvent(
      id: 'w26_theory_fat',
      title: 'Theory Final Assessment Tests (FAT)',
      description: 'Comprehensive end-semester university examinations across all academic schools.',
      startDate: DateTime(2026, 4, 28),
      endDate: DateTime(2026, 5, 12),
      category: CalendarCategory.exam,
      semester: 'Winter 2025-26',
    ),
    AcademicEvent(
      id: 'w26_vacation',
      title: 'Summer Vacation Begins',
      description: 'Commencement of semester break and summer internship period.',
      startDate: DateTime(2026, 5, 18),
      category: CalendarCategory.academic,
      semester: 'Winter 2025-26',
      isInstructional: false,
    ),
    AcademicEvent(
      id: 'w26_grades',
      title: 'Winter Semester Grade Declaration',
      description: 'Official publication of Winter semester GPA, course grades, and grade history on VTOP.',
      startDate: DateTime(2026, 5, 25),
      category: CalendarCategory.academic,
      semester: 'Winter 2025-26',
    ),

    // Fall 2025-26
    AcademicEvent(
      id: 'f25_start',
      title: 'Commencement of Classes (Fall Sem)',
      description: 'First instructional day for Fall semester academic courses.',
      startDate: DateTime(2025, 7, 14),
      category: CalendarCategory.academic,
      semester: 'Fall 2025-26',
    ),
    AcademicEvent(
      id: 'f25_indep',
      title: 'Independence Day',
      description: 'National holiday observing 79th Independence Day.',
      startDate: DateTime(2025, 8, 15),
      category: CalendarCategory.holiday,
      semester: 'Fall 2025-26',
      isInstructional: false,
    ),
    AcademicEvent(
      id: 'f25_ganesh',
      title: 'Ganesh Chaturthi',
      description: 'University holiday on occasion of Ganesh Chaturthi.',
      startDate: DateTime(2025, 8, 27),
      category: CalendarCategory.holiday,
      semester: 'Fall 2025-26',
      isInstructional: false,
    ),
    AcademicEvent(
      id: 'f25_cat1',
      title: 'Continuous Assessment Test 1 (CAT - 1)',
      description: 'Fall semester first continuous assessment test.',
      startDate: DateTime(2025, 9, 8),
      endDate: DateTime(2025, 9, 13),
      category: CalendarCategory.exam,
      semester: 'Fall 2025-26',
    ),
    AcademicEvent(
      id: 'f25_gandhi',
      title: 'Mahatma Gandhi Jayanti',
      description: 'National holiday observing Gandhi Jayanti.',
      startDate: DateTime(2025, 10, 2),
      category: CalendarCategory.holiday,
      semester: 'Fall 2025-26',
      isInstructional: false,
    ),
    AcademicEvent(
      id: 'f25_dussehra',
      title: 'Dussehra / Vijayadashami Break',
      description: 'Autumn festival holiday break for students and faculty.',
      startDate: DateTime(2025, 10, 18),
      endDate: DateTime(2025, 10, 22),
      category: CalendarCategory.holiday,
      semester: 'Fall 2025-26',
      isInstructional: false,
    ),
    AcademicEvent(
      id: 'f25_diwali',
      title: 'Diwali Holidays',
      description: 'Festival of lights university holiday.',
      startDate: DateTime(2025, 11, 1),
      endDate: DateTime(2025, 11, 3),
      category: CalendarCategory.holiday,
      semester: 'Fall 2025-26',
      isInstructional: false,
    ),
    AcademicEvent(
      id: 'f25_cat2',
      title: 'Continuous Assessment Test 2 (CAT - 2)',
      description: 'Fall semester second continuous assessment test.',
      startDate: DateTime(2025, 11, 10),
      endDate: DateTime(2025, 11, 15),
      category: CalendarCategory.exam,
      semester: 'Fall 2025-26',
    ),
    AcademicEvent(
      id: 'f25_last_day',
      title: 'Last Instructional Day (Fall Sem)',
      description: 'Conclusion of classroom instructions for Fall semester.',
      startDate: DateTime(2025, 11, 28),
      category: CalendarCategory.academic,
      semester: 'Fall 2025-26',
    ),
    AcademicEvent(
      id: 'f25_lab_fat',
      title: 'Laboratory FAT Exams',
      description: 'End-semester laboratory final examinations.',
      startDate: DateTime(2025, 12, 1),
      endDate: DateTime(2025, 12, 6),
      category: CalendarCategory.exam,
      semester: 'Fall 2025-26',
    ),
    AcademicEvent(
      id: 'f25_theory_fat',
      title: 'Theory Final Assessment Tests (FAT)',
      description: 'Fall semester end-term final examinations.',
      startDate: DateTime(2025, 12, 8),
      endDate: DateTime(2025, 12, 22),
      category: CalendarCategory.exam,
      semester: 'Fall 2025-26',
    ),
    AcademicEvent(
      id: 'f25_christmas',
      title: 'Christmas & Winter Recess',
      description: 'Winter vacation and Christmas holiday.',
      startDate: DateTime(2025, 12, 25),
      category: CalendarCategory.holiday,
      semester: 'Fall 2025-26',
      isInstructional: false,
    ),
  ];

  List<AcademicEvent> get _filteredEvents {
    return _allEvents.where((e) {
      if (_selectedSemester != 'All' && e.semester != _selectedSemester) {
        return false;
      }
      if (_selectedCategory != CalendarCategory.all && e.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchTitle = e.title.toLowerCase().contains(q);
        final matchDesc = e.description.toLowerCase().contains(q);
        final matchLoc = e.location?.toLowerCase().contains(q) ?? false;
        if (!matchTitle && !matchDesc && !matchLoc) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  AcademicEvent? get _nextUpcomingEvent {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = _allEvents.where((e) {
      final end = e.endDate != null ? DateTime(e.endDate!.year, e.endDate!.month, e.endDate!.day) : e.startDate;
      return !end.isBefore(today);
    }).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  Color _getCategoryColor(CalendarCategory category) {
    switch (category) {
      case CalendarCategory.holiday:
        return _green;
      case CalendarCategory.exam:
        return _red;
      case CalendarCategory.academic:
        return _blue;
      case CalendarCategory.event:
        return _orange;
      case CalendarCategory.all:
        return _navy;
    }
  }

  String _getCategoryLabel(CalendarCategory category) {
    switch (category) {
      case CalendarCategory.holiday:
        return 'HOLIDAY';
      case CalendarCategory.exam:
        return 'EXAMINATION';
      case CalendarCategory.academic:
        return 'ACADEMIC';
      case CalendarCategory.event:
        return 'EVENT / FEST';
      case CalendarCategory.all:
        return 'ALL';
    }
  }

  IconData _getCategoryIcon(CalendarCategory category) {
    switch (category) {
      case CalendarCategory.holiday:
        return Icons.beach_access_rounded;
      case CalendarCategory.exam:
        return Icons.assignment_outlined;
      case CalendarCategory.academic:
        return Icons.school_outlined;
      case CalendarCategory.event:
        return Icons.celebration_outlined;
      case CalendarCategory.all:
        return Icons.calendar_month_outlined;
    }
  }

  String _formatEventDateRange(AcademicEvent event) {
    final startFormat = DateFormat('EEE, d MMM yyyy');
    if (event.endDate == null) {
      return startFormat.format(event.startDate);
    }
    if (event.startDate.month == event.endDate!.month && event.startDate.year == event.endDate!.year) {
      return '${DateFormat('d').format(event.startDate)} – ${DateFormat('d MMM yyyy').format(event.endDate!)}';
    }
    return '${DateFormat('d MMM').format(event.startDate)} – ${DateFormat('d MMM yyyy').format(event.endDate!)}';
  }

  String _getCountdownText(DateTime targetDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'TOMORROW';
    if (diff > 1) return 'IN $diff DAYS';
    return 'PASSED';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nextEvent = _nextUpcomingEvent;
    final events = _filteredEvents;

    return Scaffold(
      backgroundColor: _paper,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Top Controls Bar: Semester Selector & View Toggle & Category Pills
            _buildFilterHeader(),

            // Main Content Area
            Expanded(
              child: _isCalendarView
                  ? _buildMonthCalendarView(events)
                  : _buildTimelineView(events, nextEvent),
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
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _line),
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: _ink),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACADEMIC CALENDAR',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: _navy,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'Milestones, Exams & Holidays',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _ink,
              letterSpacing: -.3,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: _isCalendarView ? 'Switch to Timeline' : 'Switch to Calendar',
          onPressed: () {
            setState(() {
              _isCalendarView = !_isCalendarView;
            });
          },
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _isCalendarView ? _navy : _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _isCalendarView ? _navy : _line),
            ),
            child: Icon(
              _isCalendarView ? Icons.view_timeline_rounded : Icons.calendar_month_rounded,
              size: 16,
              color: _isCalendarView ? Colors.white : _ink,
            ),
          ),
        ),
        const SizedBox(width: 14),
      ],
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      color: _paper,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search & Semester Row
          Row(
            children: [
              // Search Input
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _line),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search exams, holidays, fests...',
                      hintStyle: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        color: _muted,
                      ),
                      prefixIcon: Icon(Icons.search_rounded, size: 17, color: _muted),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, size: 15, color: _muted),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Semester Dropdown
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _line),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSemester,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _navy),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                    dropdownColor: _surface,
                    items: const [
                      DropdownMenuItem(
                        value: 'Winter 2025-26',
                        child: Text('Winter 2025-26'),
                      ),
                      DropdownMenuItem(
                        value: 'Fall 2025-26',
                        child: Text('Fall 2025-26'),
                      ),
                      DropdownMenuItem(
                        value: 'All',
                        child: Text('All Terms'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedSemester = val;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildCategoryChip(CalendarCategory.all, 'All Events'),
                _buildCategoryChip(CalendarCategory.holiday, 'Holidays'),
                _buildCategoryChip(CalendarCategory.exam, 'Exams'),
                _buildCategoryChip(CalendarCategory.academic, 'Academic'),
                _buildCategoryChip(CalendarCategory.event, 'Fests & Events'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(CalendarCategory category, String label) {
    final isSelected = _selectedCategory == category;
    final catColor = _getCategoryColor(category);

    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = category;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
          decoration: BoxDecoration(
            color: isSelected ? _navy : _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? _navy : _line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (category != CalendarCategory.all) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : catColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : _inkSoft,
                  letterSpacing: .3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineView(List<AcademicEvent> events, AcademicEvent? nextEvent) {
    if (events.isEmpty) {
      return _buildEmptyState();
    }

    // Group events by Month & Year
    final Map<String, List<AcademicEvent>> grouped = {};
    for (final e in events) {
      final key = DateFormat('MMMM yyyy').format(e.startDate).toUpperCase();
      grouped.putIfAbsent(key, () => []).add(e);
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        // Next Immediate Milestone Hero Card
        if (nextEvent != null && _searchQuery.isEmpty && _selectedCategory == CalendarCategory.all) ...[
          _buildHeroMilestoneCard(nextEvent)
              .animate()
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 18),
        ],

        // Grouped Month Sections
        ...grouped.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month Header Pill
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 10, left: 2),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: _soft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _line),
                      ),
                      child: Text(
                        entry.key,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: _navy,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: _line.withValues(alpha: .6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${entry.value.length} Events',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),

              // Month Event Cards
              ...entry.value.map((e) => _buildEventCard(e)),
              const SizedBox(height: 10),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildHeroMilestoneCard(AcademicEvent event) {
    final catColor = _getCategoryColor(event.category);
    final countdown = _getCountdownText(event.startDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _palette.isDark ? 0.3 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Badges Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: _navy.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 12, color: _navy),
                    const SizedBox(width: 4),
                    Text(
                      'NEXT UPCOMING MILESTONE',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: _navy,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: catColor.withValues(alpha: .3)),
                ),
                child: Text(
                  countdown,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: catColor,
                    letterSpacing: .5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            event.title,
            style: GoogleFonts.dmSans(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _ink,
              letterSpacing: -.3,
            ),
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            event.description,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: _inkSoft,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),

          // Date & Category Info Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _line.withValues(alpha: .7)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 13, color: _navy),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _formatEventDateRange(event),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ),
                if (!event.isInstructional)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      'No Classes',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: _green,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(AcademicEvent event) {
    final catColor = _getCategoryColor(event.category);
    final catLabel = _getCategoryLabel(event.category);
    final catIcon = _getCategoryIcon(event.category);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isPast = (event.endDate ?? event.startDate).isBefore(today);
    final isToday = (event.startDate.year == today.year &&
            event.startDate.month == today.month &&
            event.startDate.day == today.day) ||
        (event.endDate != null &&
            !event.startDate.isAfter(today) &&
            !event.endDate!.isBefore(today));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday ? _navy : _line,
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Badge Column
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isToday
                  ? _navy
                  : (isPast ? _soft : catColor.withValues(alpha: .1)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isToday
                    ? _navy
                    : (isPast ? _line : catColor.withValues(alpha: .3)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('MMM').format(event.startDate).toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: isToday ? Colors.white70 : (isPast ? _muted : catColor),
                    letterSpacing: .5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd').format(event.startDate),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isToday ? Colors.white : (isPast ? _muted : _ink),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEE').format(event.startDate).toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    color: isToday ? Colors.white60 : _muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Event Info Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category & Timing Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(catIcon, size: 10.5, color: catColor),
                          const SizedBox(width: 3.5),
                          Text(
                            catLabel,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: catColor,
                              letterSpacing: .4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _navy,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'TODAY',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: .5,
                          ),
                        ),
                      )
                    else if (isPast)
                      Text(
                        'Completed',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: _muted,
                        ),
                      )
                    else
                      Text(
                        _getCountdownText(event.startDate),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: _navy,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // Event Title
                Text(
                  event.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isPast ? _inkSoft : _ink,
                    letterSpacing: -.2,
                  ),
                ),
                const SizedBox(height: 4),

                // Event Description
                Text(
                  event.description,
                  style: GoogleFonts.dmSans(
                    fontSize: 11.5,
                    color: _muted,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Additional details bar
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 11.5, color: _muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _formatEventDateRange(event),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: _inkSoft,
                        ),
                      ),
                    ),
                    if (event.location != null) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.place_outlined, size: 11.5, color: _muted),
                      const SizedBox(width: 3),
                      Text(
                        event.location!,
                        style: GoogleFonts.dmSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: _inkSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCalendarView(List<AcademicEvent> events) {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startingWeekday = firstDay.weekday; // 1 = Mon, 7 = Sun

    // Filter events for selected date or focused month
    final monthEvents = events.where((e) {
      final inStart = e.startDate.year == year && e.startDate.month == month;
      final inEnd = e.endDate != null && e.endDate!.year == year && e.endDate!.month == month;
      return inStart || inEnd;
    }).toList();

    final selectedDayEvents = _selectedDate != null
        ? events.where((e) {
            final target = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
            final s = DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
            final end = e.endDate != null
                ? DateTime(e.endDate!.year, e.endDate!.month, e.endDate!.day)
                : s;
            return !target.isBefore(s) && !target.isAfter(end);
          }).toList()
        : monthEvents;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        // Month Navigation Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line),
          ),
          child: Column(
            children: [
              // Month Header Row with Prev / Next Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left_rounded, color: _ink),
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
                        _selectedDate = null;
                      });
                    },
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(_focusedMonth),
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right_rounded, color: _ink),
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
                        _selectedDate = null;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Weekday Headers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                  return SizedBox(
                    width: 34,
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: _muted,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),

              // Calendar Days Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 42, // 6 weeks max
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final dayOffset = index - (startingWeekday - 1);
                  if (dayOffset < 0 || dayOffset >= daysInMonth) {
                    return const SizedBox();
                  }

                  final day = dayOffset + 1;
                  final currentDayDate = DateTime(year, month, day);
                  final isToday = DateTime.now().year == year &&
                      DateTime.now().month == month &&
                      DateTime.now().day == day;
                  final isSelected = _selectedDate != null &&
                      _selectedDate!.year == year &&
                      _selectedDate!.month == month &&
                      _selectedDate!.day == day;

                  // Find events on this day
                  final dayEvents = events.where((e) {
                    final s = DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
                    final end = e.endDate != null
                        ? DateTime(e.endDate!.year, e.endDate!.month, e.endDate!.day)
                        : s;
                    return !currentDayDate.isBefore(s) && !currentDayDate.isAfter(end);
                  }).toList();

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedDate = currentDayDate;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _navy
                            : (isToday ? _navy.withValues(alpha: .12) : Colors.transparent),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? _navy
                              : (isToday ? _navy : Colors.transparent),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              fontWeight: isToday || isSelected ? FontWeight.w900 : FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : (isToday ? _navy : _ink),
                            ),
                          ),
                          if (dayEvents.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: dayEvents.take(3).map((e) {
                                return Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                        : _getCategoryColor(e.category),
                                    shape: BoxShape.circle,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Selected Day / Month Events Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedDate != null
                  ? 'EVENTS ON ${DateFormat('d MMMM yyyy').format(_selectedDate!).toUpperCase()}'
                  : 'ALL EVENTS IN ${DateFormat('MMMM yyyy').format(_focusedMonth).toUpperCase()}',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: _navy,
                letterSpacing: 1.1,
              ),
            ),
            if (_selectedDate != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedDate = null;
                  });
                },
                child: Text(
                  'Show All Month',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _blue,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Selected Events List
        if (selectedDayEvents.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _line),
            ),
            child: Text(
              'No scheduled university events on this day.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: _muted,
              ),
            ),
          )
        else
          ...selectedDayEvents.map((e) => _buildEventCard(e)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _soft,
                shape: BoxShape.circle,
                border: Border.all(color: _line),
              ),
              child: Icon(Icons.event_busy_rounded, size: 36, color: _muted),
            ),
            const SizedBox(height: 16),
            Text(
              'No Events Found',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try changing your search query, semester, or category filter.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                color: _muted,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedCategory = CalendarCategory.all;
                  _selectedSemester = 'Winter 2025-26';
                });
              },
              icon: Icon(Icons.restart_alt_rounded, size: 16, color: _navy),
              label: Text(
                'Reset Filters',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
