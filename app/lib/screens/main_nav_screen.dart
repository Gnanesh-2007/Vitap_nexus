import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'attendance_screen.dart';
import 'dashboard_screen.dart';
import 'marks_screen.dart';
import 'exam_schedule.dart';
import 'timetable_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;
  final List<int> _tabRevisions = [0, 0, 0, 0, 0];
  late final List<Widget> _screens;

  static const _navItems = [
    _NavTabItem(Icons.home_outlined, Icons.home_rounded, 'Home', 'HOME'),
    _NavTabItem(Icons.pie_chart_outline_rounded, Icons.pie_chart_rounded, 'Attendance', 'ATTEND'),
    _NavTabItem(Icons.calendar_today_outlined, Icons.calendar_today_rounded, 'Timetable', 'SCHEDULE'),
    _NavTabItem(Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Marks', 'MARKS'),
    _NavTabItem(Icons.event_note_outlined, Icons.event_note_rounded, 'Exams', 'EXAMS'),
  ];

  @override
  void initState() {
    super.initState();
    _screens = [
      _buildScreen(0),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
    ];
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return DashboardScreen(
          key: ValueKey('dashboard_${_tabRevisions[0]}'),
          onNavigateTab: _onTabSelected,
        );
      case 1:
        return AttendanceScreen(
          key: ValueKey('attendance_${_tabRevisions[1]}'),
        );
      case 2:
        return TimetableScreen(
          key: ValueKey('timetable_${_tabRevisions[2]}'),
        );
      case 3:
        return MarksScreen(
          key: ValueKey('marks_${_tabRevisions[3]}'),
        );
      case 4:
        return ExamScheduleScreen(
          key: ValueKey('exams_${_tabRevisions[4]}'),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _onTabSelected(int index) {
    if (index < 0 || index >= _navItems.length) return;

    HapticFeedback.selectionClick();

    setState(() {
      // Increment revision so page resets to the top
      _tabRevisions[index]++;
      _screens[index] = _buildScreen(index);
      _currentIndex = index;
    });
  }

  Widget _getScreen(int index) {
    if (_screens[index] is SizedBox) {
      _screens[index] = _buildScreen(index);
    }
    return _screens[index];
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // If user is not on Dashboard (Tab 0), back press returns to Dashboard at top
        if (_currentIndex != 0) {
          _onTabSelected(0);
        }
      },
      child: Scaffold(
        backgroundColor: palette.paper,
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(_navItems.length, (i) => _getScreen(i)),
        ),
        bottomNavigationBar: _buildNavigationBar(palette),
      ),
    );
  }

  Widget _buildNavigationBar(AppPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.line, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: List.generate(
              _navItems.length,
              (index) => Expanded(
                child: _buildNavItem(index, _navItems[index], palette),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, _NavTabItem item, AppPalette palette) {
    final selected = _currentIndex == index;
    final selectedBg = palette.isDark
        ? palette.soft
        : const Color(0xFFE8EEF9);
    final activeColor = palette.isDark ? palette.navy : const Color(0xFF172B4D);
    final unselectedColor = palette.inkMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTabSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                        ),
                    child: Icon(
                      selected ? item.activeIcon : item.icon,
                      key: ValueKey('${index}_$selected'),
                      size: selected ? 22 : 21,
                      color: selected ? activeColor : unselectedColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 160),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: selected ? 8.5 : 8,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: selected ? .65 : .45,
                      color: selected ? activeColor : unselectedColor,
                    ),
                    child: Text(
                      item.shortLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 5,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: selected ? 18 : 0,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: palette.orange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
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
  final String shortLabel;

  const _NavTabItem(
    this.icon,
    this.activeIcon,
    this.label,
    this.shortLabel,
  );
}
