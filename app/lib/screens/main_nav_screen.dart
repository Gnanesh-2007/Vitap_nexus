import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'attendance_screen.dart';
import 'timetable_screen.dart';
import 'marks_screen.dart';
import 'profile_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  static const _navItems = [
    _NavTabItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Home'),
    _NavTabItem(icon: Icons.pie_chart_outline_rounded, activeIcon: Icons.pie_chart_rounded, label: 'Attendance'),
    _NavTabItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month_rounded, label: 'Timetable'),
    _NavTabItem(icon: Icons.grade_outlined, activeIcon: Icons.grade_rounded, label: 'Marks'),
    _NavTabItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onNavigateTab: _onTabSelected),
      const AttendanceScreen(),
      const TimetableScreen(),
      const MarksScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.94),
          border: const Border(
            top: BorderSide(color: AppTheme.cardBorder, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isSelected = _currentIndex == index;

                return GestureDetector(
                  onTap: () => _onTabSelected(index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSelected ? 14 : 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(
                              color: AppTheme.primaryAccent.withValues(alpha: 0.35),
                              width: 1,
                            )
                          : Border.all(color: Colors.transparent, width: 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? item.activeIcon : item.icon,
                          size: 22,
                          color: isSelected
                              ? AppTheme.cyanAccent
                              : const Color(0xFF94A3B8),
                        )
                            .animate(target: isSelected ? 1 : 0)
                            .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 200.ms),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF64748B),
                            letterSpacing: isSelected ? 0.3 : 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
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
