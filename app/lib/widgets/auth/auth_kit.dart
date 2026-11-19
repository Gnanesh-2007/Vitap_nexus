import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

/// Shared building blocks for the sign-in flow (login, welcome tour, OTP).
///
/// Design rule for everything in here: quiet. Depth comes from hairlines,
/// soft tints and small, slow motion - never from gloss, glow or shine.

// ---------------------------------------------------------------------------
// Backdrop
// ---------------------------------------------------------------------------

/// A paper-like background: a faint dot grid that fades out down the page and
/// a soft wash of the theme colour that drifts very slowly.
class AuthBackdrop extends StatefulWidget {
  final Widget child;
  const AuthBackdrop({super.key, required this.child});

  @override
  State<AuthBackdrop> createState() => _AuthBackdropState();
}

class _AuthBackdropState extends State<AuthBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _drift,
              builder: (_, _) => CustomPaint(
                painter: _BackdropPainter(
                  t: Curves.easeInOut.transform(_drift.value),
                  accent: p.blue,
                  warm: p.orange,
                  ink: p.ink,
                  isDark: p.isDark,
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final double t;
  final Color accent;
  final Color warm;
  final Color ink;
  final bool isDark;

  _BackdropPainter({
    required this.t,
    required this.accent,
    required this.warm,
    required this.ink,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Soft colour wash, top right. Drifts a few pixels over ~16s.
    final c1 = Offset(size.width * (0.86 + 0.05 * t), size.height * (-0.04 + 0.03 * t));
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: isDark ? 0.17 : 0.11),
            accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c1, radius: size.width * 0.95)),
    );

    // A much fainter warm counterweight, bottom left.
    final c2 = Offset(size.width * (0.02 - 0.04 * t), size.height * (1.02 - 0.02 * t));
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            warm.withValues(alpha: isDark ? 0.07 : 0.05),
            warm.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c2, radius: size.width * 0.8)),
    );

    // Dot grid, strongest near the top and gone by ~55% of the height.
    const step = 22.0;
    final dot = Paint();
    final fadeEnd = size.height * 0.55;
    for (double y = step; y < fadeEnd; y += step) {
      final fade = 1 - (y / fadeEnd);
      dot.color = ink.withValues(alpha: (isDark ? 0.10 : 0.075) * fade * fade);
      for (double x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 0.9, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.t != t || old.accent != accent || old.isDark != isDark || old.ink != ink;
}

// ---------------------------------------------------------------------------
// Small text helpers
// ---------------------------------------------------------------------------

/// Tiny tracked-out caps label, e.g. "6-DIGIT CODE".
class AuthEyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  const AuthEyebrow(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.bricolageGrotesque(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: color ?? p.inkMuted,
      ),
    );
  }
}

/// Three dots that breathe in sequence. Used inside buttons while waiting.
class AuthWaitingDots extends StatelessWidget {
  final Color color;
  const AuthWaitingDots({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Container(
          width: 4.5,
          height: 4.5,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fade(
              begin: 0.25,
              end: 1,
              duration: 520.ms,
              delay: (i * 160).ms,
              curve: Curves.easeInOut,
            );
      }),
    );
  }
}

/// A round icon badge with two thin rings that expand and fade behind it.
class AuthPulseBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool pulsing;
  final double size;

  const AuthPulseBadge({
    super.key,
    required this.icon,
    required this.color,
    this.pulsing = true,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget ring(int delayMs) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.55, 1.55),
              duration: 2600.ms,
              delay: delayMs.ms,
              curve: Curves.easeOut,
            )
            .fadeOut(duration: 2600.ms, delay: delayMs.ms, curve: Curves.easeOut);

    return SizedBox(
      width: size * 1.6,
      height: size * 1.6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (pulsing) ring(0),
          if (pulsing) ring(1300),
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.alphaBlend(color.withValues(alpha: 0.10), p.surface),
              border: Border.all(color: color.withValues(alpha: 0.30)),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              transitionBuilder: (child, a) => ScaleTransition(
                scale: Tween(begin: 0.7, end: 1.0).animate(a),
                child: FadeTransition(opacity: a, child: child),
              ),
              child: Icon(icon, key: ValueKey(icon), color: color, size: size * 0.44),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// OTP code cells
// ---------------------------------------------------------------------------

enum OtpCellsState { idle, error, success }

/// Six separate cells in a 3 + 3 grouping. Purely visual: the caller owns the
/// real (invisible) text field and passes the current [code] in.
class OtpCodeCells extends StatelessWidget {
  final String code;
  final bool hasFocus;
  final bool dimmed;
  final OtpCellsState state;

  /// Bump this to replay the "wrong code" shake.
  final int shakeTick;

  const OtpCodeCells({
    super.key,
    required this.code,
    required this.hasFocus,
    this.dimmed = false,
    this.state = OtpCellsState.idle,
    this.shakeTick = 0,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    Widget cell(int i) {
      final char = i < code.length ? code[i] : '';
      final filled = char.isNotEmpty;
      final active = hasFocus &&
          state == OtpCellsState.idle &&
          (i == code.length || (code.length == 6 && i == 5));

      final Color border = switch (state) {
        OtpCellsState.error => p.red.withValues(alpha: 0.75),
        OtpCellsState.success => p.green.withValues(alpha: 0.8),
        OtpCellsState.idle => active
            ? p.blue
            : (filled ? p.ink.withValues(alpha: 0.28) : p.line),
      };
      final Color fill = switch (state) {
        OtpCellsState.error => Color.alphaBlend(p.red.withValues(alpha: 0.06), p.surface),
        OtpCellsState.success => Color.alphaBlend(p.green.withValues(alpha: 0.08), p.surface),
        OtpCellsState.idle =>
          active ? Color.alphaBlend(p.blue.withValues(alpha: 0.06), p.surface) : p.soft,
      };

      return Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 3.5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: active ? 1.6 : 1.1),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, a) => ScaleTransition(
              scale: Tween(begin: 0.8, end: 1.0)
                  .animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
              child: FadeTransition(opacity: a, child: child),
            ),
            child: filled
                ? Text(
                    char,
                    key: ValueKey('d$i$char'),
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: state == OtpCellsState.success ? p.green : p.ink,
                      height: 1,
                    ),
                  )
                : active
                    ? Container(
                        key: const ValueKey('caret'),
                        width: 2,
                        height: 22,
                        decoration: BoxDecoration(
                          color: p.blue,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .fade(begin: 1, end: 0.15, duration: 520.ms)
                    : const SizedBox.shrink(key: ValueKey('empty')),
          ),
        ),
      );
    }

    Widget row = Row(
      children: [
        cell(0),
        cell(1),
        cell(2),
        Container(
          width: 10,
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: p.line,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        cell(3),
        cell(4),
        cell(5),
      ],
    );

    if (shakeTick > 0) {
      row = row
          .animate(key: ValueKey('shake$shakeTick'))
          .shakeX(hz: 5, amount: 5, duration: 380.ms, curve: Curves.easeOut);
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: dimmed ? 0.55 : 1,
      child: row,
    );
  }
}

/// Thin line showing how long the emailed code is still valid.
class OtpExpiryBar extends StatelessWidget {
  final int secondsLeft;
  final int totalSeconds;

  const OtpExpiryBar({
    super.key,
    required this.secondsLeft,
    this.totalSeconds = 180,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final frac = (secondsLeft / totalSeconds).clamp(0.0, 1.0);
    final low = secondsLeft <= 30;
    final color = secondsLeft == 0 ? p.inkMuted : (low ? p.orange : p.blue);

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: p.line)),
            AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 900),
              curve: Curves.linear,
              alignment: Alignment.centerLeft,
              widthFactor: math.max(frac, 0.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String otpClock(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
