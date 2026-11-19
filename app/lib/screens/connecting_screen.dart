import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../providers/vtop_providers.dart';
import '../theme/app_theme.dart';
import '../utils/error_formatter.dart';
import 'main_nav_screen.dart';
import 'otp_screen.dart';

class ConnectingScreen extends ConsumerStatefulWidget {
  final String username;
  final String password;
  final bool isOtpVerification;
  final String? otp;

  const ConnectingScreen({
    super.key,
    required this.username,
    required this.password,
    this.isOtpVerification = false,
    this.otp,
  });

  @override
  ConsumerState<ConnectingScreen> createState() => _ConnectingScreenState();
}

class _ConnectingScreenState extends ConsumerState<ConnectingScreen> {
  int _currentStep = 0; // 0: Connect, 1: Verify, 2: Academic Sync, 3: Complete
  String _statusText = 'Connecting to VTOP...';
  String? _errorMessage;

  AppPalette get _palette => AppPalette.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAuthenticationAndLoading();
    });
  }

  Future<void> _startAuthenticationAndLoading() async {
    if (!mounted) return;

    setState(() {
      _currentStep = 0;
      _errorMessage = null;
      _statusText = widget.isOtpVerification
          ? 'Verifying OTP with VTOP...'
          : 'Connecting to VTOP Gateway...';
    });

    try {
      bool success = false;

      if (widget.isOtpVerification) {
        setState(() => _currentStep = 1);
        success = await ref.read(authProvider.notifier).verifyOtp(widget.otp ?? '');
      } else {
        setState(() => _currentStep = 0);
        success = await ref.read(authProvider.notifier).login(
              username: widget.username,
              password: widget.password,
            );
      }

      if (!mounted) return;

      final authState = ref.read(authProvider);

      // 1. If OTP is required by VTOP, redirect to OtpScreen
      if (authState.otpRequired) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OtpScreen()),
        );
        return;
      }

      // 2. If login failed with an error
      if (!success || !authState.isAuthenticated) {
        setState(() {
          _errorMessage = authState.errorMessage ?? 'Unable to authenticate with VTOP.';
        });
        return;
      }

      // 3. Authenticated! Now sync academic records
      setState(() {
        _currentStep = 2;
        _statusText = 'Loading your academic records...';
      });

      try {
        await ref.read(dashboardProvider.notifier).syncAll(isUserInitiated: true);
        ref.invalidate(profileProvider);
        ref.invalidate(timetableProvider);
        ref.invalidate(attendanceProvider);
        ref.invalidate(marksProvider);
        ref.invalidate(gradesProvider);
        ref.invalidate(examScheduleProvider);
      } catch (syncErr) {
        debugPrint('ConnectingScreen: Non-fatal sync error: $syncErr');
      }

      if (!mounted) return;

      setState(() {
        _currentStep = 3;
        _statusText = 'Welcome!';
      });

      await Future.delayed(const Duration(milliseconds: 350));

      if (!mounted) return;

      // Smoothly navigate straight to Dashboard
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ErrorFormatter.format(e, fallback: 'Failed to connect to VTOP. Please try again.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _palette.paper,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: _errorMessage != null
                ? _buildErrorView()
                : _buildLoadingView(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Kokonut UI Status Capsule
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _palette.blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: _palette.blue.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _palette.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _palette.green.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ENCRYPTED VTOP SESSION',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _palette.blue,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms),

        const SizedBox(height: 32),

        // Logo with ambient breathing glow (Motion.dev inspired)
        Container(
          width: 88,
          height: 88,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _palette.surface,
            shape: BoxShape.circle,
            border: Border.all(color: _palette.line, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _palette.blue.withValues(alpha: 0.12),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/vitap_nexus_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.school_rounded,
              size: 40,
              color: _palette.navy,
            ),
          ),
        )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scale(
              begin: const Offset(0.96, 0.96),
              end: const Offset(1.04, 1.04),
              duration: 1000.ms,
              curve: Curves.easeInOut,
            ),

        const SizedBox(height: 24),

        Text(
          'VITAP NEXUS',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: _palette.ink,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          _statusText,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: _palette.inkSoft,
          ),
        ),

        const SizedBox(height: 32),

        // Motion.dev Step Progress Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: _palette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _palette.line, width: 1.2),
          ),
          child: Column(
            children: [
              _buildStepItem(0, 'Establishing TLS connection to VTOP'),
              const SizedBox(height: 12),
              _buildStepItem(1, 'Authenticating student credentials & 2FA'),
              const SizedBox(height: 12),
              _buildStepItem(2, 'Synchronizing academic timetable & attendance'),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 150.ms).slideY(begin: 0.08, end: 0),
      ],
    );
  }

  Widget _buildStepItem(int stepIndex, String title) {
    final isDone = _currentStep > stepIndex;
    final isActive = _currentStep == stepIndex;

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? _palette.green
                : isActive
                    ? _palette.blue.withValues(alpha: 0.15)
                    : _palette.soft,
            border: Border.all(
              color: isDone
                  ? _palette.green
                  : isActive
                      ? _palette.blue
                      : _palette.line,
              width: 1.4,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : isActive
                    ? SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _palette.blue,
                        ),
                      )
                    : Text(
                        '${stepIndex + 1}',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _palette.inkMuted,
                        ),
                      ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              fontWeight: isActive || isDone ? FontWeight.w700 : FontWeight.w500,
              color: isDone
                  ? _palette.ink
                  : isActive
                      ? _palette.blue
                      : _palette.inkMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: _palette.red.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: _palette.red,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Connection Failed',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _palette.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: _palette.inkMuted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _palette.ink,
                  side: BorderSide(color: _palette.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: Text(
                  'Back to Login',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _startAuthenticationAndLoading,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _palette.navy,
                  foregroundColor: _palette.isDark ? Colors.black : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: Text(
                  'Try Again',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
