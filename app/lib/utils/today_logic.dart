import 'attendance_calculator.dart';
import 'vtop_helpers.dart';

/// How the day feels right now. Drives the home screen's colours, copy and character mood.
enum DayMood { inClass, soon, free, done, noClasses }

class TodayState {
  final DayMood mood;
  final ClassOccurrence? ongoing;
  final ClassOccurrence? next;
  final int total;
  final int finished;

  const TodayState({
    required this.mood,
    required this.ongoing,
    required this.next,
    required this.total,
    required this.finished,
  });

  /// [classes] must be today's classes in time order.
  factory TodayState.from(List<ClassOccurrence> classes, DateTime now) {
    if (classes.isEmpty) {
      return const TodayState(mood: DayMood.noClasses, ongoing: null, next: null, total: 0, finished: 0);
    }
    ClassOccurrence? ongoing;
    ClassOccurrence? next;
    var finished = 0;
    for (final c in classes) {
      switch (c.phaseAt(now)) {
        case ClassPhase.completed:
          finished++;
        case ClassPhase.ongoing:
          ongoing ??= c;
        case ClassPhase.upcoming:
          next ??= c;
      }
    }
    final DayMood mood;
    if (ongoing != null) {
      mood = DayMood.inClass;
    } else if (next == null) {
      mood = DayMood.done;
    } else {
      final until = next.startsInAt(now);
      mood = (until != null && until.inMinutes <= 15) ? DayMood.soon : DayMood.free;
    }
    return TodayState(mood: mood, ongoing: ongoing, next: next, total: classes.length, finished: finished);
  }
}

/// The "can I skip it?" answer for one class.
class SkipVerdict {
  final bool known;
  final bool safe; // can miss this class and stay at/above the target
  final int count; // classes you can still miss (safe) or must attend (not safe)
  final double percent;
  final int attended;
  final int total;

  const SkipVerdict({
    required this.known,
    required this.safe,
    required this.count,
    required this.percent,
    required this.attended,
    required this.total,
  });

  static const unknown = SkipVerdict(known: false, safe: true, count: 0, percent: 0, attended: 0, total: 0);

  /// Misses one more class: is the target still met afterwards?
  bool get safeToSkipNext => known && safe && count >= 1;
}

SkipVerdict skipVerdictFor(ClassOccurrence c, List<dynamic> attendance, {double target = 75}) {
  Map<String, dynamic>? match;
  final wantLab = CourseTypeHelper.getCourseCategory(c.courseType) == CourseTypeHelper.lab;
  for (final r in attendance) {
    if (r is! Map) continue;
    final m = Map<String, dynamic>.from(r);
    if ((m['course_code'] ?? '').toString().trim() != c.courseCode) continue;
    final isLab = CourseTypeHelper.getCourseCategory((m['course_type'] ?? '').toString()) == CourseTypeHelper.lab;
    if (isLab == wantLab) {
      match = m;
      break;
    }
    match ??= m;
  }
  if (match == null) return SkipVerdict.unknown;
  final attended = int.tryParse(match['attended_classes']?.toString() ?? '') ?? 0;
  final total = int.tryParse(match['total_classes']?.toString() ?? '') ?? 0;
  if (total <= 0) return SkipVerdict.unknown;
  final s = AttendanceCalculator.calculateBunkStats(attended, total, target: target);
  return SkipVerdict(
    known: true,
    safe: s['canBunk'] == true,
    count: s['count'] as int,
    percent: (s['percentage'] as num).toDouble(),
    attended: attended,
    total: total,
  );
}

/// A tiny line of personality for the home screen header.
String dayLine(TodayState s, DateTime now) {
  switch (s.mood) {
    case DayMood.noClasses:
      return now.weekday >= 6 ? 'No classes. Go touch some grass.' : 'No classes today. Breathe.';
    case DayMood.done:
      return 'All ${s.total} done. You earned the evening.';
    case DayMood.inClass:
      return 'Focus mode. ${s.total - s.finished - 1} more after this one.';
    case DayMood.soon:
      return 'Pack up. Next class is about to start.';
    case DayMood.free:
      final left = s.total - s.finished;
      return '$left ${left == 1 ? 'class' : 'classes'} left today.';
  }
}
