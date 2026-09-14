import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Provides a subtle, ambient mesh background with luminous dark gradients.
/// Gives screens a high-end, premium look instead of a flat black background.
class MeshAmbientBackground extends StatelessWidget {
  final Widget child;

  const MeshAmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Solid deep space base
        Container(color: AppTheme.background),

        // Top-left cyber indigo ambient aura
        Positioned(
          top: -100,
          left: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.18),
                  AppTheme.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),

        // Top-right electric cyan ambient aura
        Positioned(
          top: 60,
          right: -90,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.cyanAccent.withValues(alpha: 0.14),
                  AppTheme.cyanAccent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),

        // Content
        child,
      ],
    );
  }
}
