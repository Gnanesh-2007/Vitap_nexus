import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Small shared pieces for sheets and calm, outlined actions.

/// A quiet outlined action; [filled] makes it the primary one.
class NexusButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool filled;
  final bool dense;

  const NexusButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.filled = false,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final fg = filled ? p.onNavy : p.ink;
    final radius = BorderRadius.circular(dense ? 12 : 16);
    return Material(
      color: filled ? p.navy : p.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 18, vertical: dense ? 9 : 14),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: filled ? null : Border.all(color: p.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: dense ? 16 : 18, color: fg),
                SizedBox(width: dense ? 6 : 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(fontSize: dense ? 12.5 : 14, fontWeight: FontWeight.w800, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A rounded bottom sheet with a drag handle.
Future<T?> showNexusSheet<T>(BuildContext context, Widget Function(BuildContext) builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final p = AppPalette.of(ctx);
      return Material(
        color: p.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          side: BorderSide(color: p.line),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(22, 10, 22, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                builder(ctx),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void nexusToast(BuildContext context, String message) {
  final p = AppPalette.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(message, style: GoogleFonts.dmSans(color: p.paper, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
}
