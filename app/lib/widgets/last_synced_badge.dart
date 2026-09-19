import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// A sleek, non-intrusive badge showing the last-synced time with a quick refresh button.
class LastSyncedBadge extends StatefulWidget {
  final DateTime? lastSynced;
  final VoidCallback? onRefresh;
  final bool isRefreshing;
  final EdgeInsetsGeometry? padding;

  const LastSyncedBadge({
    super.key,
    required this.lastSynced,
    this.onRefresh,
    this.isRefreshing = false,
    this.padding,
  });

  @override
  State<LastSyncedBadge> createState() => _LastSyncedBadgeState();
}

class _LastSyncedBadgeState extends State<LastSyncedBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isRefreshing) {
      _spinController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant LastSyncedBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRefreshing && !_spinController.isAnimating) {
      _spinController.repeat();
    } else if (!widget.isRefreshing && _spinController.isAnimating) {
      _spinController.stop();
      _spinController.reset();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formattedTime = widget.isRefreshing
        ? 'Syncing with VTOP...'
        : 'Last synced: ${StorageService.formatLastSynced(widget.lastSynced)}';

    return Padding(
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: InkWell(
        onTap: widget.isRefreshing ? null : widget.onRefresh,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
          decoration: BoxDecoration(
            color: const Color(0xFF131722).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isRefreshing
                  ? AppTheme.cyanAccent.withValues(alpha: 0.4)
                  : const Color(0xFF2A2F3D),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _spinController,
                child: Icon(
                  widget.isRefreshing ? Icons.sync : Icons.cloud_done_rounded,
                  size: 13,
                  color: widget.isRefreshing
                      ? AppTheme.cyanAccent
                      : (widget.lastSynced != null ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                formattedTime,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: widget.isRefreshing
                      ? AppTheme.cyanAccent
                      : const Color(0xFF94A3B8),
                  letterSpacing: 0.1,
                ),
              ),
              if (widget.onRefresh != null && !widget.isRefreshing) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.refresh_rounded,
                  size: 12,
                  color: Color(0xFF64748B),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
