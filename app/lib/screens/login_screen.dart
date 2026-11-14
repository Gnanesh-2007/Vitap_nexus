import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/biometric_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_formatter.dart';
import '../widgets/otp_listener.dart';
import 'main_nav_screen.dart';
import 'onboarding_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _hasSavedBiometricCreds = false;

  // ============================================================
  // VITAP NEXUS — EDITORIAL IDENTITY (Zero-Neon Dark/Light)
  // ============================================================

  AppPalette get _palette => AppPalette.of(context);
  Color get _background => _palette.paper;
  Color get _surface => _palette.surface;
  Color get _ink => _palette.ink;
  Color get _inkSoft => _palette.inkSoft;
  Color get _muted => _palette.inkMuted;
  Color get _line => _palette.line;

  Color get _navy => _palette.navy;
  Color get _blue => _palette.blue;
  Color get _orange => _palette.orange;
  Color get _cream => _palette.soft;

  @override
  void initState() {
    super.initState();
    final savedCreds = StorageService.getCredentialsSync();
    final savedUser = (savedCreds['username'] ?? '').trim();
    final savedPass = (savedCreds['password'] ?? '').trim();
    if (savedUser.isNotEmpty) {
      _usernameController.text = savedUser.toUpperCase();
    }
    if (savedUser.isNotEmpty && savedPass.isNotEmpty) {
      _hasSavedBiometricCreds = true;
    }
    _checkAsyncSavedCreds();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authState = ref.read(authProvider);
      if (authState.otpRequired) {
        _openLoginOtpSheet(authState.pendingSessionId ?? '');
      }
    });
  }

  Future<void> _checkAsyncSavedCreds() async {
    final creds = await StorageService.getCredentials();
    final u = (creds['username'] ?? '').trim();
    final p = (creds['password'] ?? '').trim();
    if (!mounted) return;
    if (u.isNotEmpty && _usernameController.text.isEmpty) {
      _usernameController.text = u.toUpperCase();
    }
    if (u.isNotEmpty && p.isNotEmpty && !_hasSavedBiometricCreds) {
      setState(() => _hasSavedBiometricCreds = true);
    }
  }

  Future<void> _handleBiometricQuickLogin() async {
    final creds = await StorageService.getCredentials();
    final u = (creds['username'] ?? '').trim();
    final p = (creds['password'] ?? '').trim();
    if (u.isEmpty || p.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Sign in with your VTOP password once to enable Biometric Login.',
          ),
          backgroundColor: _navy,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final ok = await BiometricService.authenticate(
      title: 'Biometric VTOP Sign-In',
      subtitle: 'Authenticate to sign in as ${u.toUpperCase()}',
    );
    if (!mounted || !ok) return;

    await StorageService.setBiometricEnabled(true);
    setState(() {
      _usernameController.text = u.toUpperCase();
      _passwordController.text = p;
    });
    await _handleLogin();
  }

  Future<void> _openLoginOtpSheet(String sessionId) async {
    final verified = await showOtpVerificationSheet(
      context,
      sessionId: sessionId,
      isInitialLogin: true,
    );
    if (!mounted) return;
    if (verified && ref.read(authProvider).isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MainNavScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    final success = await ref.read(authProvider.notifier).login(
          username: username,
          password: password,
        );

    if (!mounted) return;

    final authState = ref.read(authProvider);

    // Show the OTP Verification Bottom Sheet Popup directly on top of LoginScreen
    if (authState.otpRequired) {
      await _openLoginOtpSheet(authState.pendingSessionId ?? '');
      return;
    }

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MainNavScreen(),
        ),
      );
    } else {
      final rawError = authState.errorMessage;
      final error = ErrorFormatter.cleanRawMessage(
        rawError ?? '',
        fallback: 'Login failed. Please check your credentials and try again.',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  error,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 760;

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: isWide
            ? _buildWideLayout(authState)
            : _buildMobileLayout(authState),
      ),
    );
  }

  // ============================================================
  // DESKTOP / TABLET
  // ============================================================

  Widget _buildWideLayout(AuthState authState) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: _buildBrandPanel(),
        ),
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 60,
              vertical: 42,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 450,
                ),
                child: _buildLoginContent(authState),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandPanel() {
    return Container(
      margin: const EdgeInsets.all(14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF172B4D),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -110,
            top: -100,
            child: _decorativeCircle(
              310,
              _orange.withValues(alpha: .13),
            ),
          ),
          Positioned(
            left: -120,
            bottom: -130,
            child: _decorativeCircle(
              360,
              _blue.withValues(alpha: .10),
            ),
          ),
          Positioned(
            right: 70,
            bottom: 75,
            child: _decorativeCircle(
              120,
              Colors.white.withValues(alpha: .035),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBrandMark(dark: true),
                const Spacer(),
                Text(
                  'YOUR CAMPUS,\nIN ONE PLACE.',
                  style: GoogleFonts.dmSans(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: .98,
                    letterSpacing: -2.2,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: .08, end: 0),
                const SizedBox(height: 18),
                SizedBox(
                  width: 390,
                  child: Text(
                    'A smarter way to stay connected with your VIT-AP academic life.',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      height: 1.55,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                _featureRow(
                  Icons.calendar_today_outlined,
                  'Timetable & live classes',
                ),
                _featureRow(
                  Icons.bar_chart_rounded,
                  'Grades, attendance & academics',
                ),
                _featureRow(
                  Icons.dashboard_outlined,
                  'Campus services in one app',
                ),
                const Spacer(),
                Text(
                  'VIT-AP UNIVERSITY',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white38,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _decorativeCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              color: Colors.white70,
              size: 16,
            ),
          ),
          const SizedBox(width: 11),
          Text(
            text,
            style: GoogleFonts.dmSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MOBILE
  // ============================================================

  Widget _buildMobileLayout(AuthState authState) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBrandMark(),
              _buildTopActionRow(),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            'Welcome back.',
            style: GoogleFonts.dmSans(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: _ink,
              letterSpacing: -1.5,
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: .06, end: 0),
          const SizedBox(height: 7),
          Text(
            'Sign in to continue to your VIT-AP dashboard.',
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              color: _inkSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 30),
          _buildLoginForm(authState),
          const SizedBox(height: 22),
          _buildSecurityNote(),
        ],
      ),
    );
  }

  Widget _buildTopActionRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Welcome Tour',
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const OnboardingScreen(isReplay: true),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 15,
                    color: _blue,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Tour',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: _palette.isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          child: InkWell(
            onTap: () => ref
                .read(themeModeProvider.notifier)
                .toggleTheme(currentIsDark: _palette.isDark),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line),
              ),
              child: Icon(
                _palette.isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                size: 17,
                color: _palette.isDark ? _orange : _navy,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BRAND MARK
  // ============================================================

  Widget _buildBrandMark({bool dark = false}) {
    final borderColor = dark ? Colors.white24 : _line;
    final fallbackColor = dark ? const Color(0xFF172B4D) : _palette.onNavy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: dark ? Colors.white : _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: dark ? null : _palette.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.asset(
              'assets/images/vitap_nexus_logo.png',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                Icons.school_rounded,
                color: fallbackColor,
                size: 25,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VITAP',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: dark ? Colors.white70 : _muted,
                letterSpacing: 1.7,
              ),
            ),
            Text(
              'NEXUS',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: dark ? Colors.white : _ink,
                letterSpacing: .8,
              ),
            ),
          ],
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 350.ms)
        .slideX(begin: -.04, end: 0);
  }

  // ============================================================
  // LOGIN CONTENT
  // ============================================================

  Widget _buildLoginContent(AuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildBrandMark(),
            _buildTopActionRow(),
          ],
        ),
        const SizedBox(height: 56),
        Text(
          'Welcome back.',
          style: GoogleFonts.dmSans(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            color: _ink,
            letterSpacing: -1.8,
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: .06, end: 0),
        const SizedBox(height: 7),
        Text(
          'Sign in to continue to your VIT-AP dashboard.',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: _inkSoft,
          ),
        ),
        const SizedBox(height: 30),
        _buildLoginForm(authState),
        const SizedBox(height: 22),
        _buildSecurityNote(),
      ],
    );
  }

  Widget _buildLoginForm(AuthState authState) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('VTOP USERNAME / REGISTRATION NUMBER'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _usernameController,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              TextInputFormatter.withFunction(
                (oldValue, newValue) => newValue.copyWith(
                  text: newValue.text.toUpperCase(),
                ),
              ),
            ],
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
            decoration: _inputDecoration(
              hint: 'e.g. username',
              icon: Icons.person_outline_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your username';
              }
              return null;
            },
          )
              .animate()
              .fadeIn(duration: 350.ms, delay: 100.ms)
              .slideY(begin: .05, end: 0),

          const SizedBox(height: 22),

          _fieldLabel('VTOP PASSWORD'),
          const SizedBox(height: 8),
          _buildPasswordField()
              .animate()
              .fadeIn(duration: 350.ms, delay: 150.ms)
              .slideY(begin: .05, end: 0),

          const SizedBox(height: 26),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      disabledBackgroundColor: _navy.withValues(alpha: .45),
                      foregroundColor: _palette.onNavy,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: authState.isLoading
                          ? SizedBox(
                              key: const ValueKey('loading'),
                              width: 21,
                              height: 21,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _palette.onNavy,
                                ),
                              ),
                            )
                          : Row(
                              key: const ValueKey('login'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'CONTINUE TO VTOP',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              if (_hasSavedBiometricCreds ||
                  StorageService.isBiometricEnabledSync()) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 54,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: authState.isLoading
                        ? null
                        : _handleBiometricQuickLogin,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: _surface,
                      side: BorderSide(color: _line, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Tooltip(
                      message: 'Sign in with Biometrics',
                      child: Icon(
                        Icons.fingerprint_rounded,
                        color: _blue,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          )
              .animate()
              .fadeIn(duration: 350.ms, delay: 200.ms)
              .slideY(begin: .05, end: 0),

          const SizedBox(height: 17),

          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _cream,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: _inkSoft,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Use the same credentials you use on VTOP. OTP verification will appear automatically when required.',
                    style: GoogleFonts.dmSans(
                      fontSize: 10.5,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: _inkSoft,
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

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: _inkSoft,
        letterSpacing: 1.25,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.dmSans(
        fontSize: 13,
        color: _muted,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(
        icon,
        color: _inkSoft,
        size: 19,
      ),
      filled: true,
      fillColor: _surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: _blue,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: _palette.red,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: _palette.red,
          width: 1.5,
        ),
      ),
      errorStyle: GoogleFonts.dmSans(
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildPasswordField() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _passwordController,
      builder: (context, value, child) {
        return TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
          decoration: _inputDecoration(
            hint: 'Enter your password',
            icon: Icons.lock_outline_rounded,
          ).copyWith(
            suffixIcon: IconButton(
              tooltip: _obscurePassword
                  ? 'Show password'
                  : 'Hide password',
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: _inkSoft,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            return null;
          },
        );
      },
    );
  }

  Widget _buildSecurityNote() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.shield_outlined,
          size: 14,
          color: _muted,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Credentials are encrypted and stored locally',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _muted,
            ),
          ),
        ),
      ],
    );
  }
}
