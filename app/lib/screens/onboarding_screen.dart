import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/theme_provider.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth/auth_kit.dart';
import 'login_screen.dart';

/// The welcome tour: three short feature pages, each with a small live
/// preview drawn in code (not a stock illustration), then an avatar picker.
class OnboardingScreen extends ConsumerStatefulWidget {
  final bool isReplay;

  const OnboardingScreen({
    super.key,
    this.isReplay = false,
  });

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const int _pageCount = 4;

  final PageController _pageController = PageController();
  int _currentPage = 0;
  late String _selectedAvatar;

  static const List<String> availableAvatars = [
    'assets/images/pfp/astronaut.png',
    'assets/images/pfp/ninja.png',
    'assets/images/pfp/masked.png',
    'assets/images/pfp/cat.png',
    'assets/images/pfp/panda.png',
    'assets/images/pfp/dog.png',
    'assets/images/pfp/bear.png',
    'assets/images/pfp/duck.png',
    'assets/images/pfp/chicken.png',
    'assets/images/pfp/man.png',
    'assets/images/pfp/man_1.png',
    'assets/images/pfp/woman.png',
    'assets/images/pfp/woman_1.png',
    'assets/images/pfp/default.png',
  ];

  @override
  void initState() {
    super.initState();
    _selectedAvatar =
        StorageService.getCustomAvatarPathSync() ?? availableAvatars.first;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    HapticFeedback.mediumImpact();
    await StorageService.setCustomAvatarPath(_selectedAvatar);
    await StorageService.setOnboardingCompleted(true);
    if (!mounted) return;
    if (widget.isReplay) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _goTo(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeOutCubic,
    );
  }

  void _nextPage() {
    HapticFeedback.selectionClick();
    if (_currentPage < _pageCount - 1) {
      _goTo(_currentPage + 1);
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final isLast = _currentPage == _pageCount - 1;

    return Scaffold(
      backgroundColor: palette.paper,
      body: AuthBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(palette, isDark, isLast),
              _buildProgress(palette),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  children: [
                    _FeaturePage(
                      eyebrow: '01  ·  Direct',
                      title: 'Straight to VTOP.\nNo detours.',
                      body:
                          'A Rust engine on your phone signs in, solves the captcha and reads VTOP for you. There is no server in the middle, and your last sync opens instantly, even offline.',
                      points: const [
                        (Icons.bolt_rounded, 'Opens instantly from your last sync'),
                        (Icons.phonelink_lock_outlined, 'Your password stays on this phone'),
                        (Icons.sync_rounded, 'One sign-in shared by every screen'),
                      ],
                      vignette: _DirectVignette(active: _currentPage == 0),
                    ),
                    _FeaturePage(
                      eyebrow: '02  ·  Academics',
                      title: 'Know where\nyou stand.',
                      body:
                          'Live classes, attendance with a skip calculator, marks as they are posted, and a planner for the CGPA you are aiming at.',
                      points: const [
                        (Icons.access_time_rounded, 'What is on now, and what is next'),
                        (Icons.calculate_outlined, 'How many classes you can miss at 75%'),
                        (Icons.workspace_premium_outlined, 'Grade history and target CGPA'),
                      ],
                      vignette: _AcademicsVignette(active: _currentPage == 1),
                    ),
                    _FeaturePage(
                      eyebrow: '03  ·  Campus',
                      title: 'The rest of\ncampus life.',
                      body:
                          'Upload digital assignments, grab course material, apply for outings and look up faculty, all without opening a browser.',
                      points: const [
                        (Icons.upload_file_rounded, 'Submit assignments from your phone'),
                        (Icons.confirmation_number_outlined, 'Outing requests and PDF passes'),
                        (Icons.people_alt_outlined, '700+ faculty, searchable offline'),
                      ],
                      vignette: _CampusVignette(active: _currentPage == 2),
                    ),
                    _buildAvatarPage(palette),
                  ],
                ),
              ),
              _buildBottomBar(palette, isLast),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AppPalette palette, bool isDark, bool isLast) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: palette.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/vitap_nexus_logo.png',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                Icons.school_rounded,
                size: 20,
                color: palette.navy,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VITAP NEXUS',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: palette.ink,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                'Welcome tour',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: palette.inkMuted,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            tooltip: isDark ? 'Switch to light' : 'Switch to dark',
            onPressed: () {
              HapticFeedback.selectionClick();
              ref
                  .read(themeModeProvider.notifier)
                  .toggleTheme(currentIsDark: isDark);
            },
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 19,
              color: palette.inkSoft,
            ),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isLast ? 0 : 1,
            child: TextButton(
              onPressed: isLast ? null : _completeOnboarding,
              style: TextButton.styleFrom(foregroundColor: palette.inkSoft),
              child: Text(
                widget.isReplay ? 'Close' : 'Skip',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Four thin segments that fill as you move through the tour.
  Widget _buildProgress(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
      child: Row(
        children: List.generate(_pageCount, (i) {
          final done = i <= _currentPage;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _goTo(i),
              child: Padding(
                padding: EdgeInsets.only(
                  right: i == _pageCount - 1 ? 0 : 6,
                  top: 8,
                  bottom: 8,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOut,
                  height: 3,
                  decoration: BoxDecoration(
                    color: done ? palette.navy : palette.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomBar(AppPalette palette, bool isLast) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
      child: Row(
        children: [
          Text(
            '0${_currentPage + 1}',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
          Text(
            '  /  0$_pageCount',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.inkMuted,
            ),
          ),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _currentPage == 0
                ? const SizedBox(key: ValueKey('none'), width: 0, height: 52)
                : Padding(
                    key: const ValueKey('back'),
                    padding: const EdgeInsets.only(right: 10),
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: () => _goTo(_currentPage - 1),
                      style: IconButton.styleFrom(
                        backgroundColor: palette.surface,
                        minimumSize: const Size(52, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: palette.line),
                        ),
                      ),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: palette.ink,
                      ),
                    ),
                  ),
          ),
          FilledButton(
            onPressed: _nextPage,
            style: FilledButton.styleFrom(
              backgroundColor: palette.navy,
              foregroundColor: palette.onNavy,
              minimumSize: const Size(148, 52),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    isLast
                        ? (widget.isReplay ? 'Save and close' : 'Get started')
                        : 'Continue',
                    key: ValueKey(isLast),
                    style: GoogleFonts.dmSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPage(AppPalette palette) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Selected avatar preview
              Container(
                width: 92,
                height: 92,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.surface,
                  border: Border.all(color: palette.navy, width: 2),
                  boxShadow: palette.cardShadow,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, a) => ScaleTransition(
                    scale: Tween(begin: 0.86, end: 1.0).animate(
                      CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                    ),
                    child: FadeTransition(opacity: a, child: child),
                  ),
                  child: ClipOval(
                    key: ValueKey(_selectedAvatar),
                    child: Image.asset(_selectedAvatar, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuthEyebrow('04  ·  You', color: palette.blue),
                    const SizedBox(height: 8),
                    Text(
                      'Pick a face.',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: palette.ink,
                        letterSpacing: -1.1,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'It shows on your dashboard and profile. You can switch to your VTOP photo, or change this any time in Profile.',
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              color: palette.inkSoft,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
            ),
            itemCount: availableAvatars.length,
            itemBuilder: (context, index) {
              final path = availableAvatars[index];
              final isSelected = _selectedAvatar == path;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedAvatar = path);
                },
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        padding: EdgeInsets.all(isSelected ? 4 : 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.surface,
                          border: Border.all(
                            color: isSelected ? palette.navy : palette.line,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isSelected ? 1 : 0.82,
                          child: ClipOval(
                            child: Image.asset(path, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        scale: isSelected ? 1 : 0,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: palette.navy,
                            shape: BoxShape.circle,
                            border: Border.all(color: palette.paper, width: 2),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: palette.onNavy,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feature page
// ---------------------------------------------------------------------------

class _FeaturePage extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String body;
  final List<(IconData, String)> points;
  final Widget vignette;

  const _FeaturePage({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.points,
    required this.vignette,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VignetteFrame(child: vignette),
          const SizedBox(height: 24),
          AuthEyebrow(eyebrow, color: palette.blue),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 31,
              fontWeight: FontWeight.w900,
              color: palette.ink,
              height: 1.06,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              color: palette.inkSoft,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < points.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: palette.line),
                ),
              ),
              child: Row(
                children: [
                  Icon(points[i].$1, size: 17, color: palette.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      points[i].$2,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The card every preview sits in.
class _VignetteFrame extends StatelessWidget {
  final Widget child;
  const _VignetteFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      height: 228,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.line),
        boxShadow: palette.cardShadow,
      ),
      child: child,
    );
  }
}

TextStyle _vLabel(AppPalette p, {Color? color, double size = 9.5}) =>
    GoogleFonts.bricolageGrotesque(
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
      color: color ?? p.inkMuted,
    );

// ---------------------------------------------------------------------------
// Preview 1: phone talks straight to VTOP
// ---------------------------------------------------------------------------

class _DirectVignette extends StatefulWidget {
  final bool active;
  const _DirectVignette({required this.active});

  @override
  State<_DirectVignette> createState() => _DirectVignetteState();
}

class _DirectVignetteState extends State<_DirectVignette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(_DirectVignette old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat();
    if (!widget.active && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    Widget node({required Widget child, required String label}) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            const SizedBox(height: 10),
            Text(label, style: _vLabel(p)),
          ],
        );

    final phone = Container(
      width: 56,
      height: 98,
      padding: const EdgeInsets.fromLTRB(7, 10, 7, 8),
      decoration: BoxDecoration(
        color: p.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.ink.withValues(alpha: 0.55), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 16,
            decoration: BoxDecoration(
              color: p.blue.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          for (final w in const [1.0, 0.7, 0.85])
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: FractionallySizedBox(
                widthFactor: w,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          const Spacer(),
          Center(
            child: Container(
              width: 18,
              height: 3,
              decoration: BoxDecoration(
                color: p.ink.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );

    final server = Container(
      width: 74,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: p.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.ink.withValues(alpha: 0.55), width: 1.4),
      ),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              height: 16,
              margin: EdgeInsets.only(bottom: i == 2 ? 0 : 6),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: p.soft,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: i == 0 ? p.green : p.inkMuted.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Spacer(),
                  Container(width: 22, height: 3, color: p.line),
                ],
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                node(child: phone, label: 'YOUR PHONE'),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: AnimatedBuilder(
                      animation: _c,
                      builder: (_, _) => CustomPaint(
                        size: const Size(double.infinity, 70),
                        painter: _LinkPainter(
                          t: _c.value,
                          line: p.line,
                          accent: p.blue,
                          muted: p.inkMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                node(
                  child: SizedBox(height: 98, child: Center(child: server)),
                  label: 'VTOP',
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MiniTag(icon: Icons.check_rounded, text: 'Direct line', color: p.green),
              const SizedBox(width: 8),
              _MiniTag(icon: Icons.close_rounded, text: 'No middle server', color: p.inkMuted),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinkPainter extends CustomPainter {
  final double t;
  final Color line;
  final Color accent;
  final Color muted;

  _LinkPainter({
    required this.t,
    required this.line,
    required this.accent,
    required this.muted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    const pad = 10.0;
    final x0 = pad, x1 = size.width - pad;

    // The detour that does not exist: a faint dashed arc with a struck-out node.
    final arc = Path()
      ..moveTo(x0, y)
      ..quadraticBezierTo(size.width / 2, y - 62, x1, y);
    final dash = Paint()
      ..color = muted.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final m in arc.computeMetrics()) {
      for (double d = 0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, math.min(d + 3, m.length)), dash);
      }
    }
    final mid = Offset(size.width / 2, y - 31);
    canvas.drawCircle(mid, 7, Paint()..color = muted.withValues(alpha: 0.16));
    final x = Paint()
      ..color = muted.withValues(alpha: 0.7)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(mid + const Offset(-2.6, -2.6), mid + const Offset(2.6, 2.6), x);
    canvas.drawLine(mid + const Offset(2.6, -2.6), mid + const Offset(-2.6, 2.6), x);

    // The real path: one straight line.
    canvas.drawLine(
      Offset(x0, y),
      Offset(x1, y),
      Paint()
        ..color = accent.withValues(alpha: 0.45)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );

    // Two packets: a request going out, a reply coming back.
    void packet(double phase, bool forward) {
      final v = (t + phase) % 1.0;
      final e = Curves.easeInOut.transform(v);
      final px = forward ? x0 + (x1 - x0) * e : x1 - (x1 - x0) * e;
      final fade = math.sin(v * math.pi);
      canvas.drawCircle(
        Offset(px, y),
        6,
        Paint()..color = accent.withValues(alpha: 0.16 * fade),
      );
      canvas.drawCircle(
        Offset(px, y),
        3,
        Paint()..color = accent.withValues(alpha: 0.35 + 0.65 * fade),
      );
    }

    packet(0, true);
    packet(0.5, false);
  }

  @override
  bool shouldRepaint(_LinkPainter old) => old.t != t || old.accent != accent;
}

class _MiniTag extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _MiniTag({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: p.soft,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: p.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: p.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Preview 2: attendance rings + the class that is on now
// ---------------------------------------------------------------------------

class _AcademicsVignette extends StatelessWidget {
  final bool active;
  const _AcademicsVignette({required this.active});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    Widget ring(String name, double pct, Color color, String hint, int delayMs) {
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              key: ValueKey('$name$active'),
              tween: Tween(begin: 0, end: active ? pct : 0),
              duration: Duration(milliseconds: 900 + delayMs),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => SizedBox(
                width: 54,
                height: 54,
                child: CustomPaint(
                  painter: _RingPainter(value: v / 100, color: color, track: p.line),
                  child: Center(
                    child: Text(
                      v.round().toString(),
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              name,
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
            Text(
              hint,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        children: [
          Row(
            children: [
              ring('OS', 68, p.red, 'need 10', 0),
              ring('DBMS', 76, p.orange, 'on edge', 140),
              ring('DSA', 83, p.green, 'skip 4', 280),
              ring('CN', 92, p.green, 'skip 5', 420),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
            decoration: BoxDecoration(
              color: p.paper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: p.orange, shape: BoxShape.circle),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .fade(begin: 1, end: 0.3, duration: 900.ms),
                    const SizedBox(width: 7),
                    Text('NOW  ·  UNTIL 10:50', style: _vLabel(p, color: p.orange)),
                    const Spacer(),
                    Text('AB1-204', style: _vLabel(p)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Operating Systems',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('bar$active'),
                    tween: Tween(begin: 0, end: active ? 0.52 : 0),
                    duration: const Duration(milliseconds: 1300),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 3,
                      backgroundColor: p.line,
                      valueColor: AlwaysStoppedAnimation(p.orange),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color track;
  _RingPainter({required this.value, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(rect, paint..color = track);
    if (value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * value.clamp(0.0, 1.0),
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}

// ---------------------------------------------------------------------------
// Preview 3: a loose stack of campus cards
// ---------------------------------------------------------------------------

class _CampusVignette extends StatelessWidget {
  final bool active;
  const _CampusVignette({required this.active});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    Widget card({
      required IconData icon,
      required String title,
      required String sub,
      Color? tone,
      bool front = false,
    }) {
      final c = tone ?? p.blue;
      return Container(
        width: 196,
        padding: const EdgeInsets.fromLTRB(11, 10, 12, 10),
        decoration: BoxDecoration(
          color: front ? p.paper : p.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: p.line),
          boxShadow: front ? p.elevatedShadow : p.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: c),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: p.ink,
                    ),
                  ),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: p.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Each card drifts a few pixels on its own slow rhythm.
    Widget float(Widget child, int ms, double amount) => active
        ? child
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(
              begin: -amount,
              end: amount,
              duration: ms.ms,
              curve: Curves.easeInOut,
            )
        : child;

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 26,
          left: 20,
          child: float(
            Transform.rotate(
              angle: -0.07,
              child: card(
                icon: Icons.upload_file_rounded,
                title: 'DA-2 submitted',
                sub: 'Assignment · just now',
              ),
            ),
            3200,
            3,
          ),
        ),
        Positioned(
          bottom: 24,
          right: 18,
          child: float(
            Transform.rotate(
              angle: 0.06,
              child: card(
                icon: Icons.person_search_outlined,
                title: 'Faculty directory',
                sub: '700+ profiles, offline',
              ),
            ),
            3800,
            3,
          ),
        ),
        float(
          card(
            icon: Icons.confirmation_number_outlined,
            title: 'Weekend outing',
            sub: 'Approved · pass ready',
            tone: p.green,
            front: true,
          ),
          2800,
          2,
        ),
      ],
    );
  }
}
