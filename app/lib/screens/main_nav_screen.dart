import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'attendance_screen.dart';
import 'today_screen.dart';
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
        return TodayScreen(
          key: ValueKey('today_${_tabRevisions[0]}'),
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
    final pill = _floatingBar(palette);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: pill,
      ),
    );
  }

  /// A floating, rounded dock. The active tab grows into a coloured capsule with its name.
  /// Tabs sit in a Stack and slide to computed positions, so the bar can never overflow.
  Widget _floatingBar(AppPalette palette) {
    final dark = palette.isDark;
    final base = dark ? const Color(0xFF1B1B24) : const Color(0xFF15151D);
    final hsl = HSLColor.fromColor(Theme.of(context).colorScheme.primary);
    final accent = hsl.withLightness(hsl.lightness.clamp(0.0, 0.42)).withSaturation(hsl.saturation.clamp(0.5, 1.0)).toColor();
    const dur = Duration(milliseconds: 300);
    const curve = Curves.easeOutCubic;
    Widget bar = Container(
      height: 64,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: dark ? 0.08 : 0.04)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.45 : 0.22), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final n = _navItems.length;
          final selW = c.maxWidth * 0.34;
          final otherW = (c.maxWidth - selW) / (n - 1);
          final sel = _currentIndex;
          double leftOf(int i) => i <= sel ? i * otherW : i * otherW + (selW - otherW);
          return Stack(
            children: [
              // The capsule slides under the active tab.
              AnimatedPositioned(
                duration: dur,
                curve: curve,
                left: sel * otherW,
                width: selW,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(colors: [accent, Color.lerp(accent, const Color(0xFFFF6FA8), 0.55)!]),
                  ),
                ),
              ),
              for (var i = 0; i < n; i++)
                AnimatedPositioned(
                  duration: dur,
                  curve: curve,
                  left: leftOf(i),
                  width: i == sel ? selW : otherW,
                  top: 0,
                  bottom: 0,
                  child: _dockItem(i, _navItems[i]),
                ),
            ],
          );
        },
      ),
    );
    return bar;
  }

  Widget _dockItem(int index, _NavTabItem item) {
    final selected = _currentIndex == index;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTabSelected(index),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? item.activeIcon : item.icon,
              size: 22,
              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.58),
            ),
            if (selected)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    item.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: GoogleFonts.bricolageGrotesque(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
          ],
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
