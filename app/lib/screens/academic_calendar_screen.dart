import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_formatter.dart';
import '../widgets/shadcn/shadcn_ui.dart';
import '../widgets/motion/nexus_motion.dart';

class AcademicCalendarScreen extends ConsumerStatefulWidget {
  const AcademicCalendarScreen({super.key});

  @override
  ConsumerState<AcademicCalendarScreen> createState() => _AcademicCalendarScreenState();
}

class _AcademicCalendarScreenState extends ConsumerState<AcademicCalendarScreen> {
  final String _selectedClassGroup = 'COMB';
  String? _selectedMonthKey;
  String _searchQuery = '';

  late Future<Map<String, dynamic>> _calendarFuture;
  Map<String, dynamic>? _cachedData;
  final TextEditingController _searchController = TextEditingController();

  AppPalette get _palette => AppPalette.of(context);
  Color get _paper => _palette.paper;
  Color get _surface => _palette.surface;
  Color get _ink => _palette.ink;
  Color get _inkSoft => _palette.inkSoft;
  Color get _muted => _palette.inkMuted;
  Color get _line => _palette.line;
  Color get _navy => _palette.navy;
  Color get _blue => _palette.blue;
  Color get _orange => _palette.orange;
  Color get _green => _palette.green;
  Color get _red => _palette.red;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    final user = auth.username;
    final semId = auth.activeSemesterId ?? '';
    final cacheKey = 'academic_calendar_${semId}_$_selectedClassGroup';
    final mem = StorageService.getMemoryCache('calendar', username: user, semesterId: semId) ??
        StorageService.getMemoryCache('academic_calendar', username: user, semesterId: semId) ??
        StorageService.getMemoryCache('academic_calendar_permanent', username: user) ??
        StorageService.getMemoryCache('academic_calendar_permanent') ??
        StorageService.getMemoryCache(cacheKey, username: user, semesterId: semId);
    if (mem is Map<String, dynamic> && mem.isNotEmpty) {
      _cachedData = Map<String, dynamic>.from(mem);
    }
    _loadFromDiskEarly();
    _fetchCalendar();
  }

  Future<void> _loadFromDiskEarly() async {
    final auth = ref.read(authProvider);
    final user = auth.username;
    final semId = auth.activeSemesterId ?? '';
    final cacheKey = 'academic_calendar_${semId}_$_selectedClassGroup';

    final disk = await StorageService.getCache('calendar', username: user, semesterId: semId) ??
        await StorageService.getCache('academic_calendar', username: user, semesterId: semId) ??
        await StorageService.getCache('academic_calendar_permanent', username: user) ??
        await StorageService.getCache('academic_calendar_permanent') ??
        await StorageService.getCache('academic_calendar') ??
        await StorageService.getCache(cacheKey, username: user, semesterId: semId);

    if (disk is Map<String, dynamic> && disk.isNotEmpty && mounted && _cachedData == null) {
      setState(() => _cachedData = Map<String, dynamic>.from(disk));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _fetchCalendar({bool forceRefresh = false}) {
    _calendarFuture = _getCalendarData(forceRefresh: forceRefresh).then((data) {
      if (mounted && data.isNotEmpty) {
        setState(() => _cachedData = data);
      }
      return data;
    });
  }

  Future<void> _onRefresh() async {
    try {
      final fresh = await _getCalendarData(forceRefresh: true);
      if (mounted && fresh.isNotEmpty) {
        setState(() => _cachedData = fresh);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No internet connection. Showing saved data.',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _palette.isDark ? const Color(0xFF1E2838) : _navy,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _getCalendarData({bool forceRefresh = false}) async {
    final auth = ref.read(authProvider);
    final user = auth.username;
    final semId = auth.activeSemesterId ?? '';
    final cacheKey = 'academic_calendar_${semId}_$_selectedClassGroup';

    if (!forceRefresh) {
      final mem = StorageService.getMemoryCache('calendar', username: user, semesterId: semId) ??
          StorageService.getMemoryCache('academic_calendar', username: user, semesterId: semId) ??
          StorageService.getMemoryCache('academic_calendar_permanent', username: user) ??
          StorageService.getMemoryCache('academic_calendar_permanent') ??
          StorageService.getMemoryCache(cacheKey, username: user, semesterId: semId);
      if (mem is Map<String, dynamic> && mem.isNotEmpty) {
        return mem;
      }
      final disk = await StorageService.getCache('calendar', username: user, semesterId: semId) ??
          await StorageService.getCache('academic_calendar', username: user, semesterId: semId) ??
          await StorageService.getCache('academic_calendar_permanent', username: user) ??
          await StorageService.getCache('academic_calendar_permanent') ??
          await StorageService.getCache('academic_calendar') ??
          await StorageService.getCache(cacheKey, username: user, semesterId: semId);
      if (disk is Map<String, dynamic> && disk.isNotEmpty) {
        return disk;
      }
    }

    try {
      final fresh = await apiService.fetchAcademicCalendar(
        username: auth.username ?? '',
        password: auth.password ?? '',
        semSubId: semId,
        classGroupId: _selectedClassGroup,
      );

      if (fresh.isNotEmpty) {
        await StorageService.setCache('calendar', fresh, username: user, semesterId: semId);
        await StorageService.setCache('academic_calendar', fresh, username: user, semesterId: semId);
        await StorageService.setCache(cacheKey, fresh, username: user, semesterId: semId);
        await StorageService.setCache('academic_calendar_permanent', fresh, username: user);
        await StorageService.setCache('academic_calendar_permanent', fresh);
        return fresh;
      }
    } catch (e) {
      debugPrint('AcademicCalendarScreen: Fetch failed ($e). Checking cache...');
      final fallback = StorageService.getMemoryCache('calendar', username: user, semesterId: semId) ??
          StorageService.getMemoryCache('academic_calendar', username: user, semesterId: semId) ??
          StorageService.getMemoryCache('academic_calendar_permanent', username: user) ??
          StorageService.getMemoryCache('academic_calendar_permanent') ??
          StorageService.getMemoryCache(cacheKey, username: user, semesterId: semId) ??
          await StorageService.getCache('calendar', username: user, semesterId: semId) ??
          await StorageService.getCache('academic_calendar', username: user, semesterId: semId) ??
          await StorageService.getCache('academic_calendar_permanent', username: user) ??
          await StorageService.getCache('academic_calendar_permanent') ??
          await StorageService.getCache('academic_calendar') ??
          await StorageService.getCache(cacheKey, username: user, semesterId: semId);
      if (fallback is Map<String, dynamic> && fallback.isNotEmpty) {
        return fallback;
      }
      return _generateDefaultCalendar();
    }

    final fallback = StorageService.getMemoryCache('calendar', username: user, semesterId: semId) ??
        StorageService.getMemoryCache('academic_calendar', username: user, semesterId: semId) ??
        StorageService.getMemoryCache('academic_calendar_permanent', username: user) ??
        StorageService.getMemoryCache('academic_calendar_permanent') ??
        StorageService.getMemoryCache(cacheKey, username: user, semesterId: semId) ??
        await StorageService.getCache('calendar', username: user, semesterId: semId) ??
        await StorageService.getCache('academic_calendar', username: user, semesterId: semId) ??
        await StorageService.getCache('academic_calendar_permanent', username: user) ??
        await StorageService.getCache('academic_calendar_permanent') ??
        await StorageService.getCache('academic_calendar') ??
        await StorageService.getCache(cacheKey, username: user, semesterId: semId);
    if (fallback is Map<String, dynamic> && fallback.isNotEmpty) {
      return fallback;
    }

    return _generateDefaultCalendar();
  }

  Map<String, dynamic> _generateDefaultCalendar() {
    final now = DateTime.now();
    final currentYear = now.year;
    final List<Map<String, dynamic>> months = [];
    final List<Map<String, dynamic>> days = [];

    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    for (int m = 1; m <= 12; m++) {
      final mName = monthNames[m - 1];
      final mAbbr = mName.substring(0, 3).toUpperCase();
      final calDate = '01-$mAbbr-$currentYear';
      months.add({
        'label': '$mName $currentYear',
        'cal_date': calDate,
      });

      final daysInMonth = DateTime(currentYear, m + 1, 0).day;
      for (int d = 1; d <= daysInMonth; d++) {
        final date = DateTime(currentYear, m, d);
        final dateStr = '$currentYear-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
        final weekdayName = DateFormat('EEEE').format(date);
        final isSunday = date.weekday == DateTime.sunday;
        final isSaturday = date.weekday == DateTime.saturday;

        final List<Map<String, dynamic>> events = [];
        if (isSunday) {
          events.add({'label': 'Holiday', 'description': 'Sunday Holiday'});
        } else if (isSaturday) {
          events.add({'label': 'Holiday', 'description': 'Weekend No Instruction'});
        } else {
          final dayOrderNum = ((d % 5) + 1);
          events.add({'label': 'WorkingDay', 'description': 'Instructional Day - Order $dayOrderNum'});
        }

        days.add({
          'date': dateStr,
          'weekday': weekdayName,
          'events': events,
        });
      }
    }

    final defaultData = {'months': months, 'days': days};
    StorageService.setCache('academic_calendar_permanent', defaultData);
    return defaultData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        backgroundColor: _paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _ink, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ACADEMIC SCHEDULE',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: _muted,
              ),
            ),
            Text(
              'Academic Calendar',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _inkSoft, size: 22),
            onPressed: () {
              HapticFeedback.selectionClick();
              _onRefresh();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: _navy,
        backgroundColor: _surface,
        onRefresh: _onRefresh,
        child: (_cachedData != null && _cachedData!.isNotEmpty)
            ? _buildCalendarContent(
                months: (_cachedData!['months'] as List<dynamic>?) ?? [],
                allDays: (_cachedData!['days'] as List<dynamic>?) ?? [],
              )
            : FutureBuilder<Map<String, dynamic>>(
                future: _calendarFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingState();
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  }

                  final data = snapshot.data ?? {};
                  final months = (data['months'] as List<dynamic>?) ?? [];
                  final days = (data['days'] as List<dynamic>?) ?? [];

                  if (days.isEmpty && months.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildCalendarContent(months: months, allDays: days);
                },
              ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.8,
              color: _navy,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Loading Academic Calendar...',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final cleanError = ErrorFormatter.cleanRawMessage(
      error,
      fallback: 'Unable to load academic calendar. Please try again.',
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: NexusErrorState(
          message: cleanError,
          onRetry: () {
            HapticFeedback.selectionClick();
            setState(() {
              _fetchCalendar(forceRefresh: true);
            });
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: NexusEmptyState(
          title: 'No Academic Calendar Found',
          description: 'VTOP has not published calendar dates for this semester yet.',
          icon: Icons.calendar_month_outlined,
        ),
      ),
    );
  }

  Widget _buildCalendarContent({
    required List<dynamic> months,
    required List<dynamic> allDays,
  }) {
    // Determine active month synced to current real-world month & year
    if (_selectedMonthKey == null && months.isNotEmpty) {
      final now = DateTime.now();
      final currentMonthAbbr = DateFormat('MMM').format(now).toUpperCase();
      final currentYearStr = now.year.toString();

      dynamic matchedMonth;
      for (final m in months) {
        if (m is Map) {
          final label = (m['label']?.toString() ?? '').toUpperCase();
          final calDate = (m['cal_date']?.toString() ?? '').toUpperCase();
          if ((label.contains(currentMonthAbbr) || calDate.contains(currentMonthAbbr)) &&
              (label.contains(currentYearStr) || calDate.contains(currentYearStr))) {
            matchedMonth = m;
            break;
          }
        }
      }

      matchedMonth ??= months.firstWhere((m) {
        if (m is Map) {
          final label = (m['label']?.toString() ?? '').toUpperCase();
          final calDate = (m['cal_date']?.toString() ?? '').toUpperCase();
          return label.contains(currentMonthAbbr) || calDate.contains(currentMonthAbbr);
        }
        return false;
      }, orElse: () => months.first);

      if (matchedMonth is Map) {
        _selectedMonthKey = matchedMonth['cal_date']?.toString() ?? matchedMonth['label']?.toString();
      }
    }

    // Filter days strictly by active month and search query
    List<dynamic> filteredDays = allDays;

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filteredDays = allDays.where((d) {
        if (d is! Map) return false;
        final events = (d['events'] as List<dynamic>?) ?? [];
        final hasEventMatch = events.any((e) {
          if (e is Map) {
            final desc = e['description']?.toString().toLowerCase() ?? '';
            final lbl = e['label']?.toString().toLowerCase() ?? '';
            return desc.contains(q) || lbl.contains(q);
          }
          return e.toString().toLowerCase().contains(q);
        });
        final date = d['date']?.toString().toLowerCase() ?? '';
        final weekday = d['weekday']?.toString().toLowerCase() ?? '';
        return hasEventMatch || date.contains(q) || weekday.contains(q);
      }).toList();
    } else if (_selectedMonthKey != null) {
      filteredDays = allDays.where((d) {
        if (d is! Map) return false;
        final rawDate = d['date']?.toString() ?? '';
        return _isDateInSelectedMonth(rawDate, _selectedMonthKey!);
      }).toList();
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _buildSearchBar(),
        const SizedBox(height: 14),
        if (_searchQuery.isEmpty && months.isNotEmpty) ...[
          _buildMonthSelector(months),
          const SizedBox(height: 16),
        ],
        _buildStatsRow(filteredDays),
        const SizedBox(height: 18),
        _buildDaysList(filteredDays),
      ],
    );
  }

  bool _isDateInSelectedMonth(String isoDate, String calDateKey) {
    if (isoDate.isEmpty || calDateKey.isEmpty) return false;

    final parsedDay = DateTime.tryParse(isoDate);

    final tokens = calDateKey.toUpperCase().split('-');
    String? targetMonth;
    int? targetYear;

    for (final t in tokens) {
      if (t.length == 3 && int.tryParse(t) == null) {
        targetMonth = t;
      } else if (t.length == 4 && int.tryParse(t) != null) {
        targetYear = int.tryParse(t);
      }
    }

    if (parsedDay != null) {
      if (targetYear != null && parsedDay.year != targetYear) {
        return false;
      }
      if (targetMonth != null) {
        final dayMonthStr = DateFormat('MMM').format(parsedDay).toUpperCase();
        return dayMonthStr == targetMonth;
      }
    }

    if (targetMonth != null) {
      return isoDate.toUpperCase().contains(targetMonth);
    }

    return false;
  }

  Widget _buildSearchBar() {
    return NexusSearchBar(
      controller: _searchController,
      hintText: 'Search exams, holidays, day orders...',
      onChanged: (val) {
        setState(() {
          _searchQuery = val;
        });
      },
      onClear: () {
        _searchController.clear();
        setState(() {
          _searchQuery = '';
        });
      },
    );
  }

  Widget _buildMonthSelector(List<dynamic> months) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: months.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final m = months[index];
          if (m is! Map) return const SizedBox.shrink();

          final label = m['label']?.toString() ?? m['cal_date']?.toString() ?? 'Month';
          final calDate = m['cal_date']?.toString() ?? label;
          final isSelected = _selectedMonthKey == calDate;

          return NexusFilterChip(
            label: label.toUpperCase(),
            isSelected: isSelected,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedMonthKey = calDate;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildStatsRow(List<dynamic> days) {
    int instructionalCount = 0;
    int holidayCount = 0;
    int examCount = 0;

    for (final d in days) {
      if (d is! Map) continue;
      final events = (d['events'] as List<dynamic>?) ?? [];
      final weekday = d['weekday']?.toString().toLowerCase() ?? '';

      bool isInst = false;
      bool isHol = weekday == 'sunday';
      bool isExam = false;

      for (final e in events) {
        final desc = (e is Map ? e['description']?.toString() : e.toString()) ?? '';
        final lbl = (e is Map ? e['label']?.toString() : '') ?? '';

        final lowerDesc = desc.toLowerCase();
        final lowerLbl = lbl.toLowerCase();

        if (lowerLbl.contains('working') || lowerDesc.contains('instructional') || lowerDesc.contains('working')) {
          isInst = true;
        }
        if (lowerLbl.contains('holiday') || lowerDesc.contains('holiday')) {
          isHol = true;
        }
        if (lowerLbl.contains('exam') ||
            lowerLbl.contains('fat') ||
            lowerLbl.contains('cat') ||
            lowerDesc.contains('cat') ||
            lowerDesc.contains('fat') ||
            lowerDesc.contains('exam') ||
            lowerDesc.contains('assessment')) {
          isExam = true;
        }
      }

      if (isInst) instructionalCount++;
      if (isHol) holidayCount++;
      if (isExam) examCount++;
    }

    return Row(
      children: [
        Expanded(
          child: _buildMiniStatCard(
            label: 'CLASSES',
            value: instructionalCount.toString(),
            color: _blue,
            icon: Icons.school_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniStatCard(
            label: 'HOLIDAYS',
            value: holidayCount.toString(),
            color: _orange,
            icon: Icons.celebration_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniStatCard(
            label: 'EXAMS',
            value: examCount.toString(),
            color: _green,
            icon: Icons.event_available_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: _muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysList(List<dynamic> days) {
    if (days.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        alignment: Alignment.center,
        child: Text(
          'No scheduled events found for this month.',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: _muted,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: days.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final day = days[index];
        if (day is! Map) return const SizedBox.shrink();

        return _buildDayCard(day, index);
      },
    );
  }

  Widget _buildDayCard(Map<dynamic, dynamic> day, int index) {
    final rawDate = day['date']?.toString() ?? '';
    final weekday = day['weekday']?.toString() ?? '';
    final events = (day['events'] as List<dynamic>?) ?? [];

    String dayNumber = '';
    String monthName = '';
    String fullFormatted = rawDate;

    final parsedDt = DateTime.tryParse(rawDate);
    final now = DateTime.now();
    final isToday = parsedDt != null &&
        parsedDt.year == now.year &&
        parsedDt.month == now.month &&
        parsedDt.day == now.day;

    if (parsedDt != null) {
      dayNumber = DateFormat('dd').format(parsedDt);
      monthName = DateFormat('MMM').format(parsedDt).toUpperCase();
      fullFormatted = DateFormat('EEEE, dd MMMM yyyy').format(parsedDt);
    } else {
      final tokens = rawDate.split('-');
      dayNumber = tokens.last;
      monthName = tokens.length > 1 ? tokens[1] : '';
    }

    bool isExam = false;
    bool isHoliday = weekday.toLowerCase() == 'sunday';
    bool isInstructional = false;
    String dayOrderTag = '';
    final List<String> eventDescriptions = [];

    for (final e in events) {
      final rawDesc = (e is Map ? e['description']?.toString() : e.toString()) ?? '';
      final rawLbl = (e is Map ? e['label']?.toString() : '') ?? '';

      final desc = _cleanEventTitle(rawDesc);
      final lbl = _cleanEventTitle(rawLbl);

      final lowerDesc = desc.toLowerCase();
      final lowerLbl = lbl.toLowerCase();

      if (lowerLbl.contains('exam') ||
          lowerLbl.contains('fat') ||
          lowerLbl.contains('cat') ||
          lowerDesc.contains('cat') ||
          lowerDesc.contains('fat') ||
          lowerDesc.contains('exam') ||
          lowerDesc.contains('assessment')) {
        isExam = true;
      }
      if (lowerLbl.contains('holiday') || lowerDesc.contains('holiday')) {
        isHoliday = true;
      }
      if (lowerLbl.contains('working') || lowerDesc.contains('instructional') || lowerDesc.contains('working')) {
        isInstructional = true;
      }

      final orderMatch = RegExp(r'Order\s*[-–]?\s*([0-9A-Za-z]+)', caseSensitive: false).firstMatch(desc.isNotEmpty ? desc : lbl);
      if (orderMatch != null) {
        dayOrderTag = 'ORDER ${orderMatch.group(1)}'.toUpperCase();
      }

      String displayStr = '';
      if (desc.isNotEmpty && lbl.isNotEmpty) {
        final lDesc = desc.toLowerCase();
        final lLbl = lbl.toLowerCase();
        if (lDesc.contains(lLbl)) {
          displayStr = desc;
        } else if (lLbl.contains(lDesc)) {
          displayStr = lbl;
        } else if (lLbl == 'exam days' || lLbl == 'workingday' || lLbl == 'holiday') {
          displayStr = desc;
        } else {
          displayStr = '$desc ($lbl)';
        }
      } else if (desc.isNotEmpty) {
        displayStr = desc;
      } else if (lbl.isNotEmpty) {
        displayStr = lbl;
      }

      if (displayStr.isNotEmpty && !eventDescriptions.contains(displayStr)) {
        eventDescriptions.add(displayStr);
      }
    }

    Color badgeColor = _muted;
    String badgeText = 'NON-INSTRUCTIONAL';

    if (isExam) {
      badgeColor = _green;
      final allText = '${eventDescriptions.join(" ")} $dayNumber $weekday'.toUpperCase();
      if (allText.contains('LAB FAT')) {
        badgeText = 'LAB FAT';
      } else if (allText.contains('FAT')) {
        badgeText = 'FAT';
      } else if (allText.contains('CAT-1') || allText.contains('CAT 1')) {
        badgeText = 'CAT-1';
      } else if (allText.contains('CAT-2') || allText.contains('CAT 2')) {
        badgeText = 'CAT-2';
      } else {
        badgeText = 'EXAM';
      }
    } else if (isHoliday) {
      badgeColor = _red;
      badgeText = 'HOLIDAY';
    } else if (dayOrderTag.isNotEmpty) {
      badgeColor = _blue;
      badgeText = dayOrderTag;
    } else if (isInstructional) {
      badgeColor = _blue;
      badgeText = 'CLASS DAY';
    }

    return AnimeStaggerItem(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: NexusCard(
          variant: NexusCardVariant.standard,
          padding: const EdgeInsets.all(14),
          borderColor: isToday
              ? _navy
              : isExam
                  ? _green.withValues(alpha: 0.35)
                  : isHoliday
                      ? _red.withValues(alpha: 0.25)
                      : _line,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date block badge
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  dayNumber,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: badgeColor,
                  ),
                ),
                Text(
                  monthName,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Details block
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              weekday.isNotEmpty ? weekday.toUpperCase() : fullFormatted,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: isToday ? _navy : _inkSoft,
                              ),
                            ),
                          ),
                          if (isToday) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _navy,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'TODAY',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (eventDescriptions.isNotEmpty) ...[
                  ...eventDescriptions.map((desc) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 3.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 5, right: 7),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: badgeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              desc,
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ] else ...[
                  Text(
                    isInstructional
                        ? 'Instructional day'
                        : (isHoliday ? 'Holiday / No classes' : 'No instructional events scheduled'),
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _inkSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
}

  String _cleanEventTitle(String text) {
    if (text.isEmpty) return '';
    var s = text.trim();
    s = s.replaceAll(RegExp(r'\(?\s*General\s*\(\s*Semester\s*\)\s*\)?', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*-\s*-\s*'), ' - ');
    s = s.replaceAll(RegExp(r'^\s*-\s*'), '');
    s = s.replaceAll(RegExp(r'\s*-\s*$'), '');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
