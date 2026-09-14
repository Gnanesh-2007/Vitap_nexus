import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _resendCooldown = false;
  int _cooldownSeconds = 30;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12).chain(
      CurveTween(curve: Curves.elasticIn),
    ).animate(_shakeController);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _shakeController.dispose();
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _onDigitEntered(int index, String value) {
    if (value.isEmpty) {
      // Backspace — move to previous field
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
      return;
    }
    if (index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
      _submitOtp();
    }
  }

  Future<void> _submitOtp() async {
    final otp = _otp;
    if (otp.length < 6) {
      _shakeController.forward(from: 0);
      return;
    }

    final success = await ref.read(authProvider.notifier).verifyOtp(otp);
    if (!success && mounted) {
      _shakeController.forward(from: 0);
      // Clear fields on wrong OTP
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCooldown) return;
    setState(() {
      _resendCooldown = true;
      _cooldownSeconds = 30;
    });
    await ref.read(authProvider.notifier).resendOtp();

    // Countdown timer
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _cooldownSeconds--;
      });
      if (_cooldownSeconds <= 0) {
        if (mounted) setState(() => _resendCooldown = false);
        return false;
      }
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final username = authState.username ?? '';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),

              // Header
              Image.asset(
                'assets/images/konoha_logo.png',
                width: 56,
                height: 56,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.verified_user_rounded,
                  color: AppTheme.primaryAccent,
                  size: 52,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'OTP Verification',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),

              Text(
                'VIT-AP has sent a One-Time Password to your\nregistered email/mobile',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF94A3B8),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                username,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.cyanAccent,
                ),
              ),

              const SizedBox(height: 40),

              // OTP boxes
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      _shakeAnimation.value * ((_shakeController.value % 2 == 0) ? 1 : -1),
                      0,
                    ),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    return Container(
                      width: 46,
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _focusNodes[index].hasFocus
                              ? AppTheme.primaryAccent
                              : const Color(0xFF24344D),
                          width: _focusNodes[index].hasFocus ? 2 : 1,
                        ),
                      ),
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                        ),
                        onChanged: (value) => _onDigitEntered(index, value),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 12),

              // Error message
              if (authState.errorMessage != null && !authState.isLoading)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    authState.errorMessage!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.error,
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              // Verify button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: authState.isLoading ? null : _submitOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    disabledBackgroundColor: AppTheme.surfaceLight,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Verify OTP',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // Resend OTP row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive? ",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  GestureDetector(
                    onTap: _resendCooldown ? null : _resendOtp,
                    child: Text(
                      _resendCooldown ? 'Resend in ${_cooldownSeconds}s' : 'Resend OTP',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _resendCooldown
                            ? const Color(0xFF64748B)
                            : AppTheme.primaryAccent,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Back to Login
              TextButton.icon(
                onPressed: () => ref.read(authProvider.notifier).logout(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                label: Text(
                  'Back to Login',
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
