import 'package:flutter_test/flutter_test.dart';
import 'package:vitap_nexus_app/utils/academic_report.dart';

Map<String, dynamic> course(String code, String grade, num credits, String sem, {String title = ''}) => {
      'course_code': code,
      'course_title': title.isEmpty ? code : title,
      'course_type': 'ETL',
      'credits': '$credits',
      'grade': grade,
      'exam_month': sem,
    };

void main() {
  group('semesterOrder', () {
    test('sorts by year then month', () {
      final labels = ['Nov-2025', 'Jan-2025', 'May-2026', 'May-2025']
        ..sort((a, b) => AcademicReport.semesterOrder(a).compareTo(AcademicReport.semesterOrder(b)));
      expect(labels, ['Jan-2025', 'May-2025', 'Nov-2025', 'May-2026']);
    });
    test('unknown labels sort last', () {
      expect(AcademicReport.semesterOrder('??'), greaterThan(AcademicReport.semesterOrder('Dec-2099')));
    });
  });

  group('build', () {
    final data = {
      'cgpa': '8.50',
      'credits_registered': '16',
      'credits_earned': '16',
      'courses': [
        course('CSE1001', 'S', 4, 'Jan-2025'),
        course('MAT1001', 'B', 4, 'Jan-2025'),
        course('CSE2001', 'A', 4, 'May-2025'),
        course('MAT2001', 'C', 2, 'May-2025'),
        course('MGT1001', 'P', 2, 'May-2025'),
      ],
    };
    final r = AcademicReport.build(data);

    test('semester GPAs are credit-weighted and exclude pass/fail', () {
      expect(r.semesters.map((s) => s.label), ['Jan-2025', 'May-2025']);
      expect(r.semesters[0].gpa, closeTo(9.0, 1e-9)); // (10*4 + 8*4) / 8
      expect(r.semesters[1].gpa, closeTo((9 * 4 + 7 * 2) / 6, 1e-9)); // P ignored
      expect(r.semesters[1].credits, 8);
      expect(r.semesters[1].earned, 8);
    });

    test('running CGPA and semester-to-semester change', () {
      expect(r.semesters[0].cumulative, closeTo(9.0, 1e-9));
      expect(r.semesters[1].cumulative, closeTo((40 + 32 + 36 + 14) / 14, 1e-9));
      expect(r.semesters[0].delta, isNull);
      expect(r.semesters[1].delta, closeTo(8.3333 - 9.0, 1e-3));
    });

    test('uses VTOP\'s CGPA when present, and keeps its own for comparison', () {
      expect(r.cgpa, 8.50);
      expect(r.computedCgpa, closeTo(122 / 14, 1e-9));
    });

    test('grade counts and A-or-better share', () {
      expect(r.gradeCounts, {'S': 1, 'B': 1, 'A': 1, 'C': 1, 'P': 1});
      expect(r.topShare, closeTo(8 / 14, 1e-9)); // S (4) + A (4) of 14 graded credits
    });

    test('best and lowest semester', () {
      expect(r.best!.label, 'Jan-2025');
      expect(r.lowest!.label, 'May-2025');
    });

    test('subject areas need two courses and rank by average', () {
      expect(r.areas.map((a) => a.prefix), ['CSE', 'MAT']);
      expect(r.areas.first.average, closeTo(9.5, 1e-9));
      expect(r.areas.first.name, 'Computer Science');
    });

    test('pulls add up to zero and are ordered', () {
      final total = [...r.lifts, ...r.drags].fold(0.0, (s, p) => s + p.impact);
      expect(total, closeTo(0, 1e-9));
      expect(r.lifts.first.course.code, 'CSE1001'); // an S in a 4-credit course
      expect(r.drags.first.course.code, 'MAT2001'); // C at 2 credits (-0.245) pulls harder than the B at 4 (-0.204)
      expect(r.drags.first.impact, lessThan(0));
    });
  });

  test('a repeated course counts once, with the latest grade', () {
    final r = AcademicReport.build({
      'courses': [
        course('MAT1001', 'F', 4, 'Jan-2025'),
        course('CSE1001', 'A', 4, 'Jan-2025'),
        course('MAT1001', 'B', 4, 'May-2025'),
      ],
    });
    expect(r.semesters[0].gpa, closeTo(4.5, 1e-9)); // the F counts in its own semester
    expect(r.semesters[1].cumulative, closeTo(8.5, 1e-9)); // but is replaced in the CGPA
    expect(r.computedCgpa, closeTo(8.5, 1e-9));
    expect(r.cgpa, closeTo(8.5, 1e-9)); // no VTOP figure, so ours is used
    expect(r.gradeCounts.containsKey('F'), isFalse);
    expect(r.creditsRegistered, 8);
  });

  test('empty and malformed input does not throw', () {
    expect(AcademicReport.build({}).isEmpty, isTrue);
    final r = AcademicReport.build({
      'cgpa': 'N/A',
      'courses': [
        'nonsense',
        {'course_code': '', 'grade': 'A'},
        {'course_code': 'CSE1', 'grade': '', 'credits': '4'},
        course('CSE1001', 'W', 4, 'Jan-2025'),
        course('CSE1002', 'A', 0, 'Jan-2025'),
      ],
    });
    expect(r.semesters, hasLength(1));
    expect(r.semesters.single.gpa, isNull); // nothing with both points and credits
    expect(r.cgpa, isNull);
    expect(r.best, isNull);
    expect(r.lifts, isEmpty);
  });

  group('what-if', () {
    final data = {
      'cgpa': '8.50',
      'credits_registered': '12',
      'credits_earned': '12',
      'courses': [
        course('CSE1001', 'A', 4, 'Jan-2025'),
        course('MAT1001', 'B', 4, 'Jan-2025'),
        course('ENG1002', 'B', 4, 'May-2025'),
      ],
    };

    test('no changes returns the data untouched, VTOP figures included', () {
      final out = applyWhatIf(data);
      expect(identical(out, data), isTrue);
      expect(AcademicReport.build(out).cgpa, 8.50);
    });

    test('changing a grade recalculates the semester and the CGPA', () {
      final out = applyWhatIf(data, overrides: {courseKey('MAT1001', 'Jan-2025'): 'S'});
      final r = AcademicReport.build(out);
      expect(r.semesters.first.gpa, closeTo(9.5, 1e-9)); // (9*4 + 10*4) / 8
      expect(r.computedCgpa, closeTo((36 + 40 + 32) / 12, 1e-9));
      // VTOP's figure is dropped so the edited maths is what shows
      expect(r.cgpa, closeTo(r.computedCgpa!, 1e-9));
      expect(r.cgpa, isNot(8.50));
    });

    test('the original data is never modified', () {
      applyWhatIf(data, overrides: {courseKey('MAT1001', 'Jan-2025'): 'F'});
      expect((data['courses'] as List)[1]['grade'], 'B');
      expect(data['cgpa'], '8.50');
    });

    test('a failing grade pulls the CGPA down and costs earned credits', () {
      final out = applyWhatIf(data, overrides: {courseKey('CSE1001', 'Jan-2025'): 'F'});
      final r = AcademicReport.build(out);
      expect(r.computedCgpa, closeTo((0 + 32 + 32) / 12, 1e-9));
      expect(r.creditsEarned, 8);
      expect(r.creditsRegistered, 12);
    });

    test('the same code in two semesters is edited independently', () {
      final repeat = {
        'courses': [
          course('MAT1001', 'F', 4, 'Jan-2025'),
          course('MAT1001', 'B', 4, 'May-2025'),
        ],
      };
      final out = applyWhatIf(repeat, overrides: {courseKey('MAT1001', 'Jan-2025'): 'A'});
      final r = AcademicReport.build(out);
      expect(r.semesters[0].gpa, closeTo(9, 1e-9)); // the first attempt changed
      expect(r.semesters[1].gpa, closeTo(8, 1e-9)); // the second did not
      expect(r.computedCgpa, closeTo(8, 1e-9)); // latest attempt still decides the CGPA
    });

    test('planned courses form their own last semester', () {
      final out = applyWhatIf(data, planned: const [
        PlannedCourse(id: '1', title: 'Compilers', credits: 4, grade: 'S'),
        PlannedCourse(id: '2', title: '', credits: 2, grade: 'A'),
      ]);
      final r = AcademicReport.build(out);
      expect(r.semesters.last.label, kPlannedSemester);
      expect(r.semesters.last.courses, hasLength(2));
      expect(r.semesters.last.courses.last.title, 'Planned course');
      expect(r.semesters.last.gpa, closeTo((40 + 18) / 6, 1e-9));
      expect(r.courseCount, 5);
      expect(r.computedCgpa, closeTo((36 + 32 + 32 + 40 + 18) / 18, 1e-9));
    });

    test('a planned Pass course adds credits but no points', () {
      final out = applyWhatIf(data, planned: const [PlannedCourse(id: '1', title: 'Club', credits: 2, grade: 'P')]);
      final r = AcademicReport.build(out);
      expect(r.computedCgpa, closeTo(100 / 12, 1e-9)); // (36 + 32 + 32) / 12, exactly as before
      expect(r.creditsRegistered, 14);
      expect(r.creditsEarned, 14); // a pass earns its credits
    });
  });
}
