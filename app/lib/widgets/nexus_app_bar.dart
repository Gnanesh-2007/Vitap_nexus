import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Nexus page header: a round back button, a big title with a small line
/// under it, and round action buttons. Used by every inner screen.
class NexusAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;
  final bool showBack;
  final VoidCallback? onBack;

  const NexusAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.bottom,
    this.showBack = true,
    this.onBack,
  });

  @override
  Size get preferredSize => Size.fromHeight(86 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final canPop = showBack && (onBack != null || Navigator.of(context).canPop());
    return Material(
      color: p.paper,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 86,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    if (canPop) ...[
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          if (onBack != null) {
                            onBack!();
                          } else {
                            Navigator.of(context).maybePop();
                          }
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: p.soft, shape: BoxShape.circle),
                          child: Icon(Icons.arrow_back_rounded, size: 21, color: p.ink),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: p.ink,
                              height: 1.05,
                              letterSpacing: -0.8,
                            ),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.inkMuted),
                            ),
                        ],
                      ),
                    ),
                    for (final a in actions) ...[
                      const SizedBox(width: 8),
                      _Round(child: a),
                    ],
                  ],
                ),
              ),
            ),
            ?bottom,
          ],
        ),
      ),
    );
  }
}

/// Wraps an action (usually an IconButton) in the round soft background.
class _Round extends StatelessWidget {
  final Widget child;
  const _Round({required this.child});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: p.soft, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: IconTheme(
        data: IconThemeData(color: p.ink, size: 20),
        child: child,
      ),
    );
  }
}
