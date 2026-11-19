import 'package:flutter_test/flutter_test.dart';
import 'package:vitap_nexus_app/utils/today_logic.dart';
import 'package:vitap_nexus_app/utils/vtop_helpers.dart';

ClassOccurrence cls(DateTime day, String code, int sh, int sm, int eh, int em, {String type = 'ETH'}) =>
    ClassOccurrence.on(day, {
      'course_code': code,
      'course_name': code,
      'course_type': type,
      'start_time': '${sh.toString().padLeft(2, '0')}:${sm.toString().padLeft(2, '0')}',
      'end_time': '${eh.toString().padLeft(2, '0')}:${em.toString().padLeft(2, '0')}',
    });

void main() {
  final day = DateTime(2026, 11, 19);
  final list = [cls(day, 'A', 9, 0, 9, 50), cls(day, 'B', 10, 0, 10, 50), cls(day, 'C', 14, 0, 14, 50)];

  test('in class', () {
    final s = TodayState.from(list, DateTime(2026, 11, 19, 10, 20));
    expect(s.mood, DayMood.inClass);
    expect(s.ongoing!.courseCode, 'B');
    expect(s.next!.courseCode, 'C');
    expect(s.finished, 1);
  });

  test('soon vs free', () {
    expect(TodayState.from(list, DateTime(2026, 11, 19, 13, 50)).mood, DayMood.soon);
    expect(TodayState.from(list, DateTime(2026, 11, 19, 12, 0)).mood, DayMood.free);
  });

  test('done and no classes', () {
    expect(TodayState.from(list, DateTime(2026, 11, 19, 18, 0)).mood, DayMood.done);
    expect(TodayState.from(const [], DateTime(2026, 11, 19, 9)).mood, DayMood.noClasses);
  });

  test('skip verdict', () {
    final att = [
      {'course_code': 'A', 'course_type': 'ETH', 'attended_classes': '30', 'total_classes': '36'},
      {'course_code': 'B', 'course_type': 'ETH', 'attended_classes': '25', 'total_classes': '36'},
      {'course_code': 'C', 'course_type': 'ETH', 'attended_classes': '27', 'total_classes': '36'},
    ];
    final a = skipVerdictFor(list[0], att);
    expect(a.safeToSkipNext, isTrue);
    final b = skipVerdictFor(list[1], att);
    expect(b.safe, isFalse);
    expect(b.count, greaterThan(0));
    final c = skipVerdictFor(list[2], att); // exactly 75%
    expect(c.safe, isTrue);
    expect(c.safeToSkipNext, isFalse);
    expect(skipVerdictFor(cls(day, 'Z', 9, 0, 9, 50), att).known, isFalse);
  });
}
