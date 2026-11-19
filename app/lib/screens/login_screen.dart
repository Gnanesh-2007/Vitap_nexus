import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/biometric_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_formatter.dart';
import '../widgets/auth/auth_kit.dart';
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
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();

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
    _userFocus.addListener(_onFocusChange);
    _passFocus.addListener(_onFocusChange);
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

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  /// A greeting that follows the clock - a small sign the app is paying attention.
  String get _greeting {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Good morning.';
    if (h >= 12 && h < 17) return 'Good afternoon.';
    if (h >= 17 && h < 22) return 'Good evening.';
    return 'Up late.';
  }

  @override
  void dispose() {
    _userFocus.dispose();
    _passFocus.dispose();
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
      body: AuthBackdrop(
        child: SafeArea(
          child: isWide
              ? _buildWideLayout(authState)
              : _buildMobileLayout(authState),
        ),
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
                  style: GoogleFonts.bricolageGrotesque(
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
                  style: GoogleFonts.bricolageGrotesque(
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
    // Fills the screen so the privacy note can sit at the very bottom, but
    // still scrolls when the keyboard is up or the phone is small.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
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
                  const SizedBox(height: 46),
                  _buildHeadline(titleSize: 36),
                  const SizedBox(height: 28),
                  _buildLoginForm(authState),
                  const Spacer(),
                  const SizedBox(height: 22),
                  _buildSecurityNote(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeadline({required double titleSize}) {
    final returning = _hasSavedBiometricCreds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthEyebrow(DateFormat('EEEE, d MMM').format(DateTime.now())),
        const SizedBox(height: 10),
        Text(
          _greeting,
          style: GoogleFonts.dmSans(
            fontSize: titleSize,
            fontWeight: FontWeight.w900,
            color: _ink,
            letterSpacing: -1.6,
            height: 1.02,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          returning
              ? 'Welcome back. Sign in to pick up where you left off.'
              : 'Sign in with your VTOP account to get started.',
          style: GoogleFonts.dmSans(
            fontSize: 13.5,
            color: _inkSoft,
            height: 1.4,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 420.ms).slideY(begin: .05, end: 0, curve: Curves.easeOutCubic);
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
                    style: GoogleFonts.bricolageGrotesque(
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
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: dark ? Colors.white70 : _muted,
                letterSpacing: 1.7,
              ),
            ),
            Text(
              'NEXUS',
              style: GoogleFonts.bricolageGrotesque(
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
        _buildHeadline(titleSize: 40),
        const SizedBox(height: 30),
        _buildLoginForm(authState),
        const SizedBox(height: 22),
        _buildSecurityNote(),
      ],
    );
  }

  Widget _buildLoginForm(AuthState authState) {
    final showBiometric =
        _hasSavedBiometricCreds || StorageService.isBiometricEnabledSync();

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Both fields live in one card, split by a hairline.
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _line),
              boxShadow: _palette.cardShadow,
            ),
            child: Column(
              children: [
                _fieldRow(
                  icon: Icons.badge_outlined,
                  label: 'Registration number',
                  focus: _userFocus,
                  field: TextFormField(
                    controller: _usernameController,
                    focusNode: _userFocus,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableSuggestions: false,
                    onFieldSubmitted: (_) => _passFocus.requestFocus(),
                    inputFormatters: [
                      TextInputFormatter.withFunction(
                        (oldValue, newValue) => newValue.copyWith(
                          text: newValue.text.toUpperCase(),
                        ),
                      ),
                    ],
                    style: _fieldText,
                    decoration: _bareDecoration('Your VTOP username'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter your VTOP username';
                      }
                      return null;
                    },
                  ),
                ),
                Divider(height: 1, thickness: 1, color: _line),
                _fieldRow(
                  icon: Icons.lock_outline_rounded,
                  label: 'Password',
                  focus: _passFocus,
                  trailing: IconButton(
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: _muted,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  field: TextFormField(
                    controller: _passwordController,
                    focusNode: _passFocus,
                    obscureText: _obscurePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!authState.isLoading) _handleLogin();
                    },
                    style: _fieldText,
                    decoration: _bareDecoration('Your VTOP password'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter your password';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 380.ms, delay: 90.ms)
              .slideY(begin: .04, end: 0, curve: Curves.easeOutCubic),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      disabledBackgroundColor: _navy.withValues(alpha: .6),
                      foregroundColor: _palette.onNavy,
                      disabledForegroundColor: _palette.onNavy,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: authState.isLoading
                          ? Row(
                              key: const ValueKey('loading'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Connecting to VTOP', style: _buttonText),
                                const SizedBox(width: 10),
                                AuthWaitingDots(color: _palette.onNavy),
                              ],
                            )
                          : Row(
                              key: const ValueKey('login'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Continue', style: _buttonText),
                                const SizedBox(width: 10),
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: _palette.onNavy.withValues(alpha: .14),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 16,
                                    color: _palette.onNavy,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              if (showBiometric) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: OutlinedButton(
                    onPressed:
                        authState.isLoading ? null : _handleBiometricQuickLogin,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: _surface,
                      side: BorderSide(color: _line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Tooltip(
                      message: 'Sign in with biometrics',
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
              .fadeIn(duration: 380.ms, delay: 160.ms)
              .slideY(begin: .04, end: 0, curve: Curves.easeOutCubic),

          const SizedBox(height: 30),

          _buildHowItWorks()
              .animate()
              .fadeIn(duration: 420.ms, delay: 260.ms),
        ],
      ),
    );
  }

  TextStyle get _fieldText => GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: _ink,
        letterSpacing: .1,
      );

  TextStyle get _buttonText => GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: .1,
      );

  /// One row of the grouped field card: icon tile, small label, bare input.
  /// The row tints very slightly and the icon takes the accent colour on focus.
  Widget _fieldRow({
    required IconData icon,
    required String label,
    required FocusNode focus,
    required Widget field,
    Widget? trailing,
  }) {
    final on = focus.hasFocus;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: focus.requestFocus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        color: on
            ? Color.alphaBlend(_blue.withValues(alpha: .055), _surface)
            : _surface,
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: on ? _blue.withValues(alpha: .13) : _cream,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: on ? _blue : _inkSoft),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuthEyebrow(label, color: on ? _blue : _muted),
                  field,
                ],
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: trailing,
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  InputDecoration _bareDecoration(String hint) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: GoogleFonts.dmSans(
        fontSize: 14.5,
        color: _muted.withValues(alpha: .75),
        fontWeight: FontWeight.w500,
      ),
      filled: false,
      contentPadding: const EdgeInsets.only(top: 5, bottom: 4),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      errorStyle: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _palette.red,
        height: 1.1,
      ),
    );
  }

  /// What actually happens after "Continue", as a three-stop line.
  Widget _buildHowItWorks() {
    Widget stop(int n, String title, String caption, {bool last = false}) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _surface,
                    border: Border.all(color: _line),
                  ),
                  child: Text(
                    '$n',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _inkSoft,
                      height: 1,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    margin: const EdgeInsets.only(left: 6, right: 6),
                    color: last ? Colors.transparent : _line,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 1),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                caption,
                style: GoogleFonts.dmSans(
                  fontSize: 10.5,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  color: _inkSoft,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuthEyebrow('What happens next'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            stop(1, 'Sign in', 'With your own VTOP login'),
            stop(2, 'Captcha', 'Solved on your phone'),
            stop(3, 'Email code', 'Only if VTOP asks', last: true),
          ],
        ),
      ],
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
            'Stays on this phone. Sent only to VTOP.',
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
