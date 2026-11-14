import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/theme_provider.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

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

  void _nextPage() {
    HapticFeedback.selectionClick();
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: palette.paper,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Brand + Theme Switch + Skip
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: palette.line),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/konoha_logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: palette.navy,
                        child: Icon(
                          Icons.school_rounded,
                          size: 20,
                          color: palette.onNavy,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VITAP NEXUS',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: palette.ink,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        'NATIVE RUST ENGINE v2.0',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: palette.orange,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: isDark ? 'Switch to Warm Paper' : 'Switch to Matte Slate',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(themeModeProvider.notifier)
                          .toggleTheme(currentIsDark: isDark);
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: palette.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                        side: BorderSide(color: palette.line),
                      ),
                    ),
                    icon: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      size: 18,
                      color: isDark ? palette.orange : palette.navy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_currentPage < 3)
                    TextButton(
                      onPressed: _completeOnboarding,
                      style: TextButton.styleFrom(
                        foregroundColor: palette.inkSoft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        widget.isReplay ? 'Close' : 'Skip',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: palette.inkSoft,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Main PageView
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _buildFeatureSlide(
                    palette: palette,
                    badge: 'ZERO COLD-START ARCHITECTURE',
                    title: 'Direct On-Device\nVTOP Speed.',
                    description:
                        'Powered by a native compiled Rust engine on your phone. Connect directly to VTOP with zero proxy lag, automatic CAPTCHA solving, and instant offline caching.',
                    imagePath: 'assets/images/onboarding/adventure.png',
                    highlights: const [
                      (Icons.bolt_rounded, '0ms Instant Launch from Local Cache'),
                      (Icons.shield_outlined, '100% On-Device Encrypted Credentials'),
                      (Icons.sync_rounded, 'Smart Single-Flight Session & OTP Sync'),
                    ],
                  ),
                  _buildFeatureSlide(
                    palette: palette,
                    badge: 'COMPLETE ACADEMIC COMMAND',
                    title: 'Attendance, Grades\n& Live Timetable.',
                    description:
                        'Track live ongoing classes, calculate safe bunks to hit 75%, inspect WTG marks breakdowns, and simulate your target CGPA with executive precision.',
                    imagePath: 'assets/images/onboarding/education.png',
                    highlights: const [
                      (Icons.access_time_filled_rounded, 'Live Class Progress & Venue Radar'),
                      (Icons.calculate_outlined, '75% Attendance & Bunk Predictor'),
                      (Icons.workspace_premium_outlined, 'Executive Grade History & CGPA Simulator'),
                    ],
                  ),
                  _buildFeatureSlide(
                    palette: palette,
                    badge: 'ASSIGNMENTS & CAMPUS HUB',
                    title: 'Submit DAs, Outings\n& Course Materials.',
                    description:
                        'Upload Digital Assignments directly from your phone, download question papers & lecture slides, generate real Outing PDF passes, and search 700+ faculty offline.',
                    imagePath: 'assets/images/onboarding/notifications.png',
                    highlights: const [
                      (Icons.upload_file_rounded, 'Direct Digital Assignment Upload & OTP Support'),
                      (Icons.qr_code_2_rounded, 'Official General & Weekend Outing PDF Passes'),
                      (Icons.people_alt_outlined, '700+ VIT-AP Faculty Directory Ready Offline'),
                    ],
                  ),
                  _buildAvatarSelectionSlide(palette),
                ],
              ),
            ),

            // Bottom Navigation Bar: Page Dots + Primary Action Button
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
              child: Row(
                children: [
                  // Page Indicators
                  Row(
                    children: List.generate(4, (index) {
                      final active = _currentPage == index;
                      return GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 6),
                          width: active ? 26 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active ? palette.navy : palette.line,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  if (_currentPage > 0) ...[
                    IconButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: palette.surface,
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: palette.line),
                        ),
                      ),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  FilledButton.icon(
                    onPressed: _nextPage,
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.navy,
                      foregroundColor: palette.onNavy,
                      minimumSize: const Size(156, 50),
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: Icon(
                      _currentPage == 3
                          ? Icons.rocket_launch_rounded
                          : Icons.arrow_forward_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _currentPage == 3
                          ? (widget.isReplay ? 'Save & Done' : 'Get Started')
                          : 'Continue',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureSlide({
    required AppPalette palette,
    required String badge,
    required String title,
    required String description,
    required String imagePath,
    required List<(IconData, String)> highlights,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Artwork Container
          Container(
            width: double.infinity,
            height: 220,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: palette.line),
              boxShadow: palette.cardShadow,
            ),
            child: Center(
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(
                  Icons.auto_awesome_rounded,
                  size: 72,
                  color: palette.blue,
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 380.ms)
              .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1)),
          const SizedBox(height: 22),

          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
            decoration: BoxDecoration(
              color: palette.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.orange.withValues(alpha: 0.3)),
            ),
            child: Text(
              badge,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: palette.orange,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 31,
              fontWeight: FontWeight.w900,
              color: palette.ink,
              height: 1.08,
              letterSpacing: -1.1,
            ),
          ),
          const SizedBox(height: 10),

          // Description
          Text(
            description,
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              color: palette.inkSoft,
              height: 1.48,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          // Feature Highlights
          ...highlights.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: palette.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: palette.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(item.$1, size: 17, color: palette.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.$2,
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSelectionSlide(AppPalette palette) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
            decoration: BoxDecoration(
              color: palette.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.blue.withValues(alpha: 0.3)),
            ),
            child: Text(
              'PERSONALIZE YOUR PROFILE',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: palette.blue,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose Your Avatar',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: palette.ink,
              letterSpacing: -0.9,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick an illustrated avatar for your dashboard and profile card. You can switch to your official VTOP photo or change this anytime in Profile.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              color: palette.inkSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // Selected Avatar Preview
          Container(
            width: 96,
            height: 96,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.surface,
              border: Border.all(color: palette.navy, width: 2.5),
              boxShadow: palette.cardShadow,
            ),
            child: ClipOval(
              child: Image.asset(
                _selectedAvatar,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Grid of 14 Avatars
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? palette.navy.withValues(alpha: 0.15)
                        : palette.surface,
                    border: Border.all(
                      color: isSelected ? palette.navy : palette.line,
                      width: isSelected ? 2.5 : 1.0,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      path,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
