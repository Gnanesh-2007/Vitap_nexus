import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/error_formatter.dart';
import 'main_nav_screen.dart';
import 'otp_screen.dart';

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

    // Keep the existing OTP flow exactly intact.
    if (authState.otpRequired) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const OtpScreen(),
        ),
      );
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
              const Icon(
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
        color: _navy,
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
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBrandMark(),
          const SizedBox(height: 44),
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

  // ============================================================
  // BRAND MARK
  // ============================================================

  Widget _buildBrandMark({bool dark = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 45,
          height: 45,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: dark ? Colors.white : _navy,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Image.asset(
            'assets/images/konoha_logo.png',
            color: dark ? _navy : Colors.white,
            errorBuilder: (_, _, _) => Icon(
              Icons.school_rounded,
              color: dark ? _navy : Colors.white,
              size: 25,
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
                color: dark ? Colors.white54 : _muted,
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
        _buildBrandMark(),
        const SizedBox(height: 65),
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
        const SizedBox(height: 34),
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

          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: authState.isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                disabledBackgroundColor: _navy.withValues(alpha: .45),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: authState.isLoading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
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
                const Icon(
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
        borderSide: const BorderSide(color: _line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _blue,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppTheme.error,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppTheme.error,
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
        const Icon(
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
