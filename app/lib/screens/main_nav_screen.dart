import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'attendance_screen.dart';
import 'dashboard_screen.dart';
import 'marks_screen.dart';
import 'profile_screen.dart';
import 'timetable_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  // Only build a tab when the user actually opens it.
  // This prevents every tab's Riverpod provider from firing
  // immediately when MainNavScreen is first created.
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    _screens = [
      DashboardScreen(onNavigateTab: _onTabSelected),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
    ];
  }

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;

    HapticFeedback.selectionClick();

    // Lazily create the requested tab.
    if (_screens[index] is SizedBox) {
      switch (index) {
        case 1:
          _screens[index] = const AttendanceScreen();
          break;
        case 2:
          _screens[index] = const TimetableScreen();
          break;
        case 3:
          _screens[index] = const MarksScreen();
          break;
        case 4:
          _screens[index] = const ProfileScreen();
          break;
      }
    }

    setState(() {
      _currentIndex = index;
    });
  }

  static const _navItems = [
    _NavTabItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Home',
    ),
    _NavTabItem(
      icon: Icons.pie_chart_outline_rounded,
      activeIcon: Icons.pie_chart_rounded,
      label: 'Attendance',
    ),
    _NavTabItem(
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
      label: 'Timetable',
    ),
    _NavTabItem(
      icon: Icons.grade_outlined,
      activeIcon: Icons.grade_rounded,
      label: 'Marks',
    ),
    _NavTabItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.12),
                blurRadius: 30,
                spreadRadius: -4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.surface.withValues(alpha: 0.85),
                      AppTheme.surface.withValues(alpha: 0.65),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(_navItems.length, (index) {
                    final item = _navItems[index];
                    final isSelected = _currentIndex == index;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _onTabSelected(index),
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.symmetric(
                              horizontal: isSelected ? 12 : 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary.withValues(alpha: 0.22)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.cyanAccent.withValues(alpha: 0.3)
                                    : Colors.transparent,
                                width: 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.cyanAccent
                                            .withValues(alpha: 0.15),
                                        blurRadius: 12,
                                        spreadRadius: -2,
                                      )
                                    ]
                                  : [],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (isSelected)
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppTheme.cyanAccent
                                              .withValues(alpha: 0.6),
                                        ),
                                      ).animate().scale(
                                            duration: 250.ms,
                                            curve: Curves.easeOutBack,
                                          ),
                                    Icon(
                                      isSelected
                                          ? item.activeIcon
                                          : item.icon,
                                      size: 22,
                                      color: isSelected
                                          ? AppTheme.cyanAccent
                                          : const Color(0xFF8E9BAE),
                                    )
                                        .animate(
                                            target: isSelected ? 1 : 0)
                                        .scale(
                                          begin: const Offset(1, 1),
                                          end: const Offset(1.12, 1.12),
                                          duration: 200.ms,
                                          curve: Curves.easeOutBack,
                                        ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                                    letterSpacing: isSelected ? 0.2 : 0,
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    margin: const EdgeInsets.only(top: 3),
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.cyanAccent,
                                    ),
                                  ).animate().scale(
                                        duration: 200.ms,
                                        curve: Curves.easeOut,
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}