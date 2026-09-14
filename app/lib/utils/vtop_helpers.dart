class VtopHelpers {
  /// Checks if a course item is a Lab/Practical course vs Theory course
  static bool isLabCourse({
    String? courseType,
    String? courseSlot,
    String? courseTypeCode,
  }) {
    final type = (courseType ?? '').toLowerCase();
    final slot = (courseSlot ?? '').toUpperCase().trim();
    final code = (courseTypeCode ?? '').toUpperCase().trim();

    if (type.contains('lab') || type.contains('practical') || type.contains('ela') || type.contains('lo')) {
      return true;
    }
    if (code == 'ELA' || code == 'LO' || code == 'EPJ' || code == 'P') {
      return true;
    }
    // Slot checks: L1+L2, L31+L32, L5+L6, etc.
    if (slot.startsWith('L') && (slot.contains('+') || slot.length >= 2)) {
      return true;
    }
    return false;
  }

  /// Parses a time segment (e.g. "08:30 AM", "14:00", "01:30 PM") into minutes from midnight
  static int parseSingleTimeMinutes(String timePart) {
    if (timePart.isEmpty) return 0;
    try {
      final clean = timePart.trim();
      final parts = clean.split(' ');
      final digits = parts.first.split(':');
      final amPm = parts.length > 1 ? parts[1].toUpperCase() : '';

      int hour = int.parse(digits[0]);
      int minute = digits.length > 1 ? int.parse(digits[1]) : 0;

      if (amPm == 'PM' && hour < 12) {
        hour += 12;
      } else if (amPm == 'AM' && hour == 12) {
        hour = 0;
      } else if (amPm.isEmpty && hour < 8) {
        // If 24h format omitted PM (e.g. 2:00 -> 14:00)
        hour += 12;
      }

      return hour * 60 + minute;
    } catch (_) {
      return 0;
    }
  }

  /// Parses time string range like "08:30 AM - 09:20 AM" or "08:30 - 09:20"
  /// Returns Map with 'start' and 'end' in minutes from midnight
  static Map<String, int> parseTimeRange(String timeStr) {
    if (timeStr.isEmpty) return {'start': 0, 'end': 0};
    try {
      final splits = timeStr.split('-');
      if (splits.length >= 2) {
        final start = parseSingleTimeMinutes(splits[0]);
        final end = parseSingleTimeMinutes(splits[1]);
        return {'start': start, 'end': end > start ? end : start + 50};
      } else {
        final start = parseSingleTimeMinutes(splits[0]);
        return {'start': start, 'end': start + 50};
      }
    } catch (_) {
      return {'start': 0, 'end': 0};
    }
  }

  /// Sorts timetable classes strictly chronologically from morning to evening
  static List<dynamic> sortTimetableList(List<dynamic> list) {
    final sorted = List<dynamic>.from(list);
    sorted.sort((a, b) {
      final rangeA = parseTimeRange(a['time']?.toString() ?? '');
      final rangeB = parseTimeRange(b['time']?.toString() ?? '');
      return rangeA['start']!.compareTo(rangeB['start']!);
    });
    return sorted;
  }

  /// Finds the currently active class and remaining next classes for today
  static Map<String, dynamic> getLiveClassStatus(List<dynamic> sortedTodayClasses, {DateTime? customNow}) {
    final now = customNow ?? DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    Map<String, dynamic>? activeClass;
    final List<dynamic> nextClasses = [];

    for (var item in sortedTodayClasses) {
      final range = parseTimeRange(item['time']?.toString() ?? '');
      final start = range['start']!;
      final end = range['end']!;

      if (currentMinutes >= start && currentMinutes <= end) {
        activeClass = item as Map<String, dynamic>;
      } else if (currentMinutes < start) {
        nextClasses.add(item);
      }
    }

    return {
      'activeClass': activeClass,
      'nextClasses': nextClasses,
      'currentMinutes': currentMinutes,
    };
  }
}
