import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Marks Calculation & Rounding Unit Tests', () {
    test('Rounds overall marks mathematically', () {
      expect((89.4).round(), 89);
      expect((89.5).round(), 90);
      expect((89.9).round(), 90);
      expect((0.0).round(), 0);
      expect((100.0).round(), 100);
    });

    test('Parses raw score strings safely including hyphens and spaces', () {
      double parseScore(dynamic val) {
        if (val == null) return 0.0;
        final clean = val.toString().trim();
        if (clean == '-' || clean.isEmpty || clean.toLowerCase() == 'ab') return 0.0;
        return double.tryParse(clean) ?? 0.0;
      }

      expect(parseScore('45.5'), 45.5);
      expect(parseScore(' - '), 0.0);
      expect(parseScore('AB'), 0.0);
      expect(parseScore(null), 0.0);
      expect(parseScore(50), 50.0);
    });

    test('Computes total weightage sum across assessment items', () {
      final assessments = [
        {'title': 'Quiz 1', 'weightage_score': '9.5', 'max_weightage': '10'},
        {'title': 'Mid-Term', 'weightage_score': '27.4', 'max_weightage': '30'},
        {'title': 'Assignment', 'weightage_score': '18.0', 'max_weightage': '20'},
        {'title': 'Final Exam', 'weightage_score': '36.8', 'max_weightage': '40'},
      ];

      double totalWeightage = 0.0;
      for (final a in assessments) {
        final score = double.tryParse(a['weightage_score'] ?? '0') ?? 0.0;
        totalWeightage += score;
      }

      expect(totalWeightage, closeTo(91.7, 0.001));
      expect(totalWeightage.round(), 92);
    });
  });
}
