import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/main_nav_screen.dart';
import '../screens/onboarding_screen.dart';
import '../services/biometric_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'motion/nexus_motion.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  static bool _sessionBiometricUnlocked = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final palette = AppPalette.of(context);

    // 1. Initial cold start check of saved credentials
    if (authState.isCheckingSavedAuth) {
      return Scaffold(
        backgroundColor: palette.paper,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  AnimeRadarWave(
                    color: palette.navy,
                    size: 96,
                    ringCount: 2,
                    duration: const Duration(milliseconds: 2200),
                  ),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: palette.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.line),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: palette.isDark ? 0.3 : 0.05,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/vitap_nexus_logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.school_rounded,
                          size: 36,
                          color: palette.navy,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'VITAP NEXUS',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.navy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Connecting to VTOP...',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.inkMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // 2. If authenticated, check Biometric / App Lock on cold start
    if (authState.isAuthenticated) {
      final lockRequired =
          StorageService.isBiometricEnabledSync() ||
          StorageService.getAppLockPinSync() != null;
      if (lockRequired && !_sessionBiometricUnlocked) {
        return _BiometricUnlockScreen(
          username: authState.username ?? '',
          onUnlocked: () {
            setState(() => _sessionBiometricUnlocked = true);
          },
        );
      }
      return const MainNavScreen();
    }

    // Reset lock state when logged out
    _sessionBiometricUnlocked = false;

    // 3. First-install Welcome / Onboarding Tour
    if (!StorageService.isOnboardingCompletedSync() && !authState.otpRequired) {
      return const OnboardingScreen();
    }

    // 4. Unauthenticated (stays active during login submission & OTP popup bottom sheet)
    return const LoginScreen();
  }
}

class _BiometricUnlockScreen extends ConsumerStatefulWidget {
  final String username;
  final VoidCallback onUnlocked;

  const _BiometricUnlockScreen({
    required this.username,
    required this.onUnlocked,
  });

  @override
  ConsumerState<_BiometricUnlockScreen> createState() =>
      _BiometricUnlockScreenState();
}

class _BiometricUnlockScreenState
    extends ConsumerState<_BiometricUnlockScreen> {
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  String? _errorText;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (StorageService.isBiometricEnabledSync()) {
        _triggerBiometric();
      }
    });
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _triggerBiometric() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _errorText = null;
    });
    final ok = await BiometricService.authenticate(
      title: 'Unlock VITAP Nexus',
      subtitle: 'Authenticate with Fingerprint, Face, or Device PIN',
    );
    if (!mounted) return;
    setState(() => _isAuthenticating = false);
    if (ok) {
      widget.onUnlocked();
    }
  }

  Future<void> _verifyPasswordOrPin() async {
    final entered = _passwordCtrl.text.trim();
    if (entered.isEmpty) {
      setState(() => _errorText = 'Enter your App PIN or VTOP password.');
      return;
    }

    final savedPin = StorageService.getAppLockPinSync();
    final savedCreds = await StorageService.getCredentials();
    final savedVtopPass = (savedCreds['password'] ?? '').trim();

    if ((savedPin != null && entered == savedPin) ||
        (savedVtopPass.isNotEmpty && entered == savedVtopPass)) {
      widget.onUnlocked();
    } else {
      setState(() {
        _errorText = 'Incorrect PIN or VTOP password. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final hasPin = StorageService.getAppLockPinSync() != null;

    return Scaffold(
      backgroundColor: palette.paper,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: palette.line),
                      boxShadow: palette.cardShadow,
                    ),
                    child: Icon(
                      Icons.fingerprint_rounded,
                      size: 42,
                      color: palette.blue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'VITAP Nexus Locked',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.username.isNotEmpty
                        ? 'Signed in as ${widget.username}. Verify your identity to continue.'
                        : 'Verify your identity with Biometrics or Password.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: palette.inkSoft,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 26),
                  if (StorageService.isBiometricEnabledSync()) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _isAuthenticating ? null : _triggerBiometric,
                        icon: const Icon(Icons.fingerprint_rounded, size: 22),
                        label: Text(
                          'Unlock with Biometrics',
                          style: GoogleFonts.dmSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.navy,
                          foregroundColor: palette.onNavy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: palette.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          hasPin
                              ? 'UNLOCK WITH APP PIN OR VTOP PASSWORD'
                              : 'UNLOCK WITH VTOP PASSWORD',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: palette.inkMuted,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          onSubmitted: (_) => _verifyPasswordOrPin(),
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: palette.ink,
                          ),
                          decoration: InputDecoration(
                            hintText: hasPin
                                ? 'Enter App PIN or VTOP password'
                                : 'Enter your VTOP password',
                            hintStyle: GoogleFonts.dmSans(
                              fontSize: 12.5,
                              color: palette.inkMuted,
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline_rounded,
                              size: 18,
                              color: palette.inkSoft,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                                color: palette.inkSoft,
                              ),
                            ),
                            filled: true,
                            fillColor: palette.soft,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: palette.line),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: palette.line),
                            ),
                          ),
                        ),
                        if (_errorText != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _errorText!,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: palette.red,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: _verifyPasswordOrPin,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: palette.blue),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Unlock with Password',
                              style: GoogleFonts.dmSans(
                                color: palette.blue,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
