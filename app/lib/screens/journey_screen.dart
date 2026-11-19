import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../journey/journey_image.dart';
import '../journey/journey_pdf.dart';
import '../journey/journey_widgets.dart';
import '../providers/vtop_providers.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/academic_report.dart';
import '../widgets/auth/auth_kit.dart';
import '../widgets/sheet_kit.dart';

/// Your grades as a story: where the CGPA came from, how it moved, and which
/// courses moved it. Everything is computed on the phone from the grade history
/// VTOP already gave the app.
class JourneyScreen extends ConsumerStatefulWidget {
  /// Pass the data the Grades screen already loaded, or leave null to read the cache.
  final Map<String, dynamic>? initialData;

  const JourneyScreen({super.key, this.initialData});

  @override
  ConsumerState<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends ConsumerState<JourneyScreen> {
  bool _hide = StorageService.isPrivacyModeEnabledSync();
  final Set<String> _open = {};

  // What-if: grades changed by hand, and courses added by hand. They live only
  // in this screen; the real grades are never touched.
  bool _edit = false;
  final Map<String, String> _overrides = {};
  final List<PlannedCourse> _planned = [];
  int _plannedSeq = 0;
  Map<String, String> _originalGrades = {};
  AcademicReport? _original;
  List<String> _labels = const [];

  bool get _changed => _overrides.isNotEmpty || _planned.isNotEmpty;
  int get _changeCount => _overrides.length + _planned.length;

  void _toggleEdit() {
    HapticFeedback.selectionClick();
    setState(() {
      _edit = !_edit;
      if (_edit) _open.addAll(_labels); // open every semester so grades are reachable
    });
  }

  void _reset() {
    HapticFeedback.mediumImpact();
    setState(() {
      _overrides.clear();
      _planned.clear();
    });
    nexusToast(context, 'Back to your real grades.');
  }

  Future<void> _pickGrade(ReportCourse c) async {
    final planned = c.code.startsWith('PLAN-');
    final key = courseKey(c.code, c.semester);
    final original = planned ? null : _originalGrades[key];
    final picked = await showNexusSheet<String>(
      context,
      (ctx) => _GradePickerSheet(title: c.title, credits: c.credits, current: c.grade, original: original),
    );
    if (picked == null || !mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (planned) {
        final id = c.code.substring(5);
        final i = _planned.indexWhere((x) => x.id == id);
        if (i >= 0) _planned[i] = _planned[i].copyWith(grade: picked);
      } else if (picked == original) {
        _overrides.remove(key);
      } else {
        _overrides[key] = picked;
      }
    });
  }

  Future<void> _addCourse() async {
    final result = await showNexusSheet<({String title, double credits, String grade})>(
      context,
      (ctx) => const _AddCourseSheet(),
    );
    if (result == null || !mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _planned.add(PlannedCourse(id: '${++_plannedSeq}', title: result.title, credits: result.credits, grade: result.grade));
      _open.add(kPlannedSemester);
    });
  }

  Future<void> _exportPdf(AcademicReport report) async {
    if (_hide) {
      final p = AppPalette.of(context);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: p.line)),
          title: Text('Show your grades?', style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w700, color: p.ink)),
          content: Text(
            'Privacy mode is on, but the PDF will list every course and grade. Continue?',
            style: GoogleFonts.dmSans(color: p.inkSoft, height: 1.45),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    try {
      final bytes = await buildJourneyPdf(
        report,
        whatIf: _changed,
        changed: _overrides.keys.toSet(),
        now: DateTime.now(),
      );
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: _changed ? 'VITAP-Nexus-WhatIf-Report.pdf' : 'VITAP-Nexus-Academic-Report.pdf',
      );
    } catch (_) {
      if (mounted) nexusToast(context, 'Could not prepare the PDF.');
    }
  }

  Future<void> _sharePicture(AcademicReport report) async {
    if (_hide) {
      final p = AppPalette.of(context);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: p.line)),
          title: Text('Show your CGPA?', style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w700, color: p.ink)),
          content: Text(
            'Privacy mode is on, but the picture will show your CGPA and grade mix. Continue?',
            style: GoogleFonts.dmSans(color: p.inkSoft, height: 1.45),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    await showNexusSheet<void>(context, (ctx) => _PictureSheet(report: report, whatIf: _changed));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final async = ref.watch(gradesProvider);
    final passed = widget.initialData;
    final data = (passed != null && passed.isNotEmpty) ? passed : async.valueOrNull;

    Widget body;
    AcademicReport? report;
    if (data == null) {
      body = async.hasError
          ? _message(p, Icons.cloud_off_rounded, 'Could not load your grades', 'Open Grades once while online, then come back.')
          : const Padding(padding: EdgeInsets.only(top: 120), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    } else {
      _original = AcademicReport.build(data);
      _originalGrades = {
        for (final raw in (data['courses'] as List? ?? const []))
          if (raw is Map) courseKey('${raw['course_code'] ?? ''}', '${raw['exam_month'] ?? ''}'): '${raw['grade'] ?? ''}'.trim().toUpperCase(),
      };
      report = AcademicReport.build(applyWhatIf(data, overrides: _overrides, planned: _planned));
      _labels = [for (final x in report.semesters) x.label];
      body = report.isEmpty
          ? _message(p, Icons.hourglass_empty_rounded, 'No grade history yet', 'Your journey appears here once VTOP has published grades.')
          : _content(p, report);
    }

    return Scaffold(
      backgroundColor: p.paper,
      body: AuthBackdrop(
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
            children: [
              _header(p, report),
              const SizedBox(height: 18),
              if (report != null && !report.isEmpty && _hide)
                Stack(
                  children: [
                    IgnorePointer(
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: body,
                      ),
                    ),
                    Positioned(
                      top: 40,
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 30, color: p.inkSoft),
                          const SizedBox(height: 10),
                          Text('Hidden by privacy mode', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: p.ink)),
                          const SizedBox(height: 4),
                          Text('Tap the eye to reveal', style: GoogleFonts.dmSans(fontSize: 13, color: p.inkSoft)),
                        ],
                      ),
                    ),
                  ],
                )
              else
                body,
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------------

  Widget _header(AppPalette p, AcademicReport? report) {
    Widget btn(IconData icon, String tip, VoidCallback? onTap, {bool active = false}) => IconButton(
          tooltip: tip,
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: active ? p.ink : p.soft,
            shape: const CircleBorder(),
          ),
          icon: Icon(icon, size: 20, color: active ? (p.isDark ? Colors.black : Colors.white) : p.ink),
        );
    final ready = report != null && !report.isEmpty;
    return Row(
      children: [
        btn(Icons.arrow_back_rounded, 'Back', () => Navigator.of(context).maybePop()),
        const Spacer(),
        btn(_edit ? Icons.edit_off_rounded : Icons.tune_rounded, _edit ? 'Finish editing' : 'Try different grades', ready ? _toggleEdit : null, active: _edit),
        const SizedBox(width: 8),
        btn(Icons.print_outlined, 'Print or save as PDF', ready ? () => _exportPdf(report) : null),
        const SizedBox(width: 8),
        btn(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, _hide ? 'Show' : 'Hide', ready ? () => setState(() => _hide = !_hide) : null),
        const SizedBox(width: 8),
        btn(Icons.ios_share_rounded, 'Share as picture', ready ? () => _sharePicture(report) : null),
      ],
    );
  }

  Widget _message(AppPalette p, IconData icon, String title, String body) => Padding(
        padding: const EdgeInsets.only(top: 90),
        child: Column(
          children: [
            Icon(icon, size: 38, color: p.inkMuted),
            const SizedBox(height: 14),
            Text(title, style: GoogleFonts.bricolageGrotesque(fontSize: 18, fontWeight: FontWeight.w800, color: p.ink)),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 13.5, height: 1.45, color: p.inkSoft)),
          ],
        ),
      );

  // ------------------------------------------------------------------------

  Widget _content(AppPalette p, AcademicReport r) {
    final sems = r.semesters;
    final withCum = sems.where((s) => s.cumulative != null).toList();
    final delta = withCum.length >= 2 ? withCum.last.cumulative! - withCum[withCum.length - 2].cumulative! : null;
    final since = withCum.length >= 2 ? withCum[withCum.length - 2].label : null;

    // Biggest jump between consecutive semesters.
    SemesterReport? jump;
    for (final s in sems) {
      if (s.delta != null && s.delta! > 0 && (jump == null || s.delta! > jump.delta!)) jump = s;
    }
    final area = r.areas.isEmpty ? null : r.areas.first;
    final vtopDiff = (r.cgpa != null && r.computedCgpa != null) ? (r.cgpa! - r.computedCgpa!).abs() : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthEyebrow(_changed ? 'What-if journey' : 'Academic journey', color: _changed ? p.orange : p.blue),
        const SizedBox(height: 10),
        if (_edit || _changed) ...[
          _editBanner(p, r),
          const SizedBox(height: 12),
        ],
        _hero(p, r, delta, since),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _insight(p, Icons.emoji_events_outlined, 'Best semester', r.best == null ? '-' : r.best!.gpa!.toStringAsFixed(2), r.best == null ? '' : shortSemester(r.best!.label))),
            const SizedBox(width: 10),
            Expanded(child: _insight(p, Icons.trending_up_rounded, 'Biggest jump', jump == null ? '-' : '+${jump.delta!.toStringAsFixed(2)}', jump == null ? 'not yet' : shortSemester(jump.label))),
            const SizedBox(width: 10),
            Expanded(child: _insight(p, Icons.workspace_premium_outlined, 'Strongest area', area == null ? '-' : area.average.toStringAsFixed(2), area == null ? 'needs 2+ courses' : area.name)),
          ],
        ),

        _title(p, 'The path', 'Semester by semester'),
        _card(
          p,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 230,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.linear,
                  builder: (_, t, _) => CustomPaint(
                    size: Size.infinite,
                    painter: TrendChartPainter(
                      semesters: sems,
                      progress: t,
                      accent: p.blue,
                      ink: p.ink,
                      muted: p.inkMuted,
                      grid: p.line,
                      highlight: r.best?.label,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _legend(p, p.blue.withValues(alpha: 0.35), 'Semester GPA', bar: true),
                  const SizedBox(width: 18),
                  _legend(p, p.ink, 'Running CGPA'),
                ],
              ),
            ],
          ),
        ),

        _title(p, 'The mix', 'Your grades'),
        _card(
          p,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GradeMixBar(counts: r.gradeCounts, muted: p.inkMuted, ink: p.ink),
              const SizedBox(height: 14),
              Text(
                '${(r.topShare * 100).round()}% of your graded credits are A or better.',
                style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.inkSoft),
              ),
            ],
          ),
        ),

        _title(p, 'Terms', 'Every semester'),
        for (final s in sems.reversed) Padding(padding: const EdgeInsets.only(bottom: 10), child: _semesterCard(p, s)),

        if (r.lifts.isNotEmpty || r.drags.isNotEmpty) ...[
          _title(p, 'What moved it', 'Lifts and drags'),
          _pulls(p, r),
        ],

        if (r.areas.isNotEmpty) ...[
          _title(p, 'Subjects', 'Where you shine'),
          _areas(p, r),
        ],

        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 13, color: p.inkMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Worked out on this phone from your VTOP grade history. A repeated course counts once, with its latest grade; pass/fail courses carry no points.'
                '${vtopDiff > 0.02 ? ' VTOP reports ${r.cgpa!.toStringAsFixed(2)}, this works out to ${r.computedCgpa!.toStringAsFixed(2)}.' : ''}',
                style: GoogleFonts.dmSans(fontSize: 11.5, height: 1.45, color: p.inkMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _title(AppPalette p, String eyebrow, String title) => Padding(
        padding: const EdgeInsets.only(top: 30, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthEyebrow(eyebrow, color: p.blue),
            const SizedBox(height: 4),
            Text(title, style: GoogleFonts.bricolageGrotesque(fontSize: 27, fontWeight: FontWeight.w800, color: p.ink, letterSpacing: -0.8)),
          ],
        ),
      );

  Widget _card(AppPalette p, {required Widget child, EdgeInsets padding = const EdgeInsets.all(18)}) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: p.line),
        ),
        child: child,
      );

  Widget _legend(AppPalette p, Color color, String text, {bool bar = false}) => Row(
        children: [
          Container(
            width: bar ? 12 : 14,
            height: bar ? 12 : 3,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(bar ? 4 : 2)),
          ),
          const SizedBox(width: 7),
          Text(text, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: p.inkSoft)),
        ],
      );

  // ------------------------------------------------------------------------
  // Hero
  // ------------------------------------------------------------------------

  Widget _hero(AppPalette p, AcademicReport r, double? delta, String? since) {
    final cgpa = r.cgpa;
    final credits = _num(r.creditsRegistered);
    final earned = _num(r.creditsEarned);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromColor(_changed ? p.orange : p.blue).withLightness(HSLColor.fromColor(_changed ? p.orange : p.blue).lightness.clamp(0.0, 0.42)).toColor(),
            Color.lerp(HSLColor.fromColor(_changed ? p.orange : p.blue).withLightness(HSLColor.fromColor(_changed ? p.orange : p.blue).lightness.clamp(0.0, 0.42)).toColor(), const Color(0xFF16102E), 0.72)!,
          ],
        ),
        boxShadow: [BoxShadow(color: (_changed ? p.orange : p.blue).withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AuthEyebrow(_changed ? 'What-if CGPA' : 'Cumulative CGPA', color: Colors.white70),
              const Spacer(),
              if (_changed && _original?.computedCgpa != null && r.computedCgpa != null)
                _vsActualPill(p, r.computedCgpa! - _original!.computedCgpa!)
              else if (delta != null && since != null)
                _deltaPill(p, delta, since),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: cgpa ?? 0),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => Text(
                  cgpa == null ? '--' : v.toStringAsFixed(2),
                  style: GoogleFonts.bricolageGrotesque(fontSize: 80, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -3.5, height: 1),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('/ 10', style: GoogleFonts.bricolageGrotesque(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white70)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(p, Icons.menu_book_outlined, '${r.courseCount} courses'),
              _chip(p, Icons.layers_outlined, '$earned of $credits credits'),
              _chip(p, Icons.calendar_month_outlined, '${r.semesters.length} semesters'),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: .04, end: 0, curve: Curves.easeOutCubic);
  }

  String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Widget _deltaPill(AppPalette p, double d, String since) {
    final up = d >= 0;
    final c = up ? p.green : p.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.withValues(alpha: 0.12), p.surface),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 13, color: c),
          const SizedBox(width: 3),
          Text(
            '${d.abs().toStringAsFixed(2)} since ${shortSemester(since)}',
            style: GoogleFonts.dmSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: c),
          ),
        ],
      ),
    );
  }

  Widget _chip(AppPalette p, IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(99), border: Border.all(color: p.line)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: p.inkSoft),
            const SizedBox(width: 6),
            Text(text, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: p.ink)),
          ],
        ),
      );

  Widget _insight(AppPalette p, IconData icon, String label, String value, String sub) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: p.blue),
            const SizedBox(height: 8),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w700, color: p.inkMuted)),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.bricolageGrotesque(fontSize: 20, fontWeight: FontWeight.w800, color: p.ink, letterSpacing: -0.5)),
            Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 11, height: 1.2, fontWeight: FontWeight.w600, color: p.inkSoft)),
          ],
        ),
      );

  // ------------------------------------------------------------------------
  // Semesters
  // ------------------------------------------------------------------------

  Widget _semesterCard(AppPalette p, SemesterReport s) {
    final open = _open.contains(s.label);
    final sorted = [...s.courses]..sort((a, b) {
        final d = (b.points ?? -1).compareTo(a.points ?? -1);
        return d != 0 ? d : a.code.compareTo(b.code);
      });
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => open ? _open.remove(s.label) : _open.add(s.label));
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.label, style: GoogleFonts.bricolageGrotesque(fontSize: 16, fontWeight: FontWeight.w800, color: p.ink)),
                        const SizedBox(height: 3),
                        Text(
                          '${s.courses.length} courses  ·  ${_num(s.credits)} credits${s.label == kPlannedSemester ? '  ·  what-if' : ''}',
                          style: GoogleFonts.dmSans(fontSize: 12, color: p.inkSoft, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final c in sorted)
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(color: gradeColor(c.grade), borderRadius: BorderRadius.circular(4.5)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        s.gpa == null ? '--' : s.gpa!.toStringAsFixed(2),
                        style: GoogleFonts.bricolageGrotesque(fontSize: 26, fontWeight: FontWeight.w800, color: p.ink, letterSpacing: -0.8),
                      ),
                      Text('GPA', style: GoogleFonts.bricolageGrotesque(fontSize: 10, fontWeight: FontWeight.w700, color: p.inkMuted, letterSpacing: 1.2)),
                      if (s.delta != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          '${s.delta! >= 0 ? '+' : '-'}${s.delta!.abs().toStringAsFixed(2)}',
                          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: s.delta! >= 0 ? p.green : p.red),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: p.inkMuted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? Column(
                    children: [
                      Divider(height: 1, color: p.line),
                      for (final c in sorted) _courseRow(p, c),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _courseRow(AppPalette p, ReportCourse c) {
    final planned = c.code.startsWith('PLAN-');
    final key = courseKey(c.code, c.semester);
    final original = _originalGrades[key];
    final changed = !planned && _overrides.containsKey(key);
    final color = gradeColor(c.grade);

    final tile = SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(top: 2, right: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color.alphaBlend(color.withValues(alpha: 0.18), p.surface),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: changed || planned ? p.orange : color.withValues(alpha: 0.4),
                width: changed || planned ? 1.8 : 1,
              ),
            ),
            child: Text(c.grade, style: GoogleFonts.bricolageGrotesque(fontSize: 14, fontWeight: FontWeight.w800, color: p.ink)),
          ),
          if (_edit)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: p.navy, shape: BoxShape.circle, border: Border.all(color: p.surface, width: 1.5)),
                child: Icon(Icons.edit_rounded, size: 9, color: p.onNavy),
              ),
            ),
        ],
      ),
    );

    final meta = planned
        ? 'Planned  ·  ${_num(c.credits)} credits'
        : '${c.code}  ·  ${_num(c.credits)} credits${c.type.isEmpty ? '' : '  ·  ${c.type}'}';

    return InkWell(
      onTap: _edit ? () => _pickGrade(c) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 9, 10, 9),
        child: Row(
          children: [
            tile,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.ink, height: 1.25)),
                  const SizedBox(height: 2),
                  if (changed && original != null)
                    Text(
                      'was $original  ·  ${_num(c.credits)} credits',
                      style: GoogleFonts.dmSans(fontSize: 11.5, color: p.orange, fontWeight: FontWeight.w800),
                    )
                  else
                    Text(meta, style: GoogleFonts.dmSans(fontSize: 11.5, color: p.inkMuted, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (_edit && changed)
              IconButton(
                tooltip: 'Back to $original',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _overrides.remove(key)),
                icon: Icon(Icons.undo_rounded, size: 18, color: p.inkSoft),
              ),
            if (planned)
              IconButton(
                tooltip: 'Remove this course',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _planned.removeWhere((x) => x.id == c.code.substring(5))),
                icon: Icon(Icons.close_rounded, size: 18, color: p.inkSoft),
              ),
          ],
        ),
      ),
    );
  }

  /// Explains what-if mode, summarises the change, and holds the actions.
  Widget _editBanner(AppPalette p, AcademicReport r) {
    final before = _original?.computedCgpa;
    final after = r.computedCgpa;
    final diff = (before != null && after != null) ? after - before : null;
    final up = (diff ?? 0) >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(p.orange.withValues(alpha: p.isDark ? 0.12 : 0.09), p.surface),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, size: 18, color: p.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _edit ? 'What-if mode' : 'You are looking at a what-if',
                  style: GoogleFonts.bricolageGrotesque(fontSize: 14.5, fontWeight: FontWeight.w800, color: p.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _changed
                ? '$_changeCount ${_changeCount == 1 ? 'change' : 'changes'}'
                    '${before != null && after != null ? ': CGPA ${before.toStringAsFixed(2)} to ${after.toStringAsFixed(2)}' : ''}'
                    '${diff != null ? ' (${up ? '+' : '-'}${diff.abs().toStringAsFixed(2)})' : ''}. Your real grades are not touched.'
                : 'Tap any grade to change it, or add a course. Everything recalculates as you go. Your real grades are not touched.',
            style: GoogleFonts.dmSans(fontSize: 12.5, height: 1.45, color: p.inkSoft),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              NexusButton(label: 'Add course', icon: Icons.add_rounded, dense: true, onTap: _addCourse),
              if (_changed) NexusButton(label: 'Reset', icon: Icons.restart_alt_rounded, dense: true, onTap: _reset),
              if (_edit) NexusButton(label: 'Done', icon: Icons.check_rounded, dense: true, filled: true, onTap: _toggleEdit),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vsActualPill(AppPalette p, double d) {
    final up = d >= 0;
    final c = d.abs() < 0.005 ? p.inkMuted : (up ? p.green : p.red);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.withValues(alpha: 0.12), p.surface),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(d.abs() < 0.005 ? Icons.remove_rounded : (up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded), size: 13, color: c),
          const SizedBox(width: 3),
          Text(
            '${d.abs().toStringAsFixed(2)} vs your actual',
            style: GoogleFonts.dmSans(fontSize: 11.5, fontWeight: FontWeight.w800, color: c),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------------
  // Lifts, drags and subject areas
  // ------------------------------------------------------------------------

  Widget _pulls(AppPalette p, AcademicReport r) {
    final lifts = r.lifts.take(3).toList();
    final drags = r.drags.take(3).toList();
    final maxImpact = [...lifts, ...drags].fold<double>(0.0001, (m, x) => x.impact.abs() > m ? x.impact.abs() : m);

    Widget row(CoursePull x) {
      final up = x.impact >= 0;
      final color = up ? p.green : p.red;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(x.course.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.ink)),
                ),
                const SizedBox(width: 8),
                Text('${up ? '+' : '-'}${x.impact.abs().toStringAsFixed(2)}', style: GoogleFonts.bricolageGrotesque(fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Text(
                  '${x.course.grade}  ·  ${_num(x.course.credits)} credits',
                  style: GoogleFonts.dmSans(fontSize: 11.5, color: p.inkMuted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: x.impact.abs() / maxImpact),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(value: v, minHeight: 5, backgroundColor: p.line, valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.85))),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget group(String title, Color color, List<CoursePull> list) => list.isEmpty
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 4, bottom: 2), child: AuthEyebrow(title, color: color)),
              for (final x in list) row(x),
            ],
          );

    return _card(
      p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          group('Pulled it up', p.green, lifts),
          if (lifts.isNotEmpty && drags.isNotEmpty) Divider(height: 22, color: p.line),
          group('Pulled it down', p.red, drags),
          const SizedBox(height: 10),
          Text(
            'Each figure is how far one course moved your CGPA compared with an average course: credits times (grade points minus your CGPA), shared across all graded credits.',
            style: GoogleFonts.dmSans(fontSize: 11.5, height: 1.45, color: p.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _areas(AppPalette p, AcademicReport r) {
    final list = r.areas.take(6).toList();
    return _card(
      p,
      child: Column(
        children: [
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  width: 46,
                  child: Text(list[i].prefix, style: GoogleFonts.bricolageGrotesque(fontSize: 12.5, fontWeight: FontWeight.w800, color: p.inkSoft)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(list[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.ink))),
                          Text(list[i].average.toStringAsFixed(2), style: GoogleFonts.bricolageGrotesque(fontSize: 13.5, fontWeight: FontWeight.w800, color: p.ink)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: (list[i].average / 10).clamp(0, 1)),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: p.line, valueColor: AlwaysStoppedAnimation(p.blue.withValues(alpha: 0.8))),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${list[i].courses} courses  ·  ${_num(list[i].credits)} credits', style: GoogleFonts.dmSans(fontSize: 11.5, color: p.inkMuted, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// Share picture sheet
// ===========================================================================

class _PictureSheet extends StatefulWidget {
  final AcademicReport report;
  final bool whatIf;
  const _PictureSheet({required this.report, this.whatIf = false});

  @override
  State<_PictureSheet> createState() => _PictureSheetState();
}

class _PictureSheetState extends State<_PictureSheet> {
  late final Future<Uint8List> _png = JourneyImage.render(widget.report, now: DateTime.now(), whatIf: widget.whatIf);
  bool _sharing = false;

  Future<void> _share(Uint8List bytes) async {
    setState(() => _sharing = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/nexus_journey_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'image/png')], text: 'My academic journey, made with VITAP Nexus'));
    } catch (_) {
      if (mounted) nexusToast(context, 'Could not open the share sheet.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final maxH = MediaQuery.sizeOf(context).height * 0.52;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Share your journey', style: GoogleFonts.bricolageGrotesque(fontSize: 26, fontWeight: FontWeight.w800, color: p.ink, letterSpacing: -0.8)),
        const SizedBox(height: 6),
        Text(
          'A picture of your CGPA, semester path and grade mix. It has no name, registration number or course list.',
          style: GoogleFonts.dmSans(fontSize: 13.5, height: 1.45, color: p.inkSoft),
        ),
        const SizedBox(height: 16),
        FutureBuilder<Uint8List>(
          future: _png,
          builder: (context, snap) {
            if (snap.hasError) return Text('Could not draw the picture.', style: GoogleFonts.dmSans(color: p.red));
            if (!snap.hasData) {
              return SizedBox(height: maxH, child: const Center(child: CircularProgressIndicator(strokeWidth: 2)));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxH),
                    child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.memory(snap.data!, fit: BoxFit.contain, gaplessPlayback: true)),
                  ),
                ),
                const SizedBox(height: 16),
                NexusButton(
                  label: _sharing ? 'Opening…' : 'Share picture',
                  icon: Icons.ios_share_rounded,
                  filled: true,
                  onTap: _sharing ? null : () => _share(snap.data!),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ===========================================================================
// Grade picker and "add a course"
// ===========================================================================

String _points(String g) {
  final v = kGradePoints[g];
  return g == 'P' ? 'Pass' : (v?.toString() ?? '-');
}

class _GradeTile extends StatelessWidget {
  final String grade;
  final bool selected;
  final VoidCallback onTap;
  const _GradeTile({required this.grade, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = gradeColor(grade);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 68,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Color.alphaBlend(color.withValues(alpha: selected ? 0.28 : 0.10), p.surface),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : color.withValues(alpha: 0.35), width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Text(grade, style: GoogleFonts.bricolageGrotesque(fontSize: 22, fontWeight: FontWeight.w800, color: p.ink)),
            const SizedBox(height: 2),
            Text(_points(grade), style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: p.inkSoft)),
          ],
        ),
      ),
    );
  }
}

class _GradePickerSheet extends StatelessWidget {
  final String title;
  final double credits;
  final String current;
  final String? original;
  const _GradePickerSheet({required this.title, required this.credits, required this.current, required this.original});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AuthEyebrow('Try a different grade', color: p.orange),
        const SizedBox(height: 6),
        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.bricolageGrotesque(fontSize: 21, fontWeight: FontWeight.w800, color: p.ink, letterSpacing: -0.5, height: 1.15)),
        const SizedBox(height: 4),
        Text(
          '${credits == credits.roundToDouble() ? credits.toStringAsFixed(0) : credits.toString()} credits${original == null ? '' : '  ·  VTOP grade: $original'}',
          style: GoogleFonts.dmSans(fontSize: 13, color: p.inkSoft),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final g in kPickableGrades) _GradeTile(grade: g, selected: g == current, onTap: () => Navigator.of(context).pop(g)),
          ],
        ),
        if (original != null && original != current && kPickableGrades.contains(original)) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: NexusButton(label: 'Back to $original', icon: Icons.undo_rounded, onTap: () => Navigator.of(context).pop(original)),
          ),
        ],
      ],
    );
  }
}

class _AddCourseSheet extends StatefulWidget {
  const _AddCourseSheet();

  @override
  State<_AddCourseSheet> createState() => _AddCourseSheetState();
}

class _AddCourseSheetState extends State<_AddCourseSheet> {
  final TextEditingController _title = TextEditingController();
  double _credits = 3;
  String _grade = 'A';

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: c, width: w));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AuthEyebrow('What if I take…', color: p.orange),
        const SizedBox(height: 6),
        Text('Add a course', style: GoogleFonts.bricolageGrotesque(fontSize: 24, fontWeight: FontWeight.w800, color: p.ink, letterSpacing: -0.7)),
        const SizedBox(height: 14),
        TextField(
          controller: _title,
          maxLength: 48,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: p.ink),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Course name (optional)',
            filled: true,
            fillColor: p.soft,
            border: border(p.line),
            enabledBorder: border(p.line),
            focusedBorder: border(p.blue, 1.5),
          ),
        ),
        const SizedBox(height: 16),
        const AuthEyebrow('Credits'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final c in const [1.0, 2.0, 3.0, 4.0, 5.0])
              ChoiceChip(
                label: Text(c.toStringAsFixed(0)),
                selected: _credits == c,
                onSelected: (_) => setState(() => _credits = c),
                labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: _credits == c ? p.onNavy : p.ink),
                selectedColor: p.navy,
                backgroundColor: p.surface,
                side: BorderSide(color: _credits == c ? p.navy : p.line),
                showCheckmark: false,
              ),
          ],
        ),
        const SizedBox(height: 16),
        const AuthEyebrow('Grade you expect'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final g in kPickableGrades) _GradeTile(grade: g, selected: g == _grade, onTap: () => setState(() => _grade = g)),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: NexusButton(
            label: 'Add to my journey',
            icon: Icons.add_rounded,
            filled: true,
            onTap: () => Navigator.of(context).pop((title: _title.text.trim(), credits: _credits, grade: _grade)),
          ),
        ),
      ],
    );
  }
}
