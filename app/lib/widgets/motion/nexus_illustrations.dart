import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Hand-drawn, code-animated illustrations for empty / loading / error states.
enum NexusIllo {
  /// Sleepy crescent moon with rising "z"s: free day, nothing to do.
  rest,

  /// Magnifier sweeping with sparkles: search with no results.
  search,

  /// Open box releasing sakura petals: nothing here yet.
  empty,

  /// Paper plane gliding along a wave with a dotted trail: loading.
  loading,

  /// Storm cloud with flickering bolt: something went wrong.
  error,
}

class NexusIllustration extends StatefulWidget {
  final NexusIllo kind;
  final double size;
  const NexusIllustration({super.key, required this.kind, this.size = 140});

  @override
  State<NexusIllustration> createState() => _NexusIllustrationState();
}

class _NexusIllustrationState extends State<NexusIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 0.3;
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _IlloPainter(
            kind: widget.kind,
            t: _c,
            accent: p.blue,
            accent2: p.navy,
            ink: p.ink,
            soft: p.soft,
            line: p.line,
            warm: p.orange,
            danger: p.red,
          ),
        ),
      ),
    );
  }
}

class _IlloPainter extends CustomPainter {
  final NexusIllo kind;
  final Animation<double> t;
  final Color accent, accent2, ink, soft, line, warm, danger;

  _IlloPainter({
    required this.kind,
    required this.t,
    required this.accent,
    required this.accent2,
    required this.ink,
    required this.soft,
    required this.line,
    required this.warm,
    required this.danger,
  }) : super(repaint: t);

  static const _tau = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case NexusIllo.rest:
        _rest(canvas, size);
      case NexusIllo.search:
        _search(canvas, size);
      case NexusIllo.empty:
        _empty(canvas, size);
      case NexusIllo.loading:
        _loading(canvas, size);
      case NexusIllo.error:
        _error(canvas, size);
    }
  }

  // ---------------------------------------------------------------- helpers
  void _sparkle(Canvas canvas, Offset c, double r, Color color, double alpha) {
    if (alpha <= 0) return;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = color.withValues(alpha: alpha.clamp(0.0, 1.0)),
    );
  }

  void _ground(Canvas canvas, Size s, double sway) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s.width / 2, s.height * 0.88),
        width: s.width * (0.42 + sway * 0.04),
        height: s.height * 0.05,
      ),
      Paint()..color = line.withValues(alpha: 0.9),
    );
  }

  void _glyph(Canvas canvas, String text, Offset at, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  // ------------------------------------------------------------------ rest
  void _rest(Canvas canvas, Size s) {
    final v = t.value;
    final bob = math.sin(v * _tau) * s.height * 0.02;
    final c = Offset(s.width * 0.48, s.height * 0.5 + bob);
    final r = s.width * 0.27;

    // crescent
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: c, radius: r)),
      Path()
        ..addOval(Rect.fromCircle(
          center: c + Offset(r * 0.55, -r * 0.28),
          radius: r * 0.86,
        )),
    );
    canvas.drawShadow(moon, warm.withValues(alpha: 0.5), 8, false);
    canvas.drawPath(moon, Paint()..color = const Color(0xFFFFD166));

    // face (closed eye + blush)
    final eye = Paint()
      ..color = const Color(0xFF7A5200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.012
      ..strokeCap = StrokeCap.round;
    final ec = c + Offset(-r * 0.46, -r * 0.05);
    canvas.drawArc(
      Rect.fromCenter(center: ec, width: r * 0.34, height: r * 0.2),
      0.15,
      math.pi - 0.3,
      false,
      eye,
    );
    canvas.drawCircle(
      c + Offset(-r * 0.62, r * 0.2),
      r * 0.12,
      Paint()..color = const Color(0xFFFF8FA3).withValues(alpha: 0.7),
    );

    // twinkling stars
    const pts = [
      Offset(0.18, 0.2),
      Offset(0.8, 0.26),
      Offset(0.72, 0.7),
      Offset(0.25, 0.68),
      Offset(0.55, 0.12),
    ];
    for (var i = 0; i < pts.length; i++) {
      final a = 0.35 + 0.65 * (0.5 + 0.5 * math.sin((v * 2 + i * 0.23) * _tau));
      _sparkle(
        canvas,
        Offset(pts[i].dx * s.width, pts[i].dy * s.height),
        s.width * (0.022 + 0.01 * (i % 3)),
        accent2,
        a,
      );
    }

    // rising Zs
    for (var i = 0; i < 3; i++) {
      final ph = (v + i / 3) % 1;
      final pos = Offset(
        s.width * (0.64 + ph * 0.16),
        s.height * (0.42 - ph * 0.3),
      );
      _glyph(
        canvas,
        'z',
        pos,
        s.width * (0.08 + i * 0.022),
        accent.withValues(alpha: math.sin(ph * math.pi).clamp(0.0, 1.0)),
      );
    }
    _ground(canvas, s, math.sin(v * _tau));
  }

  // ---------------------------------------------------------------- search
  void _search(Canvas canvas, Size s) {
    final v = t.value;
    final sweep = math.sin(v * _tau);
    final c = Offset(
      s.width * 0.5 + sweep * s.width * 0.14,
      s.height * 0.46 + math.sin(v * _tau * 2) * s.height * 0.02,
    );
    final r = s.width * 0.18;

    // dotted path under the glass
    final dot = Paint()..color = line;
    for (var i = 0; i < 9; i++) {
      canvas.drawCircle(
        Offset(s.width * (0.2 + i * 0.075), s.height * 0.8),
        s.width * 0.008,
        dot,
      );
    }

    // handle
    final dir = Offset(math.cos(0.8), math.sin(0.8));
    final hStart = c + dir * r;
    final hEnd = c + dir * (r * 1.95);
    canvas.drawLine(
      hStart,
      hEnd,
      Paint()
        ..color = accent
        ..strokeWidth = s.width * 0.05
        ..strokeCap = StrokeCap.round,
    );
    // lens
    canvas.drawCircle(c, r, Paint()..color = soft);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * 0.035,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.66),
      math.pi * 1.1,
      math.pi * 0.45,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * 0.018
        ..strokeCap = StrokeCap.round,
    );
    // "?" inside
    _glyph(canvas, '?', c, r * 1.0, accent.withValues(alpha: 0.55));

    for (var i = 0; i < 3; i++) {
      final a = 0.4 + 0.6 * (0.5 + 0.5 * math.sin((v * 2 + i * 0.33) * _tau));
      _sparkle(
        canvas,
        Offset(s.width * (0.2 + i * 0.3), s.height * (0.22 + (i % 2) * 0.1)),
        s.width * 0.03,
        accent2,
        a,
      );
    }
  }

  // ----------------------------------------------------------------- empty
  void _empty(Canvas canvas, Size s) {
    final v = t.value;
    final bob = math.sin(v * _tau) * s.height * 0.015;
    final w = s.width * 0.46;
    final left = (s.width - w) / 2;
    final top = s.height * 0.5 + bob;

    // petals drifting up out of the box
    for (var i = 0; i < 6; i++) {
      final ph = (v + i / 6) % 1;
      final x = s.width * (0.34 + i * 0.065) + math.sin((ph + i) * _tau) * s.width * 0.04;
      final y = top - ph * s.height * 0.42;
      final a = math.sin(ph * math.pi).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(ph * _tau * 1.2 + i);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: s.width * 0.055,
          height: s.width * 0.03,
        ),
        Paint()..color = const Color(0xFFFFB7C5).withValues(alpha: a),
      );
      canvas.restore();
    }

    // box body + flaps
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, w, s.height * 0.26),
      Radius.circular(s.width * 0.03),
    );
    canvas.drawRRect(body, Paint()..color = accent.withValues(alpha: 0.9));
    canvas.drawRRect(
      body,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final flap = Paint()..color = accent2.withValues(alpha: 0.95);
    final lf = Path()
      ..moveTo(left, top)
      ..lineTo(left - w * 0.12, top - s.height * 0.07)
      ..lineTo(left + w * 0.34, top - s.height * 0.035)
      ..lineTo(left + w * 0.3, top)
      ..close();
    final rf = Path()
      ..moveTo(left + w, top)
      ..lineTo(left + w * 1.12, top - s.height * 0.07)
      ..lineTo(left + w * 0.66, top - s.height * 0.035)
      ..lineTo(left + w * 0.7, top)
      ..close();
    canvas.drawPath(lf, flap);
    canvas.drawPath(rf, flap);
    // label
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(s.width / 2, top + s.height * 0.13),
          width: w * 0.36,
          height: s.height * 0.045,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
    _sparkle(canvas, Offset(s.width * 0.2, s.height * 0.3), s.width * 0.03, accent2,
        0.4 + 0.6 * (0.5 + 0.5 * math.sin(v * _tau * 2)));
    _sparkle(canvas, Offset(s.width * 0.82, s.height * 0.22), s.width * 0.026, warm,
        0.4 + 0.6 * (0.5 + 0.5 * math.sin(v * _tau * 2 + 2)));
    _ground(canvas, s, math.sin(v * _tau));
  }

  // --------------------------------------------------------------- loading
  Offset _planePos(Size s, double u) => Offset(
        s.width * (0.08 + u * 0.84),
        s.height * 0.5 + math.sin(u * _tau * 1.5) * s.height * 0.16,
      );

  void _loading(Canvas canvas, Size s) {
    final v = t.value;
    // trail
    for (var i = 14; i >= 1; i--) {
      final u = v - i * 0.018;
      if (u < 0) continue;
      canvas.drawCircle(
        _planePos(s, u),
        s.width * 0.009 * (1 - i / 16),
        Paint()..color = accent2.withValues(alpha: (1 - i / 15) * 0.7),
      );
    }
    final pos = _planePos(s, v);
    final ahead = _planePos(s, math.min(1.0, v + 0.01));
    final ang = math.atan2(ahead.dy - pos.dy, ahead.dx - pos.dx);

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(ang);
    final u = s.width * 0.1;
    final wing = Path()
      ..moveTo(u, 0)
      ..lineTo(-u * 0.9, -u * 0.62)
      ..lineTo(-u * 0.45, 0)
      ..lineTo(-u * 0.9, u * 0.62)
      ..close();
    canvas.drawPath(wing, Paint()..color = accent);
    canvas.drawPath(
      Path()
        ..moveTo(u, 0)
        ..lineTo(-u * 0.45, 0)
        ..lineTo(-u * 0.9, u * 0.62)
        ..close(),
      Paint()..color = accent2,
    );
    canvas.restore();

    // drifting clouds
    for (var i = 0; i < 2; i++) {
      final x = ((v * (0.6 + i * 0.3)) + i * 0.5) % 1.2 - 0.1;
      final c = Offset(s.width * (1.05 - x), s.height * (0.22 + i * 0.52));
      final cp = Paint()..color = soft;
      canvas.drawCircle(c, s.width * 0.04, cp);
      canvas.drawCircle(c + Offset(s.width * 0.04, 0), s.width * 0.05, cp);
      canvas.drawCircle(c + Offset(s.width * 0.09, 0), s.width * 0.035, cp);
    }
  }

  // ----------------------------------------------------------------- error
  void _error(Canvas canvas, Size s) {
    final v = t.value;
    final wob = math.sin(v * _tau * 2) * s.width * 0.01;
    final c = Offset(s.width / 2 + wob, s.height * 0.42);
    final base = soft;
    final cloud = Paint()..color = Color.alphaBlend(ink.withValues(alpha: 0.12), base);
    canvas.drawCircle(c + Offset(-s.width * 0.12, s.height * 0.03), s.width * 0.12, cloud);
    canvas.drawCircle(c + Offset(s.width * 0.02, -s.height * 0.03), s.width * 0.16, cloud);
    canvas.drawCircle(c + Offset(s.width * 0.15, s.height * 0.04), s.width * 0.11, cloud);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + Offset(0, s.height * 0.06), width: s.width * 0.44, height: s.height * 0.12),
        Radius.circular(s.width * 0.06),
      ),
      cloud,
    );

    // flickering bolt
    final flick = (math.sin(v * _tau * 3) > 0.2) ? 1.0 : 0.35;
    final b = Offset(s.width * 0.5, s.height * 0.62);
    final bolt = Path()
      ..moveTo(b.dx + s.width * 0.02, b.dy - s.height * 0.02)
      ..lineTo(b.dx - s.width * 0.06, b.dy + s.height * 0.1)
      ..lineTo(b.dx - s.width * 0.005, b.dy + s.height * 0.1)
      ..lineTo(b.dx - s.width * 0.04, b.dy + s.height * 0.22)
      ..lineTo(b.dx + s.width * 0.08, b.dy + s.height * 0.05)
      ..lineTo(b.dx + s.width * 0.02, b.dy + s.height * 0.05)
      ..close();
    canvas.drawPath(bolt, Paint()..color = warm.withValues(alpha: flick));

    // rain
    for (var i = 0; i < 4; i++) {
      final ph = (v * 1.5 + i * 0.25) % 1;
      final x = s.width * (0.32 + i * 0.12);
      final y = s.height * (0.62 + ph * 0.2);
      canvas.drawLine(
        Offset(x, y),
        Offset(x - s.width * 0.01, y + s.height * 0.035),
        Paint()
          ..color = accent.withValues(alpha: 1 - ph)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
    _ground(canvas, s, math.sin(v * _tau));
  }

  @override
  bool shouldRepaint(covariant _IlloPainter old) =>
      old.kind != kind || old.accent != accent || old.accent2 != accent2 || old.ink != ink;
}
