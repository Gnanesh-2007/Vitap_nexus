import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/attendance_calculator.dart';
import '../utils/vtop_helpers.dart';

/// Publishes a compact snapshot of timetable / attendance / exam data for the
/// Android home-screen widgets.
///
/// The native widgets read the snapshot straight from Flutter's
/// SharedPreferences file (key `flutter.nexus_widget_snapshot`) and work out
/// "current / next class" themselves at render time, so they stay correct even
/// when the app is closed. Only the data itself needs to be pushed from here.
class WidgetSyncService {
  WidgetSyncService._();

  static const _channel = MethodChannel('com.vitap.vitap_nexus_app/widgets');
  static const _snapshotKey = 'nexus_widget_snapshot';
  static const _days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  static Map<String, dynamic> _timetable = {};
  static List<dynamic> _attendance = [];
  static List<dynamic> _exams = [];
  static int? _accent;
  static String? _lastWritten;

  static void update({
    Map<String, dynamic>? timetable,
    List<dynamic>? attendance,
    List<dynamic>? exams,
    int? accent,
  }) {
    if (timetable != null) _timetable = timetable;
    if (attendance != null) _attendance = attendance;
    if (exams != null) _exams = exams;
    if (accent != null) _accent = accent;
    _flush();
  }

  static Future<void> clear() async {
    _timetable = {};
    _attendance = [];
    _exams = [];
    _lastWritten = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_snapshotKey);
      await _channel.invokeMethod('refresh');
    } catch (_) {}
  }

  static Future<void> _flush() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_accent == null) {
        try {
          final old = prefs.getString(_snapshotKey);
          if (old != null) _accent = (jsonDecode(old) as Map)['accent'] as int?;
        } catch (_) {}
      }
      final json = jsonEncode(_build());
      if (json == _lastWritten) return;
      _lastWritten = json;
      await prefs.setString(_snapshotKey, json);
      await _channel.invokeMethod('refresh');
    } on MissingPluginException {
      // Not running on Android (or widgets unsupported) - nothing to do.
    } catch (e) {
      debugPrint('WidgetSyncService flush error: $e');
    }
  }

  static Map<String, dynamic> _build() {
    return {
      'v': 2,
      'accent': _accent,
      'days': _buildDays(),
      'att': _buildAttendance(),
      'exams': _buildExams(),
    };
  }

  static Map<String, dynamic> _buildDays() {
    final out = <String, dynamic>{};
    for (var i = 0; i < 7; i++) {
      final raw = VtopHelpers.getClassesForDay(_timetable, _days[i]);
      final items = <Map<String, dynamic>>[];
      for (final r in raw) {
        if (r is! Map) continue;
        final m = Map<String, dynamic>.from(r);
        final range = VtopHelpers.parseItemTimeRange(m);
        final start = range['start'] ?? 0;
        final end = range['end'] ?? 0;
        if (start == 0 && end == 0) continue; // no usable time from VTOP
        items.add({
          'n': (m['course_name'] ?? m['course_title'] ?? 'Class')
              .toString()
              .trim(),
          'c': (m['course_code'] ?? '').toString().trim(),
          'v': (m['venue'] ?? m['room_no'] ?? '').toString().trim(),
          's': start,
          'e': end,
          't': (m['course_type'] ?? '').toString().trim(),
        });
      }
      items.sort((a, b) => (a['s'] as int).compareTo(b['s'] as int));
      out['$i'] = items;
    }
    return out;
  }

  static Map<String, dynamic> _buildAttendance() {
    var attendedSum = 0;
    var totalSum = 0;
    final courses = <Map<String, dynamic>>[];
    for (final r in _attendance) {
      if (r is! Map) continue;
      final m = Map<String, dynamic>.from(r);
      final attended =
          int.tryParse(m['attended_classes']?.toString() ?? '') ?? 0;
      final total = int.tryParse(m['total_classes']?.toString() ?? '') ?? 0;
      if (total <= 0) continue;
      attendedSum += attended;
      totalSum += total;
      final stats = AttendanceCalculator.calculateBunkStats(attended, total);
      final count = stats['count'] as int;
      courses.add({
        'n': (m['course_name'] ?? m['course_title'] ?? 'Course')
            .toString()
            .trim(),
        'c': (m['course_code'] ?? '').toString().trim(),
        'p': double.parse(((attended / total) * 100).toStringAsFixed(1)),
        'a': attended,
        't': total,
        'y': (m['course_type'] ?? m['course_type_code'] ?? '').toString().trim(),
        // >0 = can still miss that many, <0 = must attend that many.
        'b': (stats['canBunk'] == true) ? count : -count,
      });
    }
    courses.sort((a, b) => (a['p'] as double).compareTo(b['p'] as double));
    return {
      'p': totalSum == 0
          ? null
          : double.parse(((attendedSum / totalSum) * 100).toStringAsFixed(1)),
      'a': attendedSum,
      't': totalSum,
      'courses': courses,
    };
  }

  static List<Map<String, dynamic>> _buildExams() {
    final formats = [
      DateFormat('dd-MMM-yyyy'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('dd-MM-yyyy'),
      DateFormat('d-MMM-yyyy'),
      DateFormat('dd-MMM-yy'),
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final out = <Map<String, dynamic>>[];
    for (final r in _exams) {
      if (r is! Map) continue;
      final m = Map<String, dynamic>.from(r);
      final dateStr = (m['exam_date'] ?? '').toString().trim();
      DateTime? dt;
      for (final f in formats) {
        try {
          dt = f.parseStrict(dateStr);
          break;
        } catch (_) {}
      }
      if (dt == null) continue;
      final day = DateTime(dt.year, dt.month, dt.day);
      if (day.isBefore(today)) continue;
      out.add({
        'n': (m['course_name'] ?? 'Exam').toString().trim(),
        'c': (m['course_code'] ?? '').toString().trim(),
        'd': day.millisecondsSinceEpoch,
        't': (m['exam_time'] ?? '').toString().trim(),
        'v': (m['venue'] ?? '').toString().trim(),
      });
    }
    out.sort((a, b) => (a['d'] as int).compareTo(b['d'] as int));
    return out.take(6).toList();
  }
}
