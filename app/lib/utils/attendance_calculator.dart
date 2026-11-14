/// Pure mathematical utility for attendance bunk/attend projections
class AttendanceCalculator {
  static Map<String, dynamic> calculateBunkStats(
    int attended,
    int total, {
    double target = 75.0,
  }) {
    if (total <= 0) {
      return {
        'canBunk': true,
        'count': 0,
        'percentage': 100.0,
      };
    }

    final currentPercentage = (attended / total) * 100;
    final targetFraction = target / 100.0;

    if (currentPercentage >= target) {
      final canBunk = ((attended - targetFraction * total) / targetFraction).floor();
      return {
        'canBunk': true,
        'count': canBunk < 0 ? 0 : canBunk,
        'percentage': currentPercentage,
      };
    }

    final needed = (targetFraction * total - attended) / (1.0 - targetFraction);
    final mustAttend = needed.ceil();

    return {
      'canBunk': false,
      'count': mustAttend < 1 ? 1 : mustAttend,
      'percentage': currentPercentage,
    };
  }

  /// Calculates new percentage if user attends N more classes
  static double projectAttending(int attended, int total, int additionalClasses) {
    if (total + additionalClasses <= 0) return 0.0;
    return ((attended + additionalClasses) / (total + additionalClasses)) * 100;
  }

  /// Calculates new percentage if user misses N more classes
  static double projectMissing(int attended, int total, int missedClasses) {
    if (total + missedClasses <= 0) return 0.0;
    return (attended / (total + missedClasses)) * 100;
  }
}
