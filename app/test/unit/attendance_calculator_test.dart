import 'package:flutter_test/flutter_test.dart';
import 'package:vitap_nexus_app/utils/attendance_calculator.dart';

void main() {
  group('AttendanceCalculator Unit Tests', () {
    test('Calculates bunk allowance correctly when >= 75%', () {
      // 90 attended out of 100 classes = 90%
      // At 75% target, user can bunk (90 - 0.75 * 100) / 0.75 = 15 / 0.75 = 20 classes
      final result = AttendanceCalculator.calculateBunkStats(90, 100, target: 75.0);
      expect(result['canBunk'], isTrue);
      expect(result['count'], 20);
      expect(result['percentage'], 90.0);
    });

    test('Calculates classes needed when < 75%', () {
      // 60 attended out of 100 classes = 60%
      // Needed: (0.75 * 100 - 60) / (1 - 0.75) = 15 / 0.25 = 60 classes
      final result = AttendanceCalculator.calculateBunkStats(60, 100, target: 75.0);
      expect(result['canBunk'], isFalse);
      expect(result['count'], 60);
      expect(result['percentage'], 60.0);
    });

    test('Handles 0 total classes gracefully', () {
      final result = AttendanceCalculator.calculateBunkStats(0, 0, target: 75.0);
      expect(result['canBunk'], isTrue);
      expect(result['count'], 0);
      expect(result['percentage'], 100.0);
    });

    test('Projects percentage for upcoming attended classes', () {
      // 10 attended out of 20 classes = 50%
      // If user attends 10 more classes: 20 / 30 = 66.666%
      final projected = AttendanceCalculator.projectAttending(10, 20, 10);
      expect(projected, closeTo(66.666, 0.01));
    });

    test('Projects percentage for missed classes', () {
      // 20 attended out of 20 classes = 100%
      // If user misses 5 classes: 20 / 25 = 80.0%
      final projected = AttendanceCalculator.projectMissing(20, 20, 5);
      expect(projected, 80.0);
    });
  });
}
