/// Turns VTOP's grade history into the numbers behind the Academic Journey
/// screen. Pure Dart: no Flutter, no storage, so it is easy to test.
///
/// Input is the map the app already caches for the Grades screen:
/// `{cgpa, credits_registered, credits_earned, courses: [{course_code,
/// course_title, course_type, credits, grade, exam_month, ...}]}`.
library;

const Map<String, int> kGradePoints = {
  'S': 10,
  'A': 9,
  'B': 8,
  'C': 7,
  'D': 6,
  'E': 5,
  'F': 0,
  'N': 0,
};

/// Grades that earn the credits (P = pass/fail courses, which carry no points).
const Set<String> kPassingGrades = {'S', 'A', 'B', 'C', 'D', 'E', 'P'};

/// Display order for grade charts.
const List<String> kGradeOrder = ['S', 'A', 'B', 'C', 'D', 'E', 'F', 'N', 'P'];

const Map<String, String> _areaNames = {
  'CSE': 'Computer Science',
  'MAT': 'Mathematics',
  'PHY': 'Physics',
  'CHY': 'Chemistry',
  'ENG': 'English',
  'ECE': 'Electronics',
  'EEE': 'Electrical',
  'ECS': 'Engineering Clinics',
  'MEC': 'Mechanical',
  'STS': 'Soft Skills',
  'MGT': 'Management',
  'HUM': 'Humanities',
  'BIO': 'Biology',
  'FRL': 'Foreign Language',
  'EXC': 'Extra-curricular',
  'SWE': 'Software Engineering',
};

class ReportCourse {
  final String code;
  final String title;
  final String type;
  final double credits;
  final String grade;
  final String semester;

  const ReportCourse({
    required this.code,
    required this.title,
    required this.type,
    required this.credits,
    required this.grade,
    required this.semester,
  });

  /// Grade points, or null for pass/fail and anything unrecognised.
  int? get points => kGradePoints[grade];
  bool get passed => kPassingGrades.contains(grade);

  /// "CSE2001" -> "CSE".
  String get area {
    final m = RegExp(r'^[A-Za-z]+').firstMatch(code);
    return (m?.group(0) ?? code).toUpperCase();
  }
}

class SemesterReport {
  final String label; // "Nov-2025"
  final int order; // year * 12 + month, for sorting
  final List<ReportCourse> courses;
  final double credits; // registered this semester
  final double earned;
  final double? gpa; // this semester alone
  final double? cumulative; // CGPA up to and including this semester
  final double? delta; // gpa minus the previous semester's gpa

  const SemesterReport({
    required this.label,
    required this.order,
    required this.courses,
    required this.credits,
    required this.earned,
    required this.gpa,
    required this.cumulative,
    required this.delta,
  });

  Map<String, int> get gradeCounts => _countGrades(courses);
}

class AreaStat {
  final String prefix;
  final double average;
  final double credits;
  final int courses;

  const AreaStat({
    required this.prefix,
    required this.average,
    required this.credits,
    required this.courses,
  });

  String get name => _areaNames[prefix] ?? prefix;
}

/// How far one course pushed the CGPA up or down, in CGPA points.
class CoursePull {
  final ReportCourse course;
  final double impact;
  const CoursePull(this.course, this.impact);
}

class AcademicReport {
  /// The CGPA VTOP reports, falling back to our own calculation.
  final double? cgpa;
  final double? computedCgpa;
  final double creditsRegistered;
  final double creditsEarned;
  final int courseCount;
  final List<SemesterReport> semesters; // oldest first
  final Map<String, int> gradeCounts;

  /// Share of graded credits that are A or better (0..1).
  final double topShare;
  final List<AreaStat> areas; // best first
  final List<CoursePull> lifts; // biggest positive first
  final List<CoursePull> drags; // biggest negative first

  const AcademicReport({
    required this.cgpa,
    required this.computedCgpa,
    required this.creditsRegistered,
    required this.creditsEarned,
    required this.courseCount,
    required this.semesters,
    required this.gradeCounts,
    required this.topShare,
    required this.areas,
    required this.lifts,
    required this.drags,
  });

  bool get isEmpty => semesters.isEmpty;

  SemesterReport? get best => _pick((a, b) => a > b);
  SemesterReport? get lowest => _pick((a, b) => a < b);

  SemesterReport? _pick(bool Function(double, double) better) {
    SemesterReport? out;
    for (final s in semesters) {
      if (s.gpa == null) continue;
      if (out == null || better(s.gpa!, out.gpa!)) out = s;
    }
    return out;
  }

  static AcademicReport build(Map<String, dynamic> data) {
    final courses = <ReportCourse>[];
    for (final raw in (data['courses'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final code = '${raw['course_code'] ?? ''}'.trim().toUpperCase();
      final grade = '${raw['grade'] ?? ''}'.trim().toUpperCase();
      if (code.isEmpty || grade.isEmpty) continue;
      courses.add(ReportCourse(
        code: code,
        title: '${raw['course_title'] ?? raw['course_name'] ?? code}'.trim(),
        type: '${raw['course_type'] ?? ''}'.trim(),
        credits: double.tryParse('${raw['credits'] ?? ''}'.trim()) ?? 0,
        grade: grade,
        semester: '${raw['exam_month'] ?? ''}'.trim(),
      ));
    }

    // Group by semester, oldest first.
    final bySem = <String, List<ReportCourse>>{};
    for (final c in courses) {
      bySem.putIfAbsent(c.semester.isEmpty ? 'Unknown' : c.semester, () => []).add(c);
    }
    final labels = bySem.keys.toList()
      ..sort((a, b) => semesterOrder(a).compareTo(semesterOrder(b)));

    final semesters = <SemesterReport>[];
    final seen = <ReportCourse>[];
    double? previousGpa;
    for (final label in labels) {
      final list = bySem[label]!;
      seen.addAll(list);
      final gpa = _gpa(list);
      semesters.add(SemesterReport(
        label: label,
        order: semesterOrder(label),
        courses: list,
        credits: list.fold(0.0, (s, c) => s + c.credits),
        earned: list.where((c) => c.passed).fold(0.0, (s, c) => s + c.credits),
        gpa: gpa,
        cumulative: _gpa(latestAttempts(seen)),
        delta: (gpa != null && previousGpa != null) ? gpa - previousGpa : null,
      ));
      if (gpa != null) previousGpa = gpa;
    }

    final latest = latestAttempts(courses);
    final computed = _gpa(latest);
    final cgpa = double.tryParse('${data['cgpa'] ?? ''}'.trim()) ?? computed;

    final graded = latest.where((c) => c.points != null && c.credits > 0).toList();
    final gradedCredits = graded.fold(0.0, (s, c) => s + c.credits);
    final topCredits = graded.where((c) => c.points! >= 9).fold(0.0, (s, c) => s + c.credits);

    // Subject areas with at least two graded courses, best average first.
    final byArea = <String, List<ReportCourse>>{};
    for (final c in graded) {
      byArea.putIfAbsent(c.area, () => []).add(c);
    }
    final areas = <AreaStat>[
      for (final e in byArea.entries)
        if (e.value.length >= 2)
          AreaStat(
            prefix: e.key,
            average: _gpa(e.value)!,
            credits: e.value.fold(0.0, (s, c) => s + c.credits),
            courses: e.value.length,
          ),
    ]..sort((a, b) {
        final d = b.average.compareTo(a.average);
        return d != 0 ? d : b.credits.compareTo(a.credits);
      });

    // Each course's pull on the CGPA: credits x (points - CGPA) / all credits.
    final pulls = <CoursePull>[];
    if (computed != null && gradedCredits > 0) {
      for (final c in graded) {
        pulls.add(CoursePull(c, c.credits * (c.points! - computed) / gradedCredits));
      }
    }
    final lifts = pulls.where((p) => p.impact > 0.0005).toList()
      ..sort((a, b) => b.impact.compareTo(a.impact));
    final drags = pulls.where((p) => p.impact < -0.0005).toList()
      ..sort((a, b) => a.impact.compareTo(b.impact));

    return AcademicReport(
      cgpa: cgpa,
      computedCgpa: computed,
      creditsRegistered: double.tryParse('${data['credits_registered'] ?? ''}'.trim()) ??
          latest.fold(0.0, (s, c) => s + c.credits),
      creditsEarned: double.tryParse('${data['credits_earned'] ?? ''}'.trim()) ??
          latest.where((c) => c.passed).fold(0.0, (s, c) => s + c.credits),
      courseCount: courses.length,
      semesters: semesters,
      gradeCounts: _countGrades(latest),
      topShare: gradedCredits == 0 ? 0 : topCredits / gradedCredits,
      areas: areas,
      lifts: lifts,
      drags: drags,
    );
  }

  /// When a course was taken more than once, only the most recent attempt
  /// counts towards the CGPA.
  static List<ReportCourse> latestAttempts(List<ReportCourse> courses) {
    final latest = <String, ReportCourse>{};
    for (final c in courses) {
      final old = latest[c.code];
      if (old == null || semesterOrder(c.semester) >= semesterOrder(old.semester)) {
        latest[c.code] = c;
      }
    }
    return latest.values.toList();
  }

  static double? _gpa(List<ReportCourse> list) {
    double points = 0, credits = 0;
    for (final c in list) {
      final p = c.points;
      if (p == null || c.credits <= 0) continue;
      points += p * c.credits;
      credits += c.credits;
    }
    return credits == 0 ? null : points / credits;
  }

  /// "Nov-2025" -> 2025 * 12 + 11. Unknown shapes sort last.
  static int semesterOrder(String label) {
    const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    final m = RegExp(r'([A-Za-z]{3})[A-Za-z]*[-\s/]*(\d{4})').firstMatch(label);
    if (m == null) return 1 << 30;
    final month = months.indexOf(m.group(1)!.toLowerCase());
    final year = int.parse(m.group(2)!);
    return year * 12 + (month < 0 ? 0 : month + 1);
  }
}

Map<String, int> _countGrades(List<ReportCourse> list) {
  final out = <String, int>{};
  for (final c in list) {
    out[c.grade] = (out[c.grade] ?? 0) + 1;
  }
  return out;
}


// ===========================================================================
// What-if: change grades, add planned courses
// ===========================================================================

/// The grades a person can pick when trying things out.
const List<String> kPickableGrades = ['S', 'A', 'B', 'C', 'D', 'E', 'F', 'P'];

/// Label for the semester that holds courses added by hand.
const String kPlannedSemester = 'Planned';

/// A course added by hand to see what it would do to the CGPA.
class PlannedCourse {
  final String id;
  final String title;
  final double credits;
  final String grade;

  const PlannedCourse({
    required this.id,
    required this.title,
    required this.credits,
    required this.grade,
  });

  PlannedCourse copyWith({String? title, double? credits, String? grade}) => PlannedCourse(
        id: id,
        title: title ?? this.title,
        credits: credits ?? this.credits,
        grade: grade ?? this.grade,
      );
}

/// Identifies one course within one semester (the same code can appear twice
/// when a course was repeated).
String courseKey(String code, String semester) =>
    '${code.trim().toUpperCase()}|${semester.trim()}';

/// Returns a copy of [data] with [overrides] (courseKey -> grade) applied and
/// [planned] courses appended in a "Planned" semester. The original is never
/// modified.
///
/// When anything changed, VTOP's own CGPA and credit totals are dropped from
/// the copy so the report works them out from the edited courses instead.
Map<String, dynamic> applyWhatIf(
  Map<String, dynamic> data, {
  Map<String, String> overrides = const {},
  List<PlannedCourse> planned = const [],
}) {
  if (overrides.isEmpty && planned.isEmpty) return data;

  final courses = <dynamic>[];
  for (final raw in (data['courses'] as List? ?? const [])) {
    if (raw is! Map) continue;
    final copy = Map<String, dynamic>.from(raw);
    final key = courseKey('${copy['course_code'] ?? ''}', '${copy['exam_month'] ?? ''}');
    final g = overrides[key];
    if (g != null) copy['grade'] = g;
    courses.add(copy);
  }
  for (final c in planned) {
    courses.add({
      'course_code': 'PLAN-${c.id}',
      'course_title': c.title.trim().isEmpty ? 'Planned course' : c.title.trim(),
      'course_type': '',
      'credits': c.credits == c.credits.roundToDouble() ? c.credits.toStringAsFixed(0) : c.credits.toString(),
      'grade': c.grade,
      'exam_month': kPlannedSemester,
    });
  }

  return {
    ...data,
    'courses': courses,
    'cgpa': null,
    'credits_registered': null,
    'credits_earned': null,
  };
}
