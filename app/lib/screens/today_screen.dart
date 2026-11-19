import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../providers/vtop_providers.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/today_logic.dart';
import '../utils/vtop_helpers.dart';
import '../widgets/character_badge.dart';
import 'academic_calendar_screen.dart';
import 'assignments_screen.dart';
import 'biometric_screen.dart';
import 'cgpa_calculator_screen.dart';
import 'courses_screen.dart';
import 'faculty_screen.dart';
import 'grades_screen.dart';
import 'mentor_screen.dart';
import 'outings_screen.dart';
import 'payments_screen.dart';
import 'profile_screen.dart';
import 'vtop_webview_screen.dart';

/// Nexus "Today": the home screen, built around how the day feels right now.
class TodayScreen extends ConsumerStatefulWidget {
  final void Function(int)? onNavigateTab;
  const TodayScreen({super.key, this.onNavigateTab});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> with WidgetsBindingObserver {
  final ValueNotifier<DateTime> _now = ValueNotifier(DateTime.now());
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _now.value = DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(dashboardProvider).hasData) {
        ref.read(dashboardProvider.notifier).reloadForCurrentUser();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _now.value = DateTime.now();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _now.dispose();
    super.dispose();
  }

  void _push(Widget screen) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, a, _) => screen,
        transitionDuration: const Duration(milliseconds: 380),
        transitionsBuilder: (_, a, _, child) {
          final curve = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final dash = ref.watch(dashboardProvider);
    final profileAsync = ref.watch(profileProvider);
    final ttAsync = ref.watch(timetableProvider);
    final attAsync = ref.watch(attendanceProvider);

    final data = dash.data ?? {};
    Map<String, dynamic> pick(AsyncValue<Map<String, dynamic>> a, String key) {
      final v = a.valueOrNull;
      if (v != null && v.isNotEmpty) return v;
      return (data[key] as Map<String, dynamic>?) ?? (StorageService.getMemoryCache(key) as Map<String, dynamic>? ?? {});
    }

    final profile = pick(profileAsync, 'profile');
    final timetable = pick(ttAsync, 'timetable');
    final attendance = (attAsync.valueOrNull != null && attAsync.valueOrNull!.isNotEmpty)
        ? attAsync.valueOrNull!
        : ((data['attendance'] as List<dynamic>?) ?? (StorageService.getMemoryCache('attendance') as List<dynamic>? ?? const []));

    final rawName = profile['student_name']?.toString() ?? profile['name']?.toString() ?? auth.username ?? 'Student';
    final name = VtopHelpers.extractCallingName(rawName, auth.username);
    final pfp = profile['base64_pfp']?.toString() ?? profile['photo']?.toString() ?? profile['picture']?.toString();

    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.paper,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            try {
              await ref.read(dashboardProvider.notifier).syncAll(isUserInitiated: true);
              ref.invalidate(profileProvider);
              ref.invalidate(timetableProvider);
              ref.invalidate(attendanceProvider);
              ref.invalidate(marksProvider);
              ref.invalidate(gradesProvider);
              ref.invalidate(examScheduleProvider);
            } catch (_) {}
          },
          child: ValueListenableBuilder<DateTime>(
            valueListenable: _now,
            builder: (context, now, _) {
              final classes = timetable.isEmpty ? <ClassOccurrence>[] : VtopHelpers.classesOn(timetable, now);
              final state = TodayState.from(classes, now);
              final codes = ({...classes.map((c) => c.courseCode), ...attendance.whereType<Map>().map((m) => (m['course_code'] ?? '').toString())}..remove(''))
                  .toList()
                ..sort();
              Color colorOf(String code) => _subjectColors[(codes.indexOf(code).clamp(0, 999)) % _subjectColors.length];

              final sections = <Widget>[
                _Header(now: now, name: name, line: dayLine(state, now), pfp: pfp, onAvatar: () => _push(const ProfileScreen())),
                _Hero(state: state, now: now),
                if (classes.isNotEmpty) _DayStrip(classes: classes, now: now, colorOf: colorOf),
                if (state.next != null || state.ongoing != null)
                  _SkipCard(
                    cls: state.next ?? state.ongoing!,
                    verdict: skipVerdictFor(state.next ?? state.ongoing!, attendance),
                    isNext: state.next != null,
                    onTap: () => widget.onNavigateTab?.call(1),
                  ),
                if (attendance.isNotEmpty) _Rings(attendance: attendance, onTap: () => widget.onNavigateTab?.call(1)),
                _Jump(
                  items: [
                    _Tile('Exams', Icons.event_note_rounded, const Color(0xFFFF7A59), () => widget.onNavigateTab?.call(4)),
                    _Tile('Grades', Icons.auto_graph_rounded, const Color(0xFF6C63FF), () => _push(GradesScreen(initialData: data['grade_history'] as Map<String, dynamic>?))),
                    _Tile('Courses', Icons.auto_stories_rounded, const Color(0xFF19B5A5), () => _push(const CoursesScreen())),
                    _Tile('Assignments', Icons.task_alt_rounded, const Color(0xFFF5A524), () => _push(const AssignmentsScreen())),
                    _Tile('Calendar', Icons.calendar_month_rounded, const Color(0xFFE0568B), () => _push(const AcademicCalendarScreen())),
                    _Tile('CGPA lab', Icons.calculate_rounded, const Color(0xFF3B82F6), () => _push(const CgpaCalculatorScreen())),
                    _Tile('Faculty', Icons.groups_rounded, const Color(0xFF8B5CF6), () => _push(const FacultyScreen())),
                    _Tile('Mentor', Icons.support_agent_rounded, const Color(0xFF14B8A6), () => _push(const MentorScreen())),
                    _Tile('Outings', Icons.directions_walk_rounded, const Color(0xFFEF6C4D), () => _push(const OutingsScreen())),
                    _Tile('Payments', Icons.account_balance_wallet_rounded, const Color(0xFF22A06B), () => _push(const PaymentsScreen())),
                    _Tile('Biometric', Icons.fingerprint_rounded, const Color(0xFF64748B), () => _push(const BiometricScreen())),
                    _Tile('VTOP', Icons.public_rounded, const Color(0xFF0EA5E9), () => _push(const VtopWebViewScreen())),
                  ],
                ),
              ];

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                children: [
                  for (var i = 0; i < sections.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: sections[i]
                          .animate(key: ValueKey('sec$i-${state.mood}'))
                          .fadeIn(duration: 420.ms, delay: (70 * i).ms)
                          .slideY(begin: 0.06, end: 0, duration: 480.ms, delay: (70 * i).ms, curve: Curves.easeOutCubic),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

const _subjectColors = [
  Color(0xFF7C9BFF), Color(0xFF2DD4BF), Color(0xFFFDBA74), Color(0xFFF472B6), Color(0xFF4ADE80),
  Color(0xFFA78BFA), Color(0xFFFACC15), Color(0xFF22D3EE), Color(0xFFFB7185), Color(0xFFA3E635),
];

TextStyle _display(double size, {Color? color, FontWeight weight = FontWeight.w800, double? height, double spacing = -0.5}) =>
    GoogleFonts.bricolageGrotesque(fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: spacing);

// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final DateTime now;
  final String name;
  final String line;
  final String? pfp;
  final VoidCallback onAvatar;
  const _Header({required this.now, required this.name, required this.line, required this.pfp, required this.onAvatar});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final h = now.hour;
    final hello = h < 5 ? 'Still up' : h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : h < 21 ? 'Good evening' : 'Night owl';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${DateFormat('d MMM').format(now).toUpperCase()}  ·  $hello, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: p.inkMuted)),
              const SizedBox(height: 2),
              Text(DateFormat('EEEE').format(now), style: _display(44, color: p.ink, height: 1.05)),
              const SizedBox(height: 4),
              Text(line, style: GoogleFonts.dmSans(fontSize: 13.5, color: p.inkSoft, height: 1.3)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _Avatar(name: name, pfp: pfp, onTap: onAvatar),
      ],
    );
  }
}

/// The photo in the header. It remembers the decoded picture, so the once-a-second
/// refresh of the screen does not rebuild (and flicker) the image, and it follows the
/// avatar chosen in Profile.
class _Avatar extends StatefulWidget {
  final String name;
  final String? pfp;
  final VoidCallback onTap;
  const _Avatar({required this.name, required this.pfp, required this.onTap});

  @override
  State<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<_Avatar> {
  ImageProvider? _image;
  String? _builtFor;

  @override
  void initState() {
    super.initState();
    StorageService.avatarChanged.addListener(_refresh);
    _resolve();
  }

  @override
  void didUpdateWidget(_Avatar old) {
    super.didUpdateWidget(old);
    if (old.pfp != widget.pfp) _resolve();
  }

  @override
  void dispose() {
    StorageService.avatarChanged.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(_resolve);
  }

  /// Chosen avatar first, then the VTOP photo, otherwise the initial.
  void _resolve() {
    final custom = StorageService.getCustomAvatarPathSync();
    final key = custom != null && custom.isNotEmpty ? 'asset:$custom' : 'pfp:${widget.pfp?.hashCode}';
    if (key == _builtFor) return;
    _builtFor = key;
    if (custom != null && custom.isNotEmpty) {
      _image = AssetImage(custom);
      return;
    }
    final pfp = widget.pfp;
    _image = null;
    if (pfp != null && pfp.length > 100) {
      try {
        _image = MemoryImage(base64Decode(pfp.contains(',') ? pfp.split(',').last : pfp));
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.soft,
          border: Border.all(color: p.line, width: 1.5),
          image: _image == null ? null : DecorationImage(image: _image!, fit: BoxFit.cover),
        ),
        alignment: Alignment.center,
        child: _image == null
            ? Text(widget.name.isEmpty ? '?' : widget.name[0].toUpperCase(), style: _display(22, color: p.ink))
            : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------

({List<Color> colors, String label}) _moodStyle(DayMood m) => switch (m) {
      DayMood.inClass => (colors: const [Color(0xFF6B4DFF), Color(0xFF241A7A)], label: 'IN CLASS'),
      DayMood.soon => (colors: const [Color(0xFFFF9A1F), Color(0xFFFF3D81)], label: 'STARTING SOON'),
      DayMood.free => (colors: const [Color(0xFF12B5A6), Color(0xFF123B6B)], label: 'NEXT UP'),
      DayMood.done => (colors: const [Color(0xFF2DB87A), Color(0xFF0B3B34)], label: 'ALL DONE'),
      DayMood.noClasses => (colors: const [Color(0xFFFF8A65), Color(0xFFB8336A)], label: 'FREE DAY'),
    };

String _clock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

class _Hero extends StatelessWidget {
  final TodayState state;
  final DateTime now;
  const _Hero({required this.state, required this.now});

  @override
  Widget build(BuildContext context) {
    final style = _moodStyle(state.mood);
    final cls = state.ongoing ?? state.next;
    String big;
    String title;
    String sub;
    double? progress;
    switch (state.mood) {
      case DayMood.inClass:
        big = _clock(cls!.remainingAt(now) ?? Duration.zero);
        title = cls.courseName;
        sub = 'until ${DateFormat('h:mm a').format(cls.end ?? now)}  ·  ${cls.venue}';
        progress = cls.progressAt(now);
      case DayMood.soon:
      case DayMood.free:
        big = _clock(cls!.startsInAt(now) ?? Duration.zero);
        title = cls.courseName;
        sub = '${VtopHelpers.formatItemTimeRange(cls.info)}  ·  ${cls.venue}';
      case DayMood.done:
        big = 'Done!';
        title = 'That is a wrap for today';
        sub = '${state.total} classes finished';
      case DayMood.noClasses:
        big = 'Free';
        title = 'Nothing on the timetable';
        sub = 'Use the time well';
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      height: 218,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: style.colors),
        boxShadow: [BoxShadow(color: style.colors.first.withValues(alpha: 0.35), blurRadius: 28, offset: const Offset(0, 14))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Stack(
          children: [
            Positioned(right: -50, top: -60, child: _blob(210, 0.12)),
            Positioned(left: -40, bottom: -70, child: _blob(180, 0.08)),
            Positioned(
              right: 8,
              bottom: 6,
              child: CharacterBadge(mood: state.mood, size: 104)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: -5, duration: 1800.ms, curve: Curves.easeInOut),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Text(style.label,
                        style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: style.colors.last)),
                  ),
                  const Spacer(),
                  Text(big, style: _display(54, color: Colors.white, height: 1, spacing: -1.5)),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 215,
                    child: Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _display(16, color: Colors.white, weight: FontWeight.w700, height: 1.15, spacing: -0.2)),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    width: 215,
                    child: Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white.withValues(alpha: 0.82))),
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 215,
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.22),
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(double s, double a) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: a)),
      );
}

// ---------------------------------------------------------------------------

class _DayStrip extends StatelessWidget {
  final List<ClassOccurrence> classes;
  final DateTime now;
  final Color Function(String) colorOf;
  const _DayStrip({required this.classes, required this.now, required this.colorOf});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final timed = classes.where((c) => c.start != null && c.end != null).toList();
    if (timed.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('YOUR DAY', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.3, color: p.inkMuted)),
        const SizedBox(height: 10),
        SizedBox(
          height: 46,
          child: CustomPaint(
            size: const Size(double.infinity, 46),
            painter: _StripPainter(timed, now, colorOf, p.soft, p.ink),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('h:mm a').format(timed.first.start!), style: GoogleFonts.dmSans(fontSize: 11, color: p.inkMuted)),
            Text(DateFormat('h:mm a').format(timed.last.end!), style: GoogleFonts.dmSans(fontSize: 11, color: p.inkMuted)),
          ],
        ),
      ],
    );
  }
}

class _StripPainter extends CustomPainter {
  final List<ClassOccurrence> classes;
  final DateTime now;
  final Color Function(String) colorOf;
  final Color track;
  final Color ink;
  _StripPainter(this.classes, this.now, this.colorOf, this.track, this.ink);

  @override
  void paint(Canvas canvas, Size size) {
    final start = classes.first.start!.subtract(const Duration(minutes: 15));
    final end = classes.last.end!.add(const Duration(minutes: 15));
    final span = end.difference(start).inSeconds.toDouble();
    double x(DateTime t) => (t.difference(start).inSeconds / span).clamp(0.0, 1.0) * size.width;
    final trackRect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 12, size.width, 22), const Radius.circular(11));
    canvas.drawRRect(trackRect, Paint()..color = track);
    for (final c in classes) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTRB(x(c.start!) + 1, 12, x(c.end!) - 1, 34),
        const Radius.circular(11),
      );
      final done = c.phaseAt(now) == ClassPhase.completed;
      canvas.drawRRect(r, Paint()..color = colorOf(c.courseCode).withValues(alpha: done ? 0.38 : 1));
    }
    final nx = x(now);
    if (now.isAfter(start) && now.isBefore(end)) {
      canvas.drawLine(Offset(nx, 4), Offset(nx, 42), Paint()..color = ink..strokeWidth = 2.4..strokeCap = StrokeCap.round);
      canvas.drawCircle(Offset(nx, 5), 4.2, Paint()..color = ink);
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) => old.now.minute != now.minute || old.now.second ~/ 5 != now.second ~/ 5;
}

// ---------------------------------------------------------------------------

class _SkipCard extends StatelessWidget {
  final ClassOccurrence cls;
  final SkipVerdict verdict;
  final bool isNext;
  final VoidCallback onTap;
  const _SkipCard({required this.cls, required this.verdict, required this.isNext, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final v = verdict;
    final Color tone;
    final String headline;
    final String detail;
    if (!v.known) {
      tone = p.inkMuted;
      headline = 'No attendance data yet';
      detail = 'Open the attendance tab once to sync.';
    } else if (v.safeToSkipNext) {
      tone = p.green;
      headline = 'Safe to skip';
      detail = 'You can miss ${v.count} more and stay above 75%.';
    } else if (v.safe) {
      tone = p.orange;
      headline = 'Right on the edge';
      detail = 'Skip it and you drop under 75%. Better go.';
    } else {
      tone = p.red;
      headline = 'Do not skip';
      detail = 'Attend the next ${v.count} to climb back to 75%.';
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: tone.withValues(alpha: 0.5), width: 1.4),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: tone.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(18)),
              alignment: Alignment.center,
              child: Text(v.known ? '${v.percent.round()}%' : '?', style: _display(18, color: tone)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${isNext ? 'NEXT' : 'NOW'}  ·  ${cls.courseName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: p.inkMuted)),
                  const SizedBox(height: 3),
                  Text(headline, style: _display(20, color: tone, spacing: -0.3)),
                  const SizedBox(height: 2),
                  Text(detail, style: GoogleFonts.dmSans(fontSize: 12.5, color: p.inkSoft, height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Rings extends StatelessWidget {
  final List<dynamic> attendance;
  final VoidCallback onTap;
  const _Rings({required this.attendance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final rows = <({String code, String name, double pct})>[];
    for (final r in attendance) {
      if (r is! Map) continue;
      final a = int.tryParse(r['attended_classes']?.toString() ?? '') ?? 0;
      final t = int.tryParse(r['total_classes']?.toString() ?? '') ?? 0;
      if (t <= 0) continue;
      rows.add((code: (r['course_code'] ?? '').toString(), name: (r['course_name'] ?? r['course_title'] ?? '').toString(), pct: a * 100 / t));
    }
    rows.sort((a, b) => a.pct.compareTo(b.pct));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('EVERY SUBJECT', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.3, color: p.inkMuted)),
        const SizedBox(height: 10),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final r = rows[i];
              final tone = r.pct >= 85 ? p.green : r.pct >= 75 ? p.orange : p.red;
              return GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 92,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: p.line)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 58,
                        height: 58,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: (r.pct / 100).clamp(0, 1)),
                          duration: Duration(milliseconds: 900 + i * 80),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, _) => Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.expand(
                                child: CircularProgressIndicator(
                                  value: v,
                                  strokeWidth: 6,
                                  strokeCap: StrokeCap.round,
                                  backgroundColor: tone.withValues(alpha: 0.16),
                                  valueColor: AlwaysStoppedAnimation(tone),
                                ),
                              ),
                              Text('${(v * 100).round()}', style: _display(17, color: p.ink)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(r.code, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: p.inkSoft)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _Tile {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _Tile(this.label, this.icon, this.color, this.onTap);
}

class _Jump extends StatelessWidget {
  final List<_Tile> items;
  const _Jump({required this.items});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('JUMP TO', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.3, color: p.inkMuted)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final t in items)
              GestureDetector(
                onTap: t.onTap,
                child: Container(
                  width: (MediaQuery.sizeOf(context).width - 40 - 20) / 3,
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                  decoration: BoxDecoration(
                    color: t.color.withValues(alpha: p.isDark ? 0.16 : 0.12),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(t.icon, size: 24, color: t.color),
                      const SizedBox(height: 14),
                      Text(t.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _display(13.5, color: p.ink, weight: FontWeight.w700, spacing: -0.1)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
