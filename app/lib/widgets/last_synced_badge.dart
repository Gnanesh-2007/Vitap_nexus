import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// Small, unobtrusive sync status line.
/// The sync action itself is intentionally handled elsewhere.
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
      duration: const Duration(milliseconds: 850),
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
      _spinController
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSynced = widget.lastSynced != null;

    return Padding(
      padding: widget.padding ??
          const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _spinController,
            child: Icon(
              widget.isRefreshing
                  ? Icons.sync_rounded
                  : hasSynced
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
              size: 14,
              color: widget.isRefreshing
                  ? AppTheme.primary
                  : hasSynced
                      ? AppTheme.success
                      : AppTheme.muted,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            widget.isRefreshing
                ? 'Syncing VTOP data...'
                : 'Last synced: ${StorageService.formatLastSynced(widget.lastSynced)}',
            style: GoogleFonts.dmSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}
