import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../widgets/shadcn/shadcn_ui.dart';
import '../screens/attendance_screen.dart';
import '../screens/timetable_screen.dart';
import '../screens/marks_screen.dart';
import '../screens/exam_schedule.dart';
import '../screens/grades_screen.dart';
import '../screens/courses_screen.dart';
import '../screens/assignments_screen.dart';
import '../screens/faculty_screen.dart';
import '../screens/cgpa_calculator_screen.dart';
import '../screens/academic_calendar_screen.dart';
import '../screens/outings_screen.dart';
import '../screens/biometric_screen.dart';
import '../screens/payments_screen.dart';
import '../screens/mentor_screen.dart';
import '../screens/diagnostics_screen.dart';
import '../screens/profile_screen.dart';

class _CommandDestination {
  final String title;
  final String subtitle;
  final String category;
  final IconData icon;
  final Widget Function() builder;
  final List<String> keywords;

  const _CommandDestination({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.builder,
    required this.keywords,
  });
}

class NexusCommandPaletteModal extends StatefulWidget {
  const NexusCommandPaletteModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NexusCommandPaletteModal(),
    );
  }

  @override
  State<NexusCommandPaletteModal> createState() => _NexusCommandPaletteModalState();
}

class _NexusCommandPaletteModalState extends State<NexusCommandPaletteModal> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';

  static final List<_CommandDestination> _destinations = [
    _CommandDestination(
      title: 'Timetable & Class Schedule',
      subtitle: 'View today\'s slots, weekly days, and room venues',
      category: 'ACADEMICS',
      icon: Icons.calendar_today_rounded,
      builder: () => const TimetableScreen(),
      keywords: ['schedule', 'classes', 'lecture', 'timing', 'slots', 'monday', 'friday'],
    ),
    _CommandDestination(
      title: 'Attendance Tracker & Bunk Calculator',
      subtitle: 'Check 75% thresholds, safe classes, and day logs',
      category: 'ACADEMICS',
      icon: Icons.pie_chart_rounded,
      builder: () => const AttendanceScreen(),
      keywords: ['attendance', 'bunk', 'calculator', 'percentage', 'present', 'absent', 'duty'],
    ),
    _CommandDestination(
      title: 'Marks & Continuous Assessments',
      subtitle: 'CAT-1, CAT-2, FAT, and DA scores with class averages',
      category: 'ACADEMICS',
      icon: Icons.bar_chart_rounded,
      builder: () => const MarksScreen(),
      keywords: ['cat', 'fat', 'da', 'quiz', 'internal', 'assessment', 'marks', 'exam'],
    ),
    _CommandDestination(
      title: 'Exam Schedule & Venue Allotment',
      subtitle: 'Seat allocations, report timings, and countdown tags',
      category: 'ACADEMICS',
      icon: Icons.event_note_rounded,
      builder: () => const ExamScheduleScreen(),
      keywords: ['exam', 'hall ticket', 'seat', 'venue', 'midterm', 'final', 'room'],
    ),
    _CommandDestination(
      title: 'Course Page & Registered Curriculum',
      subtitle: 'Syllabus, faculty details, and course credits',
      category: 'ACADEMICS',
      icon: Icons.auto_stories_rounded,
      builder: () => const CoursesScreen(),
      keywords: ['course', 'subject', 'faculty', 'credits', 'syllabus'],
    ),
    _CommandDestination(
      title: 'Assignments & Digital Submissions',
      subtitle: 'Upcoming deadlines, pending uploads, and DA links',
      category: 'ACADEMICS',
      icon: Icons.assignment_turned_in_rounded,
      builder: () => const AssignmentsScreen(),
      keywords: ['assignment', 'deadline', 'da', 'submission', 'homework'],
    ),
    _CommandDestination(
      title: 'Grades History & Academic Transcript',
      subtitle: 'Semester GPA history, total earned credits, and grades',
      category: 'RECORDS',
      icon: Icons.military_tech_rounded,
      builder: () => const GradesScreen(),
      keywords: ['grades', 'gpa', 'cgpa', 'transcript', 'credits', 's grade', 'a grade'],
    ),
    _CommandDestination(
      title: 'Target CGPA Calculator',
      subtitle: 'Project required future semester grades for graduation',
      category: 'RECORDS',
      icon: Icons.calculate_rounded,
      builder: () => const CgpaCalculatorScreen(),
      keywords: ['cgpa', 'gpa', 'calculator', 'target', 'estimate', 'projection'],
    ),
    _CommandDestination(
      title: 'Hostel Outings & Leave Approvals',
      subtitle: 'Outing history, gate passes, and warden statuses',
      category: 'CAMPUS LIFE',
      icon: Icons.directions_walk_rounded,
      builder: () => const OutingsScreen(),
      keywords: ['outing', 'gatepass', 'hostel', 'leave', 'warden', 'permission'],
    ),
    _CommandDestination(
      title: 'Biometric Hostel Turnstile Logs',
      subtitle: 'Campus entry and exit punches with exact timestamps',
      category: 'CAMPUS LIFE',
      icon: Icons.fingerprint_rounded,
      builder: () => const BiometricScreen(),
      keywords: ['biometric', 'punch', 'turnstile', 'gate', 'entry', 'exit'],
    ),
    _CommandDestination(
      title: 'Academic University Calendar',
      subtitle: 'Instructional working days, holidays, and events',
      category: 'CAMPUS LIFE',
      icon: Icons.event_available_rounded,
      builder: () => const AcademicCalendarScreen(),
      keywords: ['calendar', 'holiday', 'events', 'working day', 'semester dates'],
    ),
    _CommandDestination(
      title: 'Fee Payments & Official Receipts',
      subtitle: 'Tuition dues, pending payments, and receipts',
      category: 'CAMPUS LIFE',
      icon: Icons.receipt_long_rounded,
      builder: () => const PaymentsScreen(),
      keywords: ['fees', 'payments', 'receipts', 'dues', 'finance', 'tuition'],
    ),
    _CommandDestination(
      title: 'Faculty Proctor & Mentor Directory',
      subtitle: 'Contact numbers, cabin locations, and email IDs',
      category: 'DIRECTORY',
      icon: Icons.supervisor_account_rounded,
      builder: () => const MentorScreen(),
      keywords: ['mentor', 'proctor', 'faculty', 'cabin', 'advisor', 'contact'],
    ),
    _CommandDestination(
      title: 'Faculty Directory & Cabin Lookup',
      subtitle: 'School departments, cabin rooms, and office emails',
      category: 'DIRECTORY',
      icon: Icons.badge_outlined,
      builder: () => const FacultyScreen(),
      keywords: ['professors', 'faculty', 'teachers', 'cabin', 'email', 'dean'],
    ),
    _CommandDestination(
      title: 'System Diagnostics & Gateway Benchmark',
      subtitle: 'Live roundtrip latency, disk tiers, and storage telemetry',
      category: 'SYSTEM',
      icon: Icons.speed_rounded,
      builder: () => const DiagnosticsScreen(),
      keywords: ['diagnostics', 'ping', 'latency', 'benchmark', 'cache', 'storage'],
    ),
    _CommandDestination(
      title: 'Profile Settings & Dark Appearance',
      subtitle: 'Manage theme appearance, view student ID, and sign out',
      category: 'SYSTEM',
      icon: Icons.person_rounded,
      builder: () => const ProfileScreen(),
      keywords: ['profile', 'account', 'theme', 'dark mode', 'logout', 'settings'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<_CommandDestination> get _filteredDestinations {
    if (_query.trim().isEmpty) return _destinations;
    final q = _query.toLowerCase().trim();
    return _destinations.where((item) {
      if (item.title.toLowerCase().contains(q)) return true;
      if (item.subtitle.toLowerCase().contains(q)) return true;
      if (item.category.toLowerCase().contains(q)) return true;
      return item.keywords.any((k) => k.contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final results = _filteredDestinations;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: palette.line, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: palette.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Search Input Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: NexusSearchBar(
                    controller: _searchController,
                    hintText: 'Search destinations, exams, attendance...',
                    onChanged: (val) => setState(() => _query = val),
                    onClear: () => setState(() => _query = ''),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Close search',
                  icon: Icon(Icons.close_rounded, color: palette.inkSoft, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: palette.line),

          // Destination Results List
          Flexible(
            child: results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(40),
                    child: NexusEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No destinations match "$_query"',
                      description: 'Try searching for timetable, exams, attendance, or fees.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final dest = results[index];
                      return Semantics(
                        button: true,
                        label: '${dest.title}, ${dest.category}',
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: NexusCard(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => dest.builder()),
                              );
                            },
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: palette.blue.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(dest.icon, color: palette.blue, size: 20),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              dest.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.dmSans(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: palette.ink,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: palette.soft,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: palette.line),
                                            ),
                                            child: Text(
                                              dest.category,
                                              style: GoogleFonts.spaceGrotesk(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w800,
                                                color: palette.inkMuted,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        dest.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.dmSans(
                                          fontSize: 11.5,
                                          color: palette.inkSoft,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 13,
                                  color: palette.inkMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
