import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/academic_report.dart';
import 'journey_widgets.dart';

/// A picture of the Academic Journey, drawn straight onto a canvas so it looks
/// the same on every phone. Shows the CGPA, the semester-by-semester chart and
/// the grade mix. It never includes a name, registration number or course list.
class JourneyImage {
  JourneyImage._();

  static const double width = 1080;
  static const double height = 1350;

  static const _bg1 = Color(0xFF0E121A);
  static const _bg2 = Color(0xFF171C29);
  static const _ink = Color(0xFFF4F6FB);
  static const _soft = Color(0xFFB4BCCF);
  static const _muted = Color(0xFF7D869B);
  static const _green = Color(0xFF4ADE80);
  static const _accent = Color(0xFF8FB4FF);
  static const _amber = Color(0xFFFBBF24);

  static Future<Uint8List> render(AcademicReport r, {required DateTime now, bool whatIf = false}) async {
    await _warmFonts();
    final logo = await _loadAsset('assets/images/vitap_nexus_logo.png');

    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    _background(c);
    _header(c, logo, now, whatIf);
    _hero(c, r, whatIf);
    _chartCard(c, r);
    _mixCard(c, r);
    _text(c, whatIf ? 'What-if simulation, not VTOP grades  ·  made with VITAP Nexus' : 'Made with VITAP Nexus', const Offset(width / 2, height - 78), _style(24, FontWeight.w700, _muted, spacing: 0.4), center: true);

    final image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  // ------------------------------------------------------------------------

  static void _background(Canvas c) {
    const rect = Rect.fromLTWH(0, 0, width, height);
    c.drawRect(rect, Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(width * 0.6, height), const [_bg2, _bg1]));
    c.drawRect(
      rect,
      Paint()..shader = ui.Gradient.radial(const Offset(width * 0.95, -60), width * 0.9, [_accent.withValues(alpha: 0.22), _accent.withValues(alpha: 0)]),
    );
    c.drawRect(
      rect,
      Paint()..shader = ui.Gradient.radial(const Offset(-40, height + 40), width * 0.75, [const Color(0xFFB07CFF).withValues(alpha: 0.13), const Color(0x00B07CFF)]),
    );
    final dot = Paint();
    const step = 36.0;
    const fadeEnd = height * 0.5;
    for (double y = step; y < fadeEnd; y += step) {
      final f = 1 - y / fadeEnd;
      dot.color = Colors.white.withValues(alpha: 0.07 * f * f);
      for (double x = step / 2; x < width; x += step) {
        c.drawCircle(Offset(x, y), 1.6, dot);
      }
    }
  }

  static void _header(Canvas c, ui.Image logo, DateTime now, bool whatIf) {
    const pad = 72.0;
    final n = logo.width.toDouble();
    final src = Rect.fromLTRB(n * 0.145, n * 0.13, n * 0.895, n * 0.88);
    final tile = RRect.fromRectAndRadius(const Rect.fromLTWH(pad, 68, 68, 68), const Radius.circular(17));
    c.save();
    c.clipRRect(tile);
    c.drawImageRect(logo, src, tile.outerRect, Paint()..filterQuality = FilterQuality.high);
    c.restore();
    _text(c, 'VITAP NEXUS', const Offset(pad + 88, 88), _style(26, FontWeight.w800, _ink, spacing: 3));
    _text(c, whatIf ? 'WHAT-IF SIMULATION' : 'ACADEMIC JOURNEY', const Offset(pad + 88, 118), _style(20, FontWeight.w700, whatIf ? _amber : _muted, spacing: 3.4));
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    _textRight(c, '${months[now.month - 1]} ${now.year}', const Offset(width - pad, 94), _style(24, FontWeight.w700, _soft, spacing: 2));
  }

  static void _hero(Canvas c, AcademicReport r, bool whatIf) {
    const pad = 72.0;
    _text(c, whatIf ? 'WHAT-IF CGPA' : 'CUMULATIVE CGPA', const Offset(pad, 196), _style(24, FontWeight.w800, whatIf ? _amber : _accent, spacing: 4));
    final cg = r.cgpa;
    _text(c, cg == null ? '--' : cg.toStringAsFixed(2), const Offset(pad - 6, 232), _style(232, FontWeight.w900, _ink, spacing: -8));

    // Change since the previous semester. The picture is made for posting, so a
    // dip is left off it; the screen in the app always shows it.
    final sems = r.semesters.where((s) => s.cumulative != null).toList();
    if (sems.length >= 2) {
      final d = sems.last.cumulative! - sems[sems.length - 2].cumulative!;
      if (d >= 0) {
        final text = '+${d.toStringAsFixed(2)}  since ${shortSemester(sems[sems.length - 2].label)}';
        final tp = _paint(text, _style(30, FontWeight.w800, _green));
        final px = width - pad - tp.width - 48;
        final box = RRect.fromRectAndRadius(Rect.fromLTWH(px, 330, tp.width + 48, 60), const Radius.circular(30));
        c.drawRRect(box, Paint()..color = _green.withValues(alpha: 0.14));
        tp.paint(c, Offset(px + 24, 346));
      }
    }

    final credits = r.creditsRegistered == r.creditsRegistered.roundToDouble() ? r.creditsRegistered.toStringAsFixed(0) : r.creditsRegistered.toStringAsFixed(1);
    _text(
      c,
      '${r.courseCount} courses  ·  $credits credits  ·  ${r.semesters.length} semesters',
      const Offset(pad, 446),
      _style(32, FontWeight.w600, _soft),
      maxWidth: width - pad * 2,
    );
  }

  static void _chartCard(Canvas c, AcademicReport r) {
    const pad = 72.0;
    const top = 520.0, h = 410.0;
    _card(c, const Rect.fromLTWH(pad, top, width - pad * 2, h));
    _text(c, 'SEMESTER GPA  ·  RUNNING CGPA', const Offset(pad + 36, top + 30), _style(22, FontWeight.w800, _accent, spacing: 3));
    c.save();
    c.translate(pad + 24, top + 70);
    TrendChartPainter(
      semesters: r.semesters,
      progress: 1,
      accent: _accent,
      ink: _ink,
      muted: _muted,
      grid: const Color(0x26FFFFFF),
      highlight: r.best?.label,
      labelScale: 1.45,
    ).paint(c, const Size(width - pad * 2 - 48, h - 90));
    c.restore();
  }

  static void _mixCard(Canvas c, AcademicReport r) {
    const pad = 72.0;
    const top = 958.0, h = 262.0;
    _card(c, const Rect.fromLTWH(pad, top, width - pad * 2, h));
    _text(c, 'GRADE MIX', const Offset(pad + 36, top + 30), _style(22, FontWeight.w800, _accent, spacing: 3));
    _textRight(
      c,
      '${(r.topShare * 100).round()}% of credits at A or better',
      const Offset(width - pad - 36, top + 28),
      _style(24, FontWeight.w700, _soft),
      maxWidth: 560,
    );

    final entries = [
      for (final g in kGradeOrder)
        if ((r.gradeCounts[g] ?? 0) > 0) MapEntry(g, r.gradeCounts[g]!),
    ];
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    if (total == 0) return;

    const barLeft = pad + 36.0;
    final barW = width - pad * 2 - 72;
    const barTop = top + 92.0;
    const barH = 34.0;
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(Rect.fromLTWH(barLeft, barTop, barW, barH), const Radius.circular(17)));
    var x = barLeft;
    for (final e in entries) {
      final w = (barW - 4.0 * (entries.length - 1)) * e.value / total;
      c.drawRect(Rect.fromLTWH(x, barTop, w, barH), Paint()..color = gradeColor(e.key));
      x += w + 4;
    }
    c.restore();

    var lx = barLeft;
    var ly = barTop + 66;
    for (final e in entries) {
      final label = '${e.key == 'P' ? 'Pass' : e.key}  ${e.value}';
      final tp = _paint(label, _style(26, FontWeight.w700, _ink));
      if (lx + tp.width + 40 > barLeft + barW) {
        lx = barLeft;
        ly += 40;
      }
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(lx, ly + 6, 16, 16), const Radius.circular(5)), Paint()..color = gradeColor(e.key));
      tp.paint(c, Offset(lx + 26, ly));
      lx += tp.width + 26 + 30;
    }
  }

  // ------------------------------------------------------------------------

  static void _card(Canvas c, Rect r) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(36));
    c.drawRRect(rr, Paint()..color = const Color(0x0DFFFFFF));
    c.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x26FFFFFF),
    );
  }

  static TextStyle _style(double size, FontWeight w, Color color, {double spacing = 0}) =>
      GoogleFonts.dmSans(fontSize: size, fontWeight: w, color: color, letterSpacing: spacing, height: 1.05);

  static TextPainter _paint(String s, TextStyle style, {double maxWidth = double.infinity}) =>
      TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…')..layout(maxWidth: maxWidth);

  static void _text(Canvas c, String s, Offset o, TextStyle style, {double maxWidth = double.infinity, bool center = false}) {
    final tp = _paint(s, style, maxWidth: maxWidth);
    tp.paint(c, center ? Offset(o.dx - tp.width / 2, o.dy) : o);
  }

  static void _textRight(Canvas c, String s, Offset o, TextStyle style, {double maxWidth = double.infinity}) {
    final tp = _paint(s, style, maxWidth: maxWidth);
    tp.paint(c, Offset(o.dx - tp.width, o.dy));
  }

  static Future<ui.Image> _loadAsset(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  static Future<void> _warmFonts() async {
    try {
      await GoogleFonts.pendingFonts([
        for (final w in [FontWeight.w600, FontWeight.w700, FontWeight.w800, FontWeight.w900]) GoogleFonts.dmSans(fontWeight: w),
      ]).timeout(const Duration(seconds: 6));
    } catch (_) {}
  }
}
