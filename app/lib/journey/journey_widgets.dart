import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/academic_report.dart';

/// One muted colour per grade, used by every chart on the Journey screen.
Color gradeColor(String grade) => switch (grade) {
      'S' => const Color(0xFF8B7CF6),
      'A' => const Color(0xFF34D399),
      'B' => const Color(0xFF60A5FA),
      'C' => const Color(0xFFFBBF24),
      'D' => const Color(0xFFFB923C),
      'E' => const Color(0xFFF472B6),
      'F' || 'N' => const Color(0xFFF87171),
      _ => const Color(0xFF94A3B8),
    };

/// "Nov-2025" -> "Nov 25".
String shortSemester(String label) {
  final m = RegExp(r'([A-Za-z]{3})[A-Za-z]*[-\s/]*(\d{4})').firstMatch(label);
  if (m == null) return label.length > 7 ? label.substring(0, 7) : label;
  return '${m.group(1)} ${m.group(2)!.substring(2)}';
}

/// Semester GPAs as bars, with the running CGPA drawn over them as a line.
///
/// Used both on screen (animated by [progress]) and when drawing the shareable
/// picture, so it only needs a canvas and a size.
class TrendChartPainter extends CustomPainter {
  final List<SemesterReport> semesters;
  final double progress; // 0..1, bars grow and the line draws in
  final Color accent;
  final Color ink;
  final Color muted;
  final Color grid;
  final String? highlight; // semester label to emphasise (the best one)
  final double labelScale;

  TrendChartPainter({
    required this.semesters,
    required this.progress,
    required this.accent,
    required this.ink,
    required this.muted,
    required this.grid,
    this.highlight,
    this.labelScale = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (semesters.isEmpty) return;
    final s = labelScale;
    final left = 34.0 * s, right = 10.0 * s, top = 26.0 * s, bottom = 28.0 * s;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    if (w <= 0 || h <= 0) return;

    final values = <double>[
      for (final x in semesters) ...[if (x.gpa != null) x.gpa!, if (x.cumulative != null) x.cumulative!],
    ];
    if (values.isEmpty) return;
    var lo = (values.reduce(math.min) - 0.45).floorToDouble();
    var hi = (values.reduce(math.max) + 0.25).ceilToDouble().clamp(lo + 2, 10).toDouble();
    if (hi - lo < 2) lo = hi - 2;
    lo = lo.clamp(0, 8).toDouble();

    double y(double v) => top + (1 - (v - lo) / (hi - lo)) * h;
    final n = semesters.length;
    final step = w / n;
    double cx(int i) => left + step * (i + 0.5);
    final ease = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));

    // Grid and y labels.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final v in [lo, (lo + hi) / 2, hi]) {
      canvas.drawLine(Offset(left, y(v)), Offset(size.width - right, y(v)), gridPaint);
      _text(canvas, v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1), Offset(left - 8 * s, y(v)),
          GoogleFonts.dmSans(fontSize: 10 * s, color: muted, fontWeight: FontWeight.w600), right: true, vCenter: true);
    }

    // Bars: each semester's own GPA.
    final barW = math.min(step * 0.46, 44 * s);
    for (var i = 0; i < n; i++) {
      final g = semesters[i].gpa;
      if (g == null) continue;
      final full = y(lo) - y(g);
      final hgt = full * ease;
      final isHi = semesters[i].label == highlight;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx(i) - barW / 2, y(lo) - hgt, barW, hgt),
        topLeft: Radius.circular(8 * s),
        topRight: Radius.circular(8 * s),
      );
      canvas.drawRRect(rect, Paint()..color = accent.withValues(alpha: isHi ? 0.42 : 0.20));
      if (ease > 0.7) {
        _text(
          canvas,
          g.toStringAsFixed(2),
          Offset(cx(i), y(g) - 7 * s),
          GoogleFonts.dmSans(fontSize: 10.5 * s, color: ink.withValues(alpha: ((ease - 0.7) / 0.3).clamp(0, 1)), fontWeight: FontWeight.w800),
          center: true,
          bottomAnchored: true,
        );
      }
      _text(canvas, shortSemester(semesters[i].label), Offset(cx(i), size.height - bottom + 9 * s),
          GoogleFonts.dmSans(fontSize: 10 * s, color: muted, fontWeight: FontWeight.w600),
          center: true);
    }

    // Running CGPA: a line over the bars.
    final pts = <Offset>[
      for (var i = 0; i < n; i++)
        if (semesters[i].cumulative != null) Offset(cx(i), y(semesters[i].cumulative!)),
    ];
    if (pts.isNotEmpty) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        final mid = Offset((pts[i - 1].dx + pts[i].dx) / 2, (pts[i - 1].dy + pts[i].dy) / 2);
        path.quadraticBezierTo(pts[i - 1].dx, pts[i - 1].dy, mid.dx, mid.dy);
      }
      path.lineTo(pts.last.dx, pts.last.dy);

      final line = Paint()
        ..color = ink.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final m in path.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * ease), line);
      }
      for (var i = 0; i < pts.length; i++) {
        if (i / math.max(1, pts.length - 1) > ease + 0.001) break;
        canvas.drawCircle(pts[i], 4.6 * s, Paint()..color = ink);
        canvas.drawCircle(pts[i], 2.2 * s, Paint()..color = accent.withValues(alpha: 1));
      }
    }
  }

  void _text(
    Canvas c,
    String t,
    Offset o,
    TextStyle style, {
    bool center = false,
    bool right = false,
    bool vCenter = false,
    bool bottomAnchored = false,
  }) {
    final tp = TextPainter(text: TextSpan(text: t, style: style), textDirection: TextDirection.ltr)..layout();
    var dx = o.dx, dy = o.dy;
    if (center) dx -= tp.width / 2;
    if (right) dx -= tp.width;
    if (vCenter) dy -= tp.height / 2;
    if (bottomAnchored) dy -= tp.height;
    tp.paint(c, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(TrendChartPainter old) =>
      old.progress != progress || old.semesters != semesters || old.accent != accent || old.ink != ink;
}

/// A single bar split into grade segments, with the counts underneath.
class GradeMixBar extends StatelessWidget {
  final Map<String, int> counts;
  final Color muted;
  final Color ink;
  final double height;

  const GradeMixBar({super.key, required this.counts, required this.muted, required this.ink, this.height = 16});

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final g in kGradeOrder)
        if ((counts[g] ?? 0) > 0) MapEntry(g, counts[g]!),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, t, _) => ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: SizedBox(
              height: height,
              child: Row(
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      flex: entries[i].value,
                      child: FractionallySizedBox(
                        widthFactor: t,
                        alignment: Alignment.centerLeft,
                        child: Container(color: gradeColor(entries[i].key)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final e in entries)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: gradeColor(e.key), borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${e.key == 'P' ? 'Pass' : e.key}  ${e.value}',
                    style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: ink),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
