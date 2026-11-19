import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// A pill switch with one thumb that slides to the chosen label.
/// [position] is a fractional index, so it can follow a swipe live
/// (pass a TabController's animation value or a PageController's page).
class NexusSegmented extends StatelessWidget {
  final List<String> labels;
  final double position;
  final ValueChanged<int> onSelect;

  const NexusSegmented({
    super.key,
    required this.labels,
    required this.position,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final onInk = p.isDark ? Colors.black : Colors.white;
    final n = labels.length;
    final pos = position.clamp(0.0, (n - 1).toDouble());
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(23)),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / n;
          return Stack(
            children: [
              Positioned(
                left: pos * w,
                top: 0,
                width: w,
                height: c.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(19)),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < n; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onSelect(i);
                        },
                        child: Center(
                          child: Text(
                            labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              // Fades from muted to the thumb's text colour as the thumb arrives.
                              color: Color.lerp(p.inkMuted, onInk, (1 - (pos - i).abs()).clamp(0.0, 1.0)),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
