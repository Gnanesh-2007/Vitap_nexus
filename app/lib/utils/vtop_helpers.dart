import 'package:intl/intl.dart';

/// Where a class sits relative to the current moment.
enum ClassPhase { completed, ongoing, upcoming }

/// A timetable slot map resolved against a concrete calendar date.
/// Mirrors `ClassOccurrence` from the reference VIT-AP Student App.
class ClassOccurrence {
  final Map<String, dynamic> info;
  final DateTime date;
  final DateTime? start;
  final DateTime? end;

  const ClassOccurrence({
    required this.info,
    required this.date,
    this.start,
    this.end,
  });

  factory ClassOccurrence.on(DateTime date, Map<String, dynamic> info) {
    final (rawStart, rawEnd) = VtopHelpers.extractStartEndTimes(info);
    return ClassOccurrence(
      info: info,
      date: date,
      start: VtopHelpers.parseClassTime(rawStart, onDate: date),
      end: VtopHelpers.parseClassTime(rawEnd, onDate: date),
    );
  }

  String get courseCode => (info['course_code'] ?? '').toString().trim();
  String get courseName =>
      (info['course_name'] ?? info['course_title'] ?? 'Class')
          .toString()
          .trim();
  String get courseType => (info['course_type'] ?? '').toString().trim();
  String get slot => VtopHelpers.cleanSlot(info['slot']?.toString());
  String get venue =>
      (info['venue'] ?? info['room_no'] ?? '').toString().trim();
  String get faculty => (info['faculty'] ?? '').toString().trim();

  String get startTime {
    final (s, _) = VtopHelpers.extractStartEndTimes(info);
    return s;
  }

  String get endTime {
    final (_, e) = VtopHelpers.extractStartEndTimes(info);
    return e;
  }

  /// Stable identity for animation keys.
  String get key =>
      '${info['id'] ?? '$courseCode-$slot-$startTime'}@${date.day}-${date.month}';

  /// Minutes past midnight, used purely to order a day's slots. Slots VTOP gave
  /// us no usable time for sort last instead of jumping to the top of the list.
  int get sortKey =>
      start == null ? 1 << 30 : start!.hour * 60 + start!.minute;

  ClassPhase phaseAt(DateTime now) {
    if (start == null || end == null) return ClassPhase.upcoming;
    if (now.isBefore(start!)) return ClassPhase.upcoming;
    if (now.isAfter(end!)) return ClassPhase.completed;
    return ClassPhase.ongoing;
  }

  /// Time until this class ends, or `null` when it can't be measured.
  Duration? remainingAt(DateTime now) {
    if (end == null) return null;
    final Duration left = end!.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Time until this class starts, or `null` when it can't be measured.
  Duration? startsInAt(DateTime now) {
    if (start == null) return null;
    final Duration until = start!.difference(now);
    return until.isNegative ? Duration.zero : until;
  }

  /// How far through the class we are, `0..1`, or `null` when unmeasurable.
  double? progressAt(DateTime now) {
    if (start == null || end == null) return null;
    final int total = end!.difference(start!).inSeconds;
    if (total <= 0) return null;
    return (now.difference(start!).inSeconds / total).clamp(0.0, 1.0);
  }
}

/// Utility class to categorize and extract course types from marks/timetable data.
/// Mirrors `CourseTypeHelper` from the reference VIT-AP Student App.
class CourseTypeHelper {
  static const String theory = 'Theory';
  static const String lab = 'Lab';
  static const String project = 'Project';

  static String getCourseCategory(String courseType) {
    final lowerCaseType = courseType.toLowerCase().trim();
    final upperCaseType = courseType.toUpperCase().trim();

    if (upperCaseType == 'ETH' || upperCaseType == 'TH') {
      return theory;
    } else if (upperCaseType == 'ELA' || upperCaseType == 'LO') {
      return lab;
    } else if (upperCaseType == 'EPJ' ||
        upperCaseType == 'PJ' ||
        upperCaseType == 'PJT') {
      return project;
    }

    if (lowerCaseType.contains('theory')) {
      return theory;
    } else if (lowerCaseType.contains('lab') ||
        lowerCaseType.contains('practical')) {
      return lab;
    } else if (lowerCaseType.contains('project')) {
      return project;
    }

    return courseType.trim().isEmpty ? theory : courseType.trim();
  }

  static List<String> getUniqueCourseCategories(List<String> courseTypes) {
    final Set<String> categories = {};
    for (final type in courseTypes) {
      if (type.trim().isNotEmpty) {
        categories.add(getCourseCategory(type));
      }
    }

    final orderedCategories = <String>[];
    if (categories.contains(theory)) {
      orderedCategories.add(theory);
      categories.remove(theory);
    }
    if (categories.contains(lab)) {
      orderedCategories.add(lab);
      categories.remove(lab);
    }
    if (categories.contains(project)) {
      orderedCategories.add(project);
      categories.remove(project);
    }
    orderedCategories.addAll(categories.toList()..sort());
    return orderedCategories;
  }

  static bool matchesCategory(String courseType, String category) {
    return getCourseCategory(courseType) == category;
  }
}

class VtopHelpers {
  /// Checks if a course item is a Lab/Practical course vs Theory course
  static bool isLabCourse({
    String? courseType,
    String? courseSlot,
    String? courseTypeCode,
  }) {
    final type = (courseType ?? '').toLowerCase().trim();
    final slot = cleanSlot(courseSlot).toUpperCase();
    final code = (courseTypeCode ?? '').toUpperCase().trim();

    if (type == 'ela' ||
        type == 'lo' ||
        type.contains('lab') ||
        type.contains('practical')) {
      return true;
    }
    if (code == 'ELA' || code == 'LO' || code == 'EPJ' || code == 'P') {
      return true;
    }
    if (slot.startsWith('L') && (slot.contains('+') || slot.length >= 2)) {
      return true;
    }
    return false;
  }

  /// Cleans trailing `" -"` or `"-"` emitted by VTOP timetable parser on slots.
  static String cleanSlot(String? rawSlot) {
    if (rawSlot == null) return '';
    var s = rawSlot.trim();
    while (s.endsWith('-')) {
      s = s.substring(0, s.length - 1).trim();
    }
    return s;
  }

  /// Extracts `(startTime, endTime)` from a timetable item map, supporting both
  /// `start_time`/`end_time` (from Rust `TimetableClass`) and legacy `time`.
  static (String, String) extractStartEndTimes(Map<String, dynamic> item) {
    final start = (item['start_time'] ?? item['startTime'] ?? '')
        .toString()
        .trim();
    final end = (item['end_time'] ?? item['endTime'] ?? '').toString().trim();
    if (start.isNotEmpty || end.isNotEmpty) {
      return (start == '-' ? '' : start, end == '-' ? '' : end);
    }
    final combined = (item['time'] ?? '').toString().trim();
    if (combined.isNotEmpty && combined.contains('-')) {
      final parts = combined.split('-');
      final s = parts.first.trim();
      final e = parts.sublist(1).join('-').trim();
      return (s == '-' ? '' : s, e == '-' ? '' : e);
    }
    return (combined == '-' ? '' : combined, '');
  }

  /// Safely parses a `HH:mm` (or `h:mm a`) time into a [DateTime] anchored to
  /// [onDate] — today when omitted. Returns `null` for anything that isn't a
  /// valid time, including the `"-"` placeholder VTOP emits for empty cells.
  static DateTime? parseClassTime(String? timeString, {DateTime? onDate}) {
    if (timeString == null) return null;
    final clean = timeString.trim();
    if (clean.isEmpty || clean == '-') return null;

    final spaceParts = clean.split(RegExp(r'\s+'));
    final hmParts = spaceParts.first.split(':');
    if (hmParts.length != 2) return null;

    int? hour = int.tryParse(hmParts[0].trim());
    final int? minute = int.tryParse(hmParts[1].trim());
    if (hour == null || minute == null) return null;

    if (spaceParts.length > 1) {
      final amPm = spaceParts[1].toUpperCase();
      if (amPm == 'PM' && hour < 12) {
        hour += 12;
      } else if (amPm == 'AM' && hour == 12) {
        hour = 0;
      }
    }

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    final anchor = onDate ?? DateTime.now();
    return DateTime(anchor.year, anchor.month, anchor.day, hour, minute);
  }

  /// Formats a `HH:mm` string into 12-hour form, e.g. `"9:00 AM"`.
  static String formatTo12Hour(String? timeString) {
    if (timeString == null || timeString.trim().isEmpty) {
      return '';
    }
    final dt = parseClassTime(timeString);
    if (dt == null) {
      return timeString.trim() == '-' ? '' : timeString.trim();
    }
    return DateFormat('h:mm a').format(dt);
  }

  /// Formats a `start – end` time range in 12-hour form, e.g. `"9:00 AM - 9:50 AM"`.
  static String formatTimeRange(String? startTime, String? endTime) {
    final start = formatTo12Hour(startTime);
    final end = formatTo12Hour(endTime);
    if (start.isEmpty) return end;
    if (end.isEmpty) return start;
    return '$start - $end';
  }

  /// Formats the time range directly from a timetable item map.
  static String formatItemTimeRange(Map<String, dynamic> item) {
    final (start, end) = extractStartEndTimes(item);
    return formatTimeRange(start, end);
  }

  /// Compact duration for the `"22m left"` / `"IN 1H 15M"` readouts.
  static String formatShortDuration(Duration duration) {
    if (duration.inMinutes < 1) return '<1m';
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  /// Every class scheduled on [date], ordered chronologically by start time.
  static List<ClassOccurrence> classesOn(
    Map<String, dynamic> timetable,
    DateTime date,
  ) {
    final String weekday = DateFormat('EEEE').format(date);
    final rawList = getClassesForDay(timetable, weekday);
    final classes = rawList
        .whereType<Map>()
        .map((m) => ClassOccurrence.on(date, Map<String, dynamic>.from(m)))
        .toList();
    classes.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return classes;
  }

  /// Parses a single time string (e.g. "09:00", "14:00", "08:30 AM") into minutes from midnight.
  static int parseSingleTimeMinutes(String timePart) {
    final dt = parseClassTime(timePart);
    if (dt == null) return 0;
    return dt.hour * 60 + dt.minute;
  }

  /// Parses time string range like "08:30 AM - 09:20 AM" or "09:00 - 09:50"
  /// Returns Map with 'start' and 'end' in minutes from midnight.
  static Map<String, int> parseTimeRange(String timeStr) {
    if (timeStr.trim().isEmpty) return {'start': 0, 'end': 0};
    try {
      final splits = timeStr.split('-');
      if (splits.length >= 2) {
        final startDt = parseClassTime(splits[0]);
        final endDt = parseClassTime(splits[1]);
        if (startDt == null) return {'start': 0, 'end': 0};
        final start = startDt.hour * 60 + startDt.minute;
        final end = endDt != null
            ? (endDt.hour * 60 + endDt.minute)
            : (start + 50);
        return {'start': start, 'end': end > start ? end : start + 50};
      } else {
        final startDt = parseClassTime(splits[0]);
        if (startDt == null) return {'start': 0, 'end': 0};
        final start = startDt.hour * 60 + startDt.minute;
        return {'start': start, 'end': start + 50};
      }
    } catch (_) {
      return {'start': 0, 'end': 0};
    }
  }

  /// Parses time range from a timetable class Map (supports `start_time`/`end_time` and `time`).
  static Map<String, int> parseItemTimeRange(Map<String, dynamic> item) {
    final (rawStart, rawEnd) = extractStartEndTimes(item);
    final startDt = parseClassTime(rawStart);
    final endDt = parseClassTime(rawEnd);
    if (startDt == null) return {'start': 1 << 30, 'end': 1 << 30};
    final start = startDt.hour * 60 + startDt.minute;
    final end = endDt != null ? (endDt.hour * 60 + endDt.minute) : (start + 50);
    return {'start': start, 'end': end >= start ? end : start + 50};
  }

  /// Resolves classes for a given day name with case-insensitivity and prefix matching
  static List<dynamic> getClassesForDay(
    Map<String, dynamic> timetable,
    String dayName,
  ) {
    if (timetable.isEmpty) return [];
    if (timetable.containsKey(dayName) && timetable[dayName] is List) {
      return timetable[dayName] as List<dynamic>;
    }
    for (var entry in timetable.entries) {
      if (entry.key.trim().toLowerCase() == dayName.trim().toLowerCase() &&
          entry.value is List) {
        return entry.value as List<dynamic>;
      }
    }
    final prefix = dayName.length >= 3
        ? dayName.substring(0, 3).toLowerCase()
        : dayName.toLowerCase();
    for (var entry in timetable.entries) {
      if (entry.key.trim().toLowerCase().startsWith(prefix) &&
          entry.value is List) {
        return entry.value as List<dynamic>;
      }
    }
    return [];
  }

  /// Sorts timetable classes strictly chronologically from morning to evening
  static List<dynamic> sortTimetableList(List<dynamic> list) {
    final sorted = List<dynamic>.from(list);
    sorted.sort((a, b) {
      final mapA = a is Map
          ? Map<String, dynamic>.from(a)
          : <String, dynamic>{};
      final mapB = b is Map
          ? Map<String, dynamic>.from(b)
          : <String, dynamic>{};
      final rangeA = parseItemTimeRange(mapA);
      final rangeB = parseItemTimeRange(mapB);
      return rangeA['start']!.compareTo(rangeB['start']!);
    });
    return sorted;
  }

  /// Finds the currently active class and remaining next classes for today
  static Map<String, dynamic> getLiveClassStatus(
    List<dynamic> sortedTodayClasses, {
    DateTime? customNow,
  }) {
    final now = customNow ?? DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    Map<String, dynamic>? activeClass;
    final List<dynamic> nextClasses = [];

    for (var item in sortedTodayClasses) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final occ = ClassOccurrence.on(now, map);
      final phase = occ.phaseAt(now);
      if (phase == ClassPhase.ongoing) {
        activeClass = map;
      } else if (phase == ClassPhase.upcoming) {
        nextClasses.add(map);
      }
    }

    return {
      'activeClass': activeClass,
      'nextClasses': nextClasses,
      'currentMinutes': currentMinutes,
    };
  }

  /// Extracts the student's calling name (middle name or given name) from full name.
  static String extractCallingName(
    String? rawName, [
    String? fallbackUsername,
  ]) {
    if (rawName == null || rawName.trim().isEmpty) {
      if (fallbackUsername != null && fallbackUsername.trim().isNotEmpty) {
        return _formatNameToken(fallbackUsername.trim());
      }
      return 'Student';
    }

    final cleaned = rawName.replaceAll(RegExp(r'[_,\-\/\\]+'), ' ').trim();
    final tokens = cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    if (tokens.isEmpty) {
      if (fallbackUsername != null && fallbackUsername.trim().isNotEmpty) {
        return _formatNameToken(fallbackUsername.trim());
      }
      return 'Student';
    }

    final nonTitles = tokens.where((token) {
      final upper = token.replaceAll('.', '').toUpperCase().trim();
      return !const {'DR', 'MR', 'MS', 'MRS', 'PROF'}.contains(upper);
    }).toList();

    final pool = nonTitles.isNotEmpty ? nonTitles : tokens;

    if (pool.length >= 3) {
      return _formatNameToken(pool[1]);
    } else if (pool.length == 2) {
      return _formatNameToken(pool[1]);
    } else {
      return _formatNameToken(pool[0]);
    }
  }

  static String _formatNameToken(String token) {
    if (token.isEmpty) return 'Student';
    if (RegExp(r'^\d{2}[A-Za-z]{3}\d{4,5}$').hasMatch(token)) {
      return token.toUpperCase();
    }
    final lower = token.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }
}
