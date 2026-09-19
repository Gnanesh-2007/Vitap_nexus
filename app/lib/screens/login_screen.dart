import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/mesh_ambient_background.dart';
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

  // ─────────────────────────────────────────────
  // MINIMALIST THEME COLORS
  // ─────────────────────────────────────────────

  static const Color _background = Color(0xFF0F1117);
  static const Color _surface = Color(0xFF171B24);
  static const Color _surfaceLight = Color(0xFF1C202A);
  static const Color _border = Color(0xFF2A2F3A);

  static const Color _accent = Color(0xFF8B8FD8);
  static const Color _accentSoft = Color(0xFFB7B9E8);

  static const Color _textPrimary = Color(0xFFF4F4F5);
  static const Color _textSecondary = Color(0xFF9CA3AF);
  static const Color _textMuted = Color(0xFF687080);

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // LOGIN LOGIC
  // ─────────────────────────────────────────────

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

    // CRITICAL: If VTOP requires OTP, immediately navigate to the OtpScreen
    // without showing any "Login failed" error!
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
      final error =
          authState.errorMessage ??
          'Login failed. Please check your credentials and try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(error),
              ),
            ],
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: _background,
      body: MeshAmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 28.0,
              ),
              child: Form(
                key: _formKey,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 430,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ─────────────────────────────────────────
                      // KONOHA LOGO
                      // ─────────────────────────────────────────

                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: _surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _border,
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _accent.withOpacity(0.12),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/konoha_logo.png',
                            width: 58,
                            height: 58,
                            color: _accentSoft,
                            colorBlendMode: BlendMode.srcIn,
                            errorBuilder:
                                (context, error, stackTrace) =>
                                    const Icon(
                              Icons.school_rounded,
                              size: 52,
                              color: _accentSoft,
                            ),
                          ),
                        ),
                      )
                          .animate()
                          .scale(
                            duration: 500.ms,
                            curve: Curves.easeOutBack,
                          )
                          .fadeIn(
                            duration: 400.ms,
                          ),

                      const SizedBox(height: 24),

                      // ─────────────────────────────────────────
                      // APP TITLE
                      // ─────────────────────────────────────────

                      Text(
                        'VITAP NEXUS',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 29,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.2,
                          color: _textPrimary,
                        ),
                      ).animate().fadeIn(
                            duration: 400.ms,
                            delay: 100.ms,
                          ),

                      const SizedBox(height: 7),

                      Text(
                        'Your smart companion for VIT-AP',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: _textSecondary,
                          letterSpacing: 0.1,
                        ),
                      ).animate().fadeIn(
                            duration: 400.ms,
                            delay: 150.ms,
                          ),

                      const SizedBox(height: 36),

                      // ─────────────────────────────────────────
                      // LOGIN CARD
                      // ─────────────────────────────────────────

                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: _surface.withOpacity(0.94),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _border,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.20),
                              blurRadius: 30,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            // ─────────────────────────────────
                            // WELCOME
                            // ─────────────────────────────────

                            Text(
                              'Welcome back',
                              style: GoogleFonts.manrope(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),

                            const SizedBox(height: 5),

                            Text(
                              'Sign in with your VTOP credentials',
                              style: GoogleFonts.manrope(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: _textSecondary,
                              ),
                            ),

                            const SizedBox(height: 25),

                            // ─────────────────────────────────
                            // USERNAME
                            // ─────────────────────────────────

                            Text(
                              'VTOP Username / Reg Number',
                              style: GoogleFonts.manrope(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _textSecondary,
                              ),
                            ),

                            const SizedBox(height: 8),

                            TextFormField(
                              controller: _usernameController,
                              style: GoogleFonts.manrope(
                                color: _textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              textCapitalization:
                                  TextCapitalization.characters,
                              inputFormatters: [
                                TextInputFormatter.withFunction(
                                  (oldValue, newValue) =>
                                      newValue.copyWith(
                                    text: newValue.text.toUpperCase(),
                                  ),
                                ),
                              ],
                              decoration: InputDecoration(
                                hintText:
                                    'e.g. 24BCE8650 or NARUTO2007',
                                hintStyle: GoogleFonts.manrope(
                                  color: _textMuted,
                                  fontSize: 13,
                                ),
                                prefixIcon: const Icon(
                                  Icons.person_outline_rounded,
                                  color: _accent,
                                  size: 20,
                                ),
                                filled: true,
                                fillColor: _surfaceLight,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: _border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: _border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: _accent,
                                    width: 1.3,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppTheme.error,
                                  ),
                                ),
                                focusedErrorBorder:
                                    OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppTheme.error,
                                    width: 1.3,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null ||
                                    value.trim().isEmpty) {
                                  return 'Please enter your username';
                                }

                                return null;
                              },
                            )
                                .animate()
                                .fadeIn(
                                  duration: 400.ms,
                                  delay: 200.ms,
                                )
                                .slideY(
                                  begin: 0.08,
                                  end: 0,
                                ),

                            const SizedBox(height: 20),

                            // ─────────────────────────────────
                            // PASSWORD LABEL
                            // ─────────────────────────────────

                            Text(
                              'VTOP Password',
                              style: GoogleFonts.manrope(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _textSecondary,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // ─────────────────────────────────
                            // PASSWORD FIELD
                            //
                            // IMPORTANT:
                            // We do NOT use obscureText here.
                            //
                            // Instead, the real password remains
                            // inside _passwordController while
                            // the actual text is rendered
                            // transparent and we draw our own
                            // bullets on top.
                            //
                            // This prevents the last character
                            // from briefly appearing.
                            // ─────────────────────────────────

                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _passwordController,
                              builder: (
                                context,
                                value,
                                child,
                              ) {
                                return Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    TextFormField(
                                      controller:
                                          _passwordController,

                                      // Deliberately false.
                                      // We handle masking ourselves.
                                      obscureText: false,

                                      autocorrect: false,
                                      enableSuggestions: false,

                                      keyboardType:
                                          TextInputType.visiblePassword,

                                      cursorColor: _accent,

                                      style: GoogleFonts.manrope(
                                        color: _obscurePassword
                                            ? Colors.transparent
                                            : _textPrimary,
                                        fontSize: 14,
                                        fontWeight:
                                            FontWeight.w500,
                                      ),

                                      decoration: InputDecoration(
                                        hintText: value.text.isEmpty
                                            ? '••••••••••••'
                                            : null,

                                        hintStyle:
                                            GoogleFonts.manrope(
                                          color: _textMuted,
                                        ),

                                        prefixIcon: const Icon(
                                          Icons
                                              .lock_outline_rounded,
                                          color: _accent,
                                          size: 20,
                                        ),

                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons
                                                    .visibility_off_rounded
                                                : Icons
                                                    .visibility_rounded,
                                            color: _textSecondary,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                        ),

                                        filled: true,
                                        fillColor: _surfaceLight,

                                        contentPadding:
                                            const EdgeInsets
                                                .symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),

                                        border:
                                            OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide:
                                              const BorderSide(
                                            color: _border,
                                          ),
                                        ),

                                        enabledBorder:
                                            OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide:
                                              const BorderSide(
                                            color: _border,
                                          ),
                                        ),

                                        focusedBorder:
                                            OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide:
                                              const BorderSide(
                                            color: _accent,
                                            width: 1.3,
                                          ),
                                        ),

                                        errorBorder:
                                            OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide:
                                              const BorderSide(
                                            color: AppTheme.error,
                                          ),
                                        ),

                                        focusedErrorBorder:
                                            OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide:
                                              const BorderSide(
                                            color: AppTheme.error,
                                            width: 1.3,
                                          ),
                                        ),
                                      ),

                                      validator: (value) {
                                        if (value == null ||
                                            value.isEmpty) {
                                          return 'Please enter your password';
                                        }

                                        return null;
                                      },
                                    ),

                                    // ─────────────────────────
                                    // MANUAL PASSWORD MASK
                                    // ─────────────────────────

                                    if (_obscurePassword &&
                                        value.text.isNotEmpty)
                                      Positioned(
                                        left: 48,
                                        right: 48,
                                        child: IgnorePointer(
                                          child: Text(
                                            '•' * value.text.length,
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.clip,
                                            style:
                                                GoogleFonts.manrope(
                                              color: _textSecondary,
                                              fontSize: 14,
                                              fontWeight:
                                                  FontWeight.w500,
                                              letterSpacing: 2.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            )
                                .animate()
                                .fadeIn(
                                  duration: 400.ms,
                                  delay: 250.ms,
                                )
                                .slideY(
                                  begin: 0.08,
                                  end: 0,
                                ),

                            const SizedBox(height: 28),

                            // ─────────────────────────────────
                            // LOGIN BUTTON
                            // ─────────────────────────────────

                            Container(
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        _accent.withOpacity(0.16),
                                    blurRadius: 20,
                                    offset: const Offset(0, 7),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: authState.isLoading
                                    ? null
                                    : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _accent,
                                  disabledBackgroundColor:
                                      _accent.withOpacity(0.55),
                                  shadowColor: Colors.transparent,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  child: authState.isLoading
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child:
                                              CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.3,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Login with VTOP',
                                              style:
                                                  GoogleFonts.manrope(
                                                fontSize: 14.5,
                                                fontWeight:
                                                    FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons
                                                  .arrow_forward_rounded,
                                              color: Colors.white,
                                              size: 19,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            )
                                .animate()
                                .fadeIn(
                                  duration: 400.ms,
                                  delay: 300.ms,
                                )
                                .scale(
                                  begin: const Offset(0.97, 0.97),
                                  end: const Offset(1, 1),
                                ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ─────────────────────────────────────────
                      // PRIVACY NOTE
                      // ─────────────────────────────────────────

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.lock_clock_outlined,
                            size: 14,
                            color: _textMuted,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Credentials are encrypted and stored locally only',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: _textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}