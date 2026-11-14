import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../motion/nexus_illustrations.dart';

// ============================================================================
// SHADCN DESIGN SYSTEM - FLUTTER IMPLEMENTATION
// Inspired by ui.shadcn.com
// Features:
// - 1px crisp borders, neutral slate/zinc surface contrast
// - Micro-interactions (spring tap scale, smooth chevrons, shimmer skeletons)
// - Accessible, theme-adaptive (light & dark modes)
// - High performance 60fps animations
// ============================================================================

// ============================================================================
// 1. SHADCN BUTTON
// ============================================================================

enum ShadcnButtonVariant {
  defaultStyle,
  secondary,
  outline,
  ghost,
  destructive,
  success,
}

enum ShadcnButtonSize {
  sm,
  md,
  lg,
  icon,
}

class ShadcnButton extends StatefulWidget {
  final Widget? child;
  final String? label;
  final IconData? icon;
  final IconData? trailingIcon;
  final VoidCallback? onPressed;
  final ShadcnButtonVariant variant;
  final ShadcnButtonSize size;
  final bool isLoading;
  final bool isFullWidth;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final String? semanticsLabel;
  final String? tooltip;

  const ShadcnButton({
    super.key,
    this.child,
    this.label,
    this.icon,
    this.trailingIcon,
    required this.onPressed,
    this.variant = ShadcnButtonVariant.defaultStyle,
    this.size = ShadcnButtonSize.md,
    this.isLoading = false,
    this.isFullWidth = false,
    this.width,
    this.height,
    this.borderRadius,
    this.semanticsLabel,
    this.tooltip,
  });

  @override
  State<ShadcnButton> createState() => _ShadcnButtonState();
}

class _ShadcnButtonState extends State<ShadcnButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final disabled = widget.onPressed == null || widget.isLoading;

    // Styling based on variant
    Color bg;
    Color fg;
    Border? border;

    switch (widget.variant) {
      case ShadcnButtonVariant.defaultStyle:
        bg = palette.isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
        fg = palette.isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
        border = null;
        break;
      case ShadcnButtonVariant.secondary:
        bg = palette.soft;
        fg = palette.ink;
        border = Border.all(color: palette.line, width: 1);
        break;
      case ShadcnButtonVariant.outline:
        bg = Colors.transparent;
        fg = palette.ink;
        border = Border.all(color: palette.line, width: 1);
        break;
      case ShadcnButtonVariant.ghost:
        bg = _isPressed ? palette.soft : Colors.transparent;
        fg = palette.ink;
        border = null;
        break;
      case ShadcnButtonVariant.destructive:
        bg = palette.red.withValues(alpha: palette.isDark ? 0.2 : 0.1);
        fg = palette.red;
        border = Border.all(color: palette.red.withValues(alpha: 0.3), width: 1);
        break;
      case ShadcnButtonVariant.success:
        bg = palette.green.withValues(alpha: palette.isDark ? 0.2 : 0.1);
        fg = palette.green;
        border = Border.all(color: palette.green.withValues(alpha: 0.3), width: 1);
        break;
    }

    // Sizes
    EdgeInsets padding;
    double fontSize;
    double iconSize;
    double defaultHeight;

    switch (widget.size) {
      case ShadcnButtonSize.sm:
        padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
        fontSize = 12;
        iconSize = 14;
        defaultHeight = 32;
        break;
      case ShadcnButtonSize.md:
        padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
        fontSize = 13.5;
        iconSize = 16;
        defaultHeight = 40;
        break;
      case ShadcnButtonSize.lg:
        padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 13);
        fontSize = 15;
        iconSize = 18;
        defaultHeight = 48;
        break;
      case ShadcnButtonSize.icon:
        padding = EdgeInsets.zero;
        fontSize = 14;
        iconSize = 18;
        defaultHeight = 38;
        break;
    }

    final radius = widget.borderRadius ?? BorderRadius.circular(9);
    final effectiveLabel = widget.semanticsLabel ?? widget.label;

    Widget buttonWidget = AnimatedScale(
      scale: _isPressed && !disabled ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: Opacity(
        opacity: disabled ? 0.55 : 1.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTapDown: disabled ? null : (_) {
              setState(() => _isPressed = true);
              HapticFeedback.selectionClick();
            },
            onTapUp: disabled ? null : (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: disabled ? null : widget.onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: widget.isFullWidth ? double.infinity : widget.width,
              height: widget.height ?? defaultHeight,
              padding: widget.size == ShadcnButtonSize.icon ? null : padding,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: radius,
                border: border,
                boxShadow: (widget.variant == ShadcnButtonVariant.defaultStyle && !palette.isDark)
                    ? [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: widget.isLoading
                    ? SizedBox(
                        width: iconSize,
                        height: iconSize,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(fg),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, size: iconSize, color: fg),
                            if (widget.label != null || widget.child != null)
                              const SizedBox(width: 8),
                          ],
                          if (widget.child != null)
                            widget.child!
                          else if (widget.label != null)
                            Text(
                              widget.label!,
                              style: GoogleFonts.dmSans(
                                fontSize: fontSize,
                                fontWeight: FontWeight.w600,
                                color: fg,
                                letterSpacing: -0.2,
                              ),
                            ),
                          if (widget.trailingIcon != null) ...[
                            const SizedBox(width: 8),
                            Icon(widget.trailingIcon, size: iconSize, color: fg),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      buttonWidget = Tooltip(
        message: widget.tooltip!,
        child: buttonWidget,
      );
    }

    return Semantics(
      button: true,
      enabled: !disabled,
      label: effectiveLabel,
      child: buttonWidget,
    );
  }
}

// ============================================================================
// 2. SHADCN BADGE
// ============================================================================

enum ShadcnBadgeVariant {
  defaultStyle,
  secondary,
  outline,
  destructive,
  success,
  warning,
  info,
}

class ShadcnBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final ShadcnBadgeVariant variant;
  final VoidCallback? onTap;

  const ShadcnBadge({
    super.key,
    required this.label,
    this.icon,
    this.variant = ShadcnBadgeVariant.defaultStyle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    Color bg;
    Color fg;
    Border? border;

    switch (variant) {
      case ShadcnBadgeVariant.defaultStyle:
        bg = palette.isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
        fg = palette.isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
        break;
      case ShadcnBadgeVariant.secondary:
        bg = palette.soft;
        fg = palette.ink;
        border = Border.all(color: palette.line, width: 0.8);
        break;
      case ShadcnBadgeVariant.outline:
        bg = Colors.transparent;
        fg = palette.ink;
        border = Border.all(color: palette.line, width: 1);
        break;
      case ShadcnBadgeVariant.destructive:
        bg = palette.red.withValues(alpha: 0.12);
        fg = palette.red;
        border = Border.all(color: palette.red.withValues(alpha: 0.25), width: 0.8);
        break;
      case ShadcnBadgeVariant.success:
        bg = palette.green.withValues(alpha: 0.12);
        fg = palette.green;
        border = Border.all(color: palette.green.withValues(alpha: 0.25), width: 0.8);
        break;
      case ShadcnBadgeVariant.warning:
        bg = palette.orange.withValues(alpha: 0.12);
        fg = palette.orange;
        border = Border.all(color: palette.orange.withValues(alpha: 0.25), width: 0.8);
        break;
      case ShadcnBadgeVariant.info:
        bg = palette.blue.withValues(alpha: 0.12);
        fg = palette.blue;
        border = Border.all(color: palette.blue.withValues(alpha: 0.25), width: 0.8);
        break;
    }

    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        child: content,
      );
    }
    return content;
  }
}

// ============================================================================
// 3. SHADCN CARD
// ============================================================================

class ShadcnCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final bool hasHoverEffect;

  const ShadcnCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 14,
    this.hasHoverEffect = true,
  });

  @override
  State<ShadcnCard> createState() => _ShadcnCardState();
}

class _ShadcnCardState extends State<ShadcnCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isInteractive = widget.onTap != null && widget.hasHoverEffect;

    final card = Container(
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
            color: palette.ink.withValues(alpha: palette.isDark ? 0.08 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: widget.child,
    );

    if (!isInteractive) return card;

    return AnimatedScale(
      scale: _isPressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _isPressed = true);
          HapticFeedback.selectionClick();
        },
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: card,
      ),
    );
  }
}

class ShadcnCardHeader extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? leading;
  final Widget? trailing;

  const ShadcnCardHeader({
    super.key,
    required this.title,
    this.description,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                  letterSpacing: -0.3,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 2),
                Text(
                  description!,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: palette.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

// ============================================================================
// 4. SHADCN ACCORDION / COLLAPSIBLE
// ============================================================================

class ShadcnAccordionItem {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget content;
  final Widget? trailing;

  const ShadcnAccordionItem({
    required this.title,
    this.subtitle,
    this.icon,
    required this.content,
    this.trailing,
  });
}

class ShadcnAccordion extends StatefulWidget {
  final List<ShadcnAccordionItem> items;
  final bool allowMultiple;
  final int? initiallyExpandedIndex;

  const ShadcnAccordion({
    super.key,
    required this.items,
    this.allowMultiple = false,
    this.initiallyExpandedIndex,
  });

  @override
  State<ShadcnAccordion> createState() => _ShadcnAccordionState();
}

class _ShadcnAccordionState extends State<ShadcnAccordion> {
  final Set<int> _expandedIndices = {};

  @override
  void initState() {
    super.initState();
    if (widget.initiallyExpandedIndex != null) {
      _expandedIndices.add(widget.initiallyExpandedIndex!);
    }
  }

  void _toggle(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_expandedIndices.contains(index)) {
        _expandedIndices.remove(index);
      } else {
        if (!widget.allowMultiple) {
          _expandedIndices.clear();
        }
        _expandedIndices.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line, width: 1),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.items.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: palette.line),
        itemBuilder: (context, index) {
          final item = widget.items[index];
          final isExpanded = _expandedIndices.contains(index);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => _toggle(index),
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(14) : Radius.zero,
                  bottom: index == widget.items.length - 1 && !isExpanded
                      ? const Radius.circular(14)
                      : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      if (item.icon != null) ...[
                        Icon(item.icon, size: 18, color: palette.blue),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: GoogleFonts.dmSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: palette.ink,
                              ),
                            ),
                            if (item.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle!,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11.5,
                                  color: palette.inkMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (item.trailing != null) ...[
                        item.trailing!,
                        const SizedBox(width: 8),
                      ],
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: palette.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: item.content,
                ),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 240),
                sizeCurve: Curves.easeOutCubic,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// 5. SHADCN TABS
// ============================================================================

class ShadcnTab {
  final String label;
  final IconData? icon;
  final String? badge;

  const ShadcnTab({
    required this.label,
    this.icon,
    this.badge,
  });
}

class ShadcnTabs extends StatelessWidget {
  final List<ShadcnTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  /// Optional live page position (e.g. `PageController.page`): the thumb then
  /// follows a swipe in real time.
  final double? progress;

  const ShadcnTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final n = tabs.length;
    if (n == 0) return const SizedBox.shrink();

    final live = progress?.clamp(0.0, (n - 1).toDouble());
    final selected = live != null ? live.round() : selectedIndex.clamp(0, n - 1);
    final pos = live ?? selected.toDouble();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.line, width: 0.8),
      ),
      child: Stack(
        children: [
          // Sliding thumb
          Positioned.fill(
            child: AnimatedAlign(
              duration: live != null ? Duration.zero : const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment(n == 1 ? 0 : -1 + 2 * pos / (n - 1), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: palette.line, width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: palette.ink.withValues(alpha: palette.isDark ? 0.14 : 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: List.generate(n, (index) {
              final tab = tabs[index];
              final isSelected = selected == index;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (!isSelected) {
                      HapticFeedback.selectionClick();
                      onTabSelected(index);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (tab.icon != null) ...[
                          Icon(
                            tab.icon,
                            size: 14,
                            color: isSelected ? palette.ink : palette.inkMuted,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            tab.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? palette.ink : palette.inkMuted,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        if (tab.badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? palette.blue.withValues(alpha: 0.14)
                                  : palette.line,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              tab.badge!,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? palette.blue : palette.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 6. SHADCN PROGRESS BAR
// ============================================================================

class ShadcnProgress extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final double height;
  final Color? color;
  final Color? backgroundColor;

  const ShadcnProgress({
    super.key,
    required this.value,
    this.height = 7,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final clamped = value.clamp(0.0, 1.0);

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor ?? palette.soft,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final progressWidth = constraints.maxWidth * clamped;
          return Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: progressWidth,
              height: height,
              decoration: BoxDecoration(
                color: color ?? palette.blue,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// 7. SHADCN SKELETON
// ============================================================================

class ShadcnSkeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const ShadcnSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1200.ms,
          color: palette.line.withValues(alpha: 0.5),
        );
  }
}

// ============================================================================
// 8. SHADCN BOTTOM SHEET & DIALOG
// ============================================================================

class ShadcnSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    String? description,
  }) {
    final palette = AppPalette.of(context);

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.line, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Grabber handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: palette.line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (title != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: GoogleFonts.dmSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: palette.ink,
                          letterSpacing: -0.4,
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: palette.inkMuted,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    child,
                  ],
                ),
              ),
            ),
          )
              .animate()
              .slideY(begin: 0.1, end: 0, duration: 250.ms, curve: Curves.easeOutCubic)
              .fadeIn(duration: 200.ms),
        );
      },
    );
  }
}

// ============================================================================
// 12. NEXUS CARD & STAT CARD (Productivity + Academic Hierarchy)
// ============================================================================

enum NexusCardVariant {
  standard,
  subtle,
  elevated,
  bordered,
}

class NexusCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final NexusCardVariant variant;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final String? semanticsLabel;

  const NexusCard({
    super.key,
    required this.child,
    this.onTap,
    this.variant = NexusCardVariant.standard,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius,
    this.borderColor,
    this.backgroundColor,
    this.semanticsLabel,
  });

  @override
  State<NexusCard> createState() => _NexusCardState();
}

class _NexusCardState extends State<NexusCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final radius = widget.borderRadius ?? BorderRadius.circular(16);

    Color bg;
    Border? border;
    List<BoxShadow>? shadows;

    switch (widget.variant) {
      case NexusCardVariant.standard:
        bg = widget.backgroundColor ?? palette.surface;
        border = Border.all(color: widget.borderColor ?? palette.line, width: 1);
        shadows = palette.cardShadow;
        break;
      case NexusCardVariant.subtle:
        bg = widget.backgroundColor ?? palette.surfaceSubtle;
        border = Border.all(color: widget.borderColor ?? palette.line.withValues(alpha: 0.6), width: 1);
        shadows = null;
        break;
      case NexusCardVariant.elevated:
        bg = widget.backgroundColor ?? palette.surfaceElevated;
        border = Border.all(color: widget.borderColor ?? palette.line, width: 1);
        shadows = palette.elevatedShadow;
        break;
      case NexusCardVariant.bordered:
        bg = Colors.transparent;
        border = Border.all(color: widget.borderColor ?? palette.line, width: 1);
        shadows = null;
        break;
    }

    final isInteractive = widget.onTap != null;

    Widget cardWidget = AnimatedScale(
      scale: _isPressed && isInteractive ? 0.985 : 1.0,
      duration: AppPalette.fastDuration,
      curve: AppPalette.springCurve,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: border,
          boxShadow: shadows,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTapDown: isInteractive ? (_) => setState(() => _isPressed = true) : null,
            onTapUp: isInteractive ? (_) => setState(() => _isPressed = false) : null,
            onTapCancel: isInteractive ? () => setState(() => _isPressed = false) : null,
            onTap: widget.onTap,
            child: Padding(
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
      ),
    );

    if (isInteractive || widget.semanticsLabel != null) {
      cardWidget = Semantics(
        button: isInteractive,
        enabled: isInteractive,
        label: widget.semanticsLabel,
        child: cardWidget,
      );
    }

    return cardWidget;
  }
}

class NexusStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;
  final IconData? icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  const NexusStatCard({
    super.key,
    required this.label,
    required this.value,
    this.subValue,
    this.icon,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final accent = accentColor ?? palette.blue;

    return NexusCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: palette.inkMuted,
                  letterSpacing: 0.8,
                ),
              ),
              if (icon != null)
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 14, color: accent),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: palette.ink,
              letterSpacing: -0.5,
            ),
          ),
          if (subValue != null) ...[
            const SizedBox(height: 2),
            Text(
              subValue!,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: palette.inkSoft,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// 13. NEXUS SEARCH BAR & FILTER CHIP (Bits UI / shadcn Inspired)
// ============================================================================

class NexusSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final Widget? trailing;

  const NexusSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onClear,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.line, width: 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search_rounded, size: 18, color: palette.inkMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                color: palette.ink,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.dmSans(
                  fontSize: 13.5,
                  color: palette.inkMuted,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            Semantics(
              button: true,
              label: 'Clear search query',
              child: Tooltip(
                message: 'Clear search',
                child: GestureDetector(
                  onTap: () {
                    controller.clear();
                    if (onClear != null) onClear!();
                    if (onChanged != null) onChanged!('');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Icon(Icons.close_rounded, size: 16, color: palette.inkMuted),
                  ),
                ),
              ),
            ),
          ?trailing,
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class NexusFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const NexusFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      hint: isSelected ? 'Filter active. Double tap to deselect' : 'Double tap to filter by $label',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: AppPalette.fastDuration,
          curve: AppPalette.springCurve,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? palette.navy : palette.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? palette.navy : palette.line,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: isSelected ? (palette.isDark ? const Color(0xFF0F172A) : Colors.white) : palette.inkSoft,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? (palette.isDark ? const Color(0xFF0F172A) : Colors.white)
                      : palette.inkSoft,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 14. NEXUS STATES (Empty, Error, Loading, Offline Banner)
// ============================================================================

class NexusEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  /// Kept for API compatibility; illustrations are drawn in code now.
  final String? lottieAsset;
  final double lottieHeight;

  const NexusEmptyState({
    super.key,
    this.icon = Icons.inbox_rounded,
    required this.title,
    this.description,
    this.action,
    this.lottieAsset,
    this.lottieHeight = 130,
  });

  NexusIllo _resolve() {
    final lower = '${title.toLowerCase()} ${(description ?? '').toLowerCase()}';
    if (lower.contains('class') ||
        lower.contains('relax') ||
        lower.contains('completed') ||
        lower.contains('holiday') ||
        lower.contains('weekend') ||
        lower.contains('free')) {
      return NexusIllo.rest;
    }
    if (lower.contains('search') ||
        lower.contains('match') ||
        lower.contains('not found') ||
        icon == Icons.search_off_rounded) {
      return NexusIllo.search;
    }
    return NexusIllo.empty;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NexusIllustration(
              kind: _resolve(),
              size: lottieHeight < 110 ? 120 : lottieHeight + 10,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: palette.ink,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  color: palette.inkMuted,
                  height: 1.4,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class NexusErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  const NexusErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Retry Connection',
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NexusIllustration(kind: NexusIllo.error, size: 130),
            const SizedBox(height: 10),
            Text(
              'Connection Issue',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                color: palette.inkMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            ShadcnButton(
              size: ShadcnButtonSize.sm,
              variant: ShadcnButtonVariant.outline,
              icon: Icons.refresh_rounded,
              label: retryLabel,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class NexusLoadingState extends StatelessWidget {
  final String title;
  final String? subtitle;

  const NexusLoadingState({
    super.key,
    this.title = 'Syncing with VTOP...',
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NexusIllustration(kind: NexusIllo.loading, size: 150),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: palette.ink,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: palette.inkMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NexusBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color? color;
  final VoidCallback? onDismiss;

  const NexusBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.color,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final accent = color ?? palette.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.ink,
              ),
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close_rounded, size: 14, color: palette.inkMuted),
            ),
        ],
      ),
    );
  }
}
