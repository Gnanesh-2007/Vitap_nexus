import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

// ============================================================================
// NEXUS MOTION & CREATIVE UI SUITE
// Inspired by:
// 1. Kokonut UI (kokonutui.com) - Shine border cards, rolling counters, gradient text
// 2. Anime.js (animejs.com) - Concentric radar ripples, elastic wave staggers
// 3. Bklit UI (bklit.com) - Sleek radial attendance gauges, mini sparkline bars
// 4. Motion.dev (motion.dev) - Touch-tracking spotlight cards & spring physics
// ============================================================================

// ============================================================================
// 1. KOKONUT UI: SHINE BORDER CARD
// Perimeter traveling gradient light beam around card borders
// ============================================================================

class KokonutShineCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final List<Color>? shineColors;
  final Color? backgroundColor;
  final Duration duration;
  final double borderWidth;
  final bool isShining;

  const KokonutShineCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(18),
    this.shineColors,
    this.backgroundColor,
    this.duration = const Duration(seconds: 4),
    this.borderWidth = 1.5,
    this.isShining = true,
  });

  @override
  State<KokonutShineCard> createState() => _KokonutShineCardState();
}

class _KokonutShineCardState extends State<KokonutShineCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    if (widget.isShining) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant KokonutShineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isShining != oldWidget.isShining) {
      if (widget.isShining) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final defaultColors = [
      palette.blue,
      palette.orange,
      palette.green,
      palette.blue,
    ];
    final colors = widget.shineColors ?? defaultColors;

    return AnimatedScale(
      scale: _isPressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: widget.onTap != null
            ? (_) {
                setState(() => _isPressed = true);
                HapticFeedback.selectionClick();
              }
            : null,
        onTapUp: widget.onTap != null ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: widget.onTap != null ? () => setState(() => _isPressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _ShineBorderPainter(
                progress: _controller.value,
                borderRadius: widget.borderRadius,
                borderWidth: widget.borderWidth,
                colors: colors,
                baseBorderColor: palette.line,
                isShining: widget.isShining,
              ),
              child: Container(
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? palette.surface,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: palette.ink.withValues(alpha: palette.isDark ? 0.14 : 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: widget.child,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShineBorderPainter extends CustomPainter {
  final double progress;
  final double borderRadius;
  final double borderWidth;
  final List<Color> colors;
  final Color baseBorderColor;
  final bool isShining;

  _ShineBorderPainter({
    required this.progress,
    required this.borderRadius,
    required this.borderWidth,
    required this.colors,
    required this.baseBorderColor,
    required this.isShining,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // 1. Base border
    final basePaint = Paint()
      ..color = baseBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRRect(rrect, basePaint);

    if (!isShining) return;

    // 2. Animated sweep shine
    final sweepGradient = SweepGradient(
      center: Alignment.center,
      colors: [
        Colors.transparent,
        ...colors,
        Colors.transparent,
      ],
      transform: GradientRotation(progress * 2 * math.pi),
    );

    final shinePaint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth * 1.5;

    canvas.drawRRect(rrect, shinePaint);
  }

  @override
  bool shouldRepaint(covariant _ShineBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isShining != isShining ||
        oldDelegate.borderRadius != borderRadius;
  }
}

// ============================================================================
// 2. KOKONUT UI: ROLLING NUMBER / ANIMATED COUNTER
// Smooth number rolling up into place with easing physics
// ============================================================================

class KokonutRollingNumber extends StatefulWidget {
  final double value;
  final String prefix;
  final String suffix;
  final int fractionDigits;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  const KokonutRollingNumber({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.fractionDigits = 1,
    this.style,
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeOutExpo,
  });

  @override
  State<KokonutRollingNumber> createState() => _KokonutRollingNumberState();
}

class _KokonutRollingNumberState extends State<KokonutRollingNumber>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousValue = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _previousValue = widget.value;
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant KokonutRollingNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(begin: _previousValue, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: widget.curve),
      );
      _previousValue = widget.value;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final defaultStyle = GoogleFonts.spaceGrotesk(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: palette.ink,
      letterSpacing: -0.5,
    );

    final finalFormatted = widget.fractionDigits > 0
        ? widget.value.toStringAsFixed(widget.fractionDigits)
        : widget.value.toInt().toString();
    final semanticString = '${widget.prefix}$finalFormatted${widget.suffix}';

    if (MediaQuery.of(context).disableAnimations) {
      return Semantics(
        value: semanticString,
        child: Text(
          semanticString,
          style: widget.style ?? defaultStyle,
        ),
      );
    }

    return Semantics(
      value: semanticString,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final currentVal = _animation.value;
          final formatted = widget.fractionDigits > 0
              ? currentVal.toStringAsFixed(widget.fractionDigits)
              : currentVal.toInt().toString();

          return Text(
            '${widget.prefix}$formatted${widget.suffix}',
            style: widget.style ?? defaultStyle,
          );
        },
      ),
    );
  }
}

// ============================================================================
// 3. ANIME.JS: CONCENTRIC RADAR RIPPLE WAVE
// Pulsing concentric ripple waves radiating outwards (Live class, sync indicator)
// ============================================================================

class AnimeRadarWave extends StatefulWidget {
  final Color color;
  final double size;
  final Widget? centerWidget;
  final int ringCount;
  final Duration duration;

  const AnimeRadarWave({
    super.key,
    required this.color,
    this.size = 28,
    this.centerWidget,
    this.ringCount = 3,
    this.duration = const Duration(milliseconds: 1800),
  });

  @override
  State<AnimeRadarWave> createState() => _AnimeRadarWaveState();
}

class _AnimeRadarWaveState extends State<AnimeRadarWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Radiating rings
          ...List.generate(widget.ringCount, (index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final delayFraction = index / widget.ringCount;
                final progress = (_controller.value + delayFraction) % 1.0;
                final currentScale = 0.4 + (progress * 0.9);
                final currentOpacity = (1.0 - progress).clamp(0.0, 0.7);

                return Transform.scale(
                  scale: currentScale,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.color.withValues(alpha: currentOpacity),
                        width: 1.5,
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Center icon or dot
          if (widget.centerWidget != null)
            widget.centerWidget!
          else
            Container(
              width: widget.size * 0.35,
              height: widget.size * 0.35,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. BKLIT UI: RADIAL ATTENDANCE GAUGE
// Modern semi-circular arc gauge with target threshold & rolling stats
// ============================================================================

class BklitGaugeMeter extends StatelessWidget {
  final double percentage; // 0.0 to 100.0
  final double targetPercentage; // e.g. 75.0
  final double size;
  final double strokeWidth;
  final String title;
  final String subtitle;
  final Color? trackColor;

  const BklitGaugeMeter({
    super.key,
    required this.percentage,
    this.targetPercentage = 75.0,
    this.size = 140,
    this.strokeWidth = 10,
    this.title = 'Overall Attendance',
    this.subtitle = '75% Minimum Required',
    this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final clamped = percentage.clamp(0.0, 100.0);

    // Color zone determination
    Color progressColor;
    if (clamped >= 85) {
      progressColor = palette.green;
    } else if (clamped >= targetPercentage) {
      progressColor = palette.blue;
    } else if (clamped >= 65) {
      progressColor = palette.orange;
    } else {
      progressColor = palette.red;
    }

    final statusLabel = clamped >= targetPercentage ? 'Safe Zone' : 'Attention Required';
    final semanticLabel = '$title: ${clamped.toStringAsFixed(1)} percent, $statusLabel. Target: ${targetPercentage.toInt()} percent.';

    return Semantics(
      label: semanticLabel,
      value: '${clamped.toStringAsFixed(1)}%',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
          width: size,
          height: size * 0.72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size * 0.72),
                painter: _GaugePainter(
                  percentage: clamped,
                  targetPercentage: targetPercentage,
                  strokeWidth: strokeWidth,
                  progressColor: progressColor,
                  trackColor: trackColor ?? palette.line.withValues(alpha: 0.7),
                  targetMarkerColor: palette.ink,
                ),
              ),
              Positioned(
                bottom: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${clamped.toStringAsFixed(1)}%',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: size * 0.2,
                        fontWeight: FontWeight.w900,
                        color: progressColor,
                        letterSpacing: -0.6,
                      ),
                    ),
                    Text(
                      clamped >= targetPercentage ? 'SAFE ZONE' : 'ATTENTION REQUIRED',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: clamped >= targetPercentage ? palette.green : palette.red,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (title.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
        ],
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: palette.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percentage;
  final double targetPercentage;
  final double strokeWidth;
  final Color progressColor;
  final Color trackColor;
  final Color targetMarkerColor;

  _GaugePainter({
    required this.percentage,
    required this.targetPercentage,
    required this.strokeWidth,
    required this.progressColor,
    required this.trackColor,
    required this.targetMarkerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.82);
    final radius = (size.width - strokeWidth) / 2;

    const startAngle = math.pi * 0.85;
    const sweepTotalAngle = math.pi * 1.3;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // 1. Draw track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotalAngle,
      false,
      trackPaint,
    );

    // 2. Draw active progress
    final sweepProgress = sweepTotalAngle * (percentage / 100.0);
    if (sweepProgress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepProgress,
        false,
        progressPaint,
      );
    }

    // 3. Draw 75% target threshold tick
    final targetAngle = startAngle + (sweepTotalAngle * (targetPercentage / 100.0));
    final targetTickStart = Offset(
      center.dx + (radius - strokeWidth / 2 - 2) * math.cos(targetAngle),
      center.dy + (radius - strokeWidth / 2 - 2) * math.sin(targetAngle),
    );
    final targetTickEnd = Offset(
      center.dx + (radius + strokeWidth / 2 + 3) * math.cos(targetAngle),
      center.dy + (radius + strokeWidth / 2 + 3) * math.sin(targetAngle),
    );

    final tickPaint = Paint()
      ..color = targetMarkerColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(targetTickStart, targetTickEnd, tickPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.progressColor != progressColor;
  }
}

// ============================================================================
// 5. MOTION.DEV: SPOTLIGHT INTERACTIVE CARD
// Dynamic radial spotlight glow that tracks touch location across card surface
// ============================================================================

class MotionSpotlightCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? spotlightColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final double spotlightRadius;

  const MotionSpotlightCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 18,
    this.padding = const EdgeInsets.all(16),
    this.spotlightColor,
    this.backgroundColor,
    this.borderColor,
    this.spotlightRadius = 140,
  });

  @override
  State<MotionSpotlightCard> createState() => _MotionSpotlightCardState();
}

class _MotionSpotlightCardState extends State<MotionSpotlightCard> {
  Offset? _spotlightPosition;
  bool _isHovering = false;
  bool _isPressed = false;

  void _updatePosition(Offset localPosition) {
    setState(() {
      _spotlightPosition = localPosition;
      _isHovering = true;
    });
  }

  void _clearPosition() {
    setState(() {
      _isHovering = false;
      _isPressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final spotColor = widget.spotlightColor ??
        (palette.isDark
            ? palette.blue.withValues(alpha: 0.18)
            : palette.blue.withValues(alpha: 0.08));

    return AnimatedScale(
      scale: _isPressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onPanDown: (details) {
          setState(() => _isPressed = true);
          _updatePosition(details.localPosition);
          HapticFeedback.selectionClick();
        },
        onPanUpdate: (details) => _updatePosition(details.localPosition),
        onPanEnd: (_) => _clearPosition(),
        onPanCancel: () => _clearPosition(),
        onTapUp: (_) => _clearPosition(),
        onTapCancel: () => _clearPosition(),
        onTap: widget.onTap,
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? palette.surface,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: widget.borderColor ?? palette.line,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: palette.ink.withValues(alpha: palette.isDark ? 0.1 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (_isHovering && _spotlightPosition != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _SpotlightPainter(
                        center: _spotlightPosition!,
                        radius: widget.spotlightRadius,
                        color: spotColor,
                        borderRadius: widget.borderRadius,
                      ),
                    ),
                  ),
                ),
              widget.child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final Color color;
  final double borderRadius;

  _SpotlightPainter({
    required this.center,
    required this.radius,
    required this.color,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    canvas.clipRRect(rrect);

    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (center.dx / size.width) * 2 - 1,
          (center.dy / size.height) * 2 - 1,
        ),
        radius: radius / (size.width / 2),
        colors: [
          color,
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.center != center || oldDelegate.color != color;
  }
}

// ============================================================================
// 6. ANIME.JS: STAGGERED ENTRANCE CONTAINER
// Staggers the entrance of child widgets smoothly with subtle fade + slide
// ============================================================================

class AnimeStaggerItem extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration baseDelay;
  final Duration itemDuration;
  final double slideOffset;

  const AnimeStaggerItem({
    super.key,
    required this.index,
    required this.child,
    this.baseDelay = const Duration(milliseconds: 30),
    this.itemDuration = const Duration(milliseconds: 320),
    this.slideOffset = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return child;
    }

    final totalDelayMs = (index * baseDelay.inMilliseconds).clamp(0, 400);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: itemDuration,
      curve: Curves.easeOutCubic,
      builder: (context, value, animChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1.0 - value) * slideOffset),
            child: animChild,
          ),
        );
      },
      child: FutureBuilder<bool>(
        future: Future.delayed(Duration(milliseconds: totalDelayMs), () => true),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data == true) {
            return child;
          }
          // Hold invisible until stagger delay passes
          return Opacity(
            opacity: 0,
            child: child,
          );
        },
      ),
    );
  }
}

// ============================================================================
// 7. MOTION.DEV: SPRING TOUCH SCALE FEEDBACK
// Wraps any widget with micro-spring tactile press feedback
// ============================================================================

class NexusSpringPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final Duration duration;

  const NexusSpringPress({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.965,
    this.duration = const Duration(milliseconds: 140),
  });

  @override
  State<NexusSpringPress> createState() => _NexusSpringPressState();
}

class _NexusSpringPressState extends State<NexusSpringPress> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap != null
          ? (_) {
              setState(() => _isDown = true);
              HapticFeedback.selectionClick();
            }
          : null,
      onTapUp: widget.onTap != null ? (_) => setState(() => _isDown = false) : null,
      onTapCancel: widget.onTap != null ? () => setState(() => _isDown = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isDown ? widget.scaleDown : 1.0,
        duration: widget.duration,
        curve: _isDown ? Curves.easeOutCubic : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

// ============================================================================
// 8. NEXUS ANIMATED ATTENDANCE PROGRESS BAR
// Smoothly animates progress changes with theme-aware gradient shaders
// ============================================================================

class NexusAnimatedProgressBar extends StatelessWidget {
  final double percentage; // 0.0 to 100.0
  final double height;
  final Color? color;
  final Color? backgroundColor;
  final Duration duration;
  final BorderRadius? borderRadius;

  const NexusAnimatedProgressBar({
    super.key,
    required this.percentage,
    this.height = 6.0,
    this.color,
    this.backgroundColor,
    this.duration = const Duration(milliseconds: 650),
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final clampedRatio = (percentage / 100.0).clamp(0.0, 1.0);
    final barRadius = borderRadius ?? BorderRadius.circular(height / 2);
    final activeColor = color ?? palette.attendanceColor(percentage);
    final bgColor = backgroundColor ?? palette.soft;

    final semanticLabel = '${percentage.toStringAsFixed(1)} percent progress';

    return Semantics(
      label: semanticLabel,
      value: '${percentage.toStringAsFixed(1)}%',
      child: ClipRRect(
        borderRadius: barRadius,
        child: Container(
          height: height,
          width: double.infinity,
          color: bgColor,
          child: MediaQuery.of(context).disableAnimations
              ? FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: clampedRatio,
                  child: Container(
                    decoration: BoxDecoration(
                      color: activeColor,
                      borderRadius: barRadius,
                    ),
                  ),
                )
              : TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: clampedRatio),
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  builder: (context, val, _) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: val,
                      child: Container(
                        decoration: BoxDecoration(
                          color: activeColor,
                          borderRadius: barRadius,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

// ============================================================================
// 9. NEXUS FADE & SLIDE TRANSITION CONTAINER
// State switcher helper with ease-in-out physics
// ============================================================================

class NexusAnimatedStateSwitcher extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const NexusAnimatedStateSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 260),
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return child;
    }

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.04),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

