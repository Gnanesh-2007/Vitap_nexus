import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/error_formatter.dart';
import 'main_nav_screen.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with SingleTickerProviderStateMixin {
  static const int _otpLength = 6;

  final List<TextEditingController> _controllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  bool _isSubmittingOtp = false;
  bool _isResendingOtp = false;

  AppPalette get _palette => AppPalette.of(context);
  Color get _paper => _palette.paper;
  Color get _surface => _palette.surface;
  Color get _ink => _palette.ink;
  Color get _navy => _palette.navy;
  Color get _blue => _palette.blue;
  Color get _orange => _palette.orange;
  Color get _red => _palette.red;
  Color get _muted => _palette.inkMuted;
  Color get _line => _palette.line;
  Color get _soft => _palette.soft;

  bool get _isCooldownActive => _cooldownSeconds > 0;
  String get _otp => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _setupAnimations();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  void _setupAnimations() {
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();

    for (final c in _controllers) {
      c.dispose();
    }

    for (final f in _focusNodes) {
      f.dispose();
    }

    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitEntered(int index, String value) {
    if (value.isNotEmpty) {
      if (index < _otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _submitOtp();
      }
    }
  }

  void _triggerErrorFeedback() {
    _shakeController.forward(from: 0);
    HapticFeedback.vibrate();

    for (final c in _controllers) {
      c.clear();
    }

    _focusNodes[0].requestFocus();
    setState(() {});
  }

  Future<void> _submitOtp() async {
    if (_isSubmittingOtp) return;

    final otp = _otp;

    if (otp.length < _otpLength) {
      _triggerErrorFeedback();
      return;
    }

    _isSubmittingOtp = true;

    try {
      final success =
          await ref.read(authProvider.notifier).verifyOtp(otp);

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const MainNavScreen(),
          ),
          (route) => false,
        );
      } else {
        _triggerErrorFeedback();
      }
    } finally {
      _isSubmittingOtp = false;
    }
  }

  void _startResendCooldown() {
    setState(() => _cooldownSeconds = 30);
    _cooldownTimer?.cancel();

    _cooldownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_isCooldownActive || _isResendingOtp) return;

    _isResendingOtp = true;
    _startResendCooldown();

    try {
      await ref.read(authProvider.notifier).resendOtp();
    } finally {
      _isResendingOtp = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final username = authState.username ?? '';

    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 720;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                22,
                compact ? 14 : 24,
                22,
                18,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight -
                      MediaQuery.of(context).padding.vertical -
                      42,
                ),
                child: Column(
                  children: [
                    _buildTopBar(),
                    SizedBox(height: compact ? 28 : 48),
                    _buildSecurityHeader(
                      username: username,
                      compact: compact,
                    ),
                    SizedBox(height: compact ? 28 : 38),
                    _buildOtpFields(),
                    const SizedBox(height: 16),
                    _buildError(authState),
                    SizedBox(height: compact ? 20 : 28),
                    _buildVerifyButton(authState),
                    const SizedBox(height: 22),
                    _buildResendRow(),
                    const SizedBox(height: 30),
                    _buildSecurityNote(),
                    const SizedBox(height: 24),
                    _buildBackButton(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _line),
          ),
          child: Icon(
            Icons.lock_outline_rounded,
            color: _navy,
            size: 19,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VIT-AP NEXUS',
                style: GoogleFonts.spaceGrotesk(
                  color: _orange,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Secure sign-in',
                style: GoogleFonts.dmSans(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _line),
          ),
          child: Text(
            'OTP',
            style: GoogleFonts.spaceGrotesk(
              color: _navy,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityHeader({
    required String username,
    required bool compact,
  }) {
    return Column(
      children: [
        Container(
          width: compact ? 64 : 74,
          height: compact ? 64 : 74,
          decoration: BoxDecoration(
            color: _surface,
            shape: BoxShape.circle,
            border: Border.all(color: _line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D17202A),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/konoha_logo.png',
              width: compact ? 35 : 40,
              height: compact ? 35 : 40,
              errorBuilder: (_, _, _) => Icon(
                Icons.verified_user_outlined,
                color: _navy,
                size: 34,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Security Verification',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            color: _ink,
            fontSize: compact ? 25 : 29,
            fontWeight: FontWeight.w800,
            letterSpacing: -.7,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          'Enter the 6-digit code sent to',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            color: _muted,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          username.isEmpty ? 'your registered account' : username,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.spaceGrotesk(
            color: _blue,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: .2,
          ),
        ),
      ],
    );
  }

  Widget _buildOtpFields() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_otpLength, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == _otpLength - 1 ? 0 : 7,
              ),
              child: _buildOtpBox(index),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return AnimatedBuilder(
      animation: _focusNodes[index],
      builder: (context, _) {
        final isFocused = _focusNodes[index].hasFocus;
        final hasText = _controllers[index].text.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 58,
          decoration: BoxDecoration(
            color: isFocused ? _surface : _soft,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isFocused
                  ? _blue
                  : hasText
                      ? const Color(0xFF9BB3E8)
                      : _line,
              width: isFocused ? 2 : 1,
            ),
            boxShadow: isFocused
                ? const [
                    BoxShadow(
                      color: Color(0x16356AE6),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            showCursor: false,
            enableInteractiveSelection: false,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              LengthLimitingTextInputFormatter(1),
              FilteringTextInputFormatter.digitsOnly,
            ],
            style: GoogleFonts.spaceGrotesk(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (value) => _onDigitEntered(index, value),
          ),
        );
      },
    );
  }

  Widget _buildError(dynamic authState) {
    if (authState.errorMessage == null || authState.isLoading) {
      return const SizedBox.shrink();
    }

    final friendlyError = ErrorFormatter.cleanRawMessage(
      authState.errorMessage!,
      fallback: 'The OTP entered is incorrect. Please check and try again.',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEDEA),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE7C6C1)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 17,
            color: _red,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              friendlyError,
              style: GoogleFonts.dmSans(
                color: _red,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyButton(dynamic authState) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: authState.isLoading ? null : _submitOtp,
        style: FilledButton.styleFrom(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _navy.withValues(alpha: .55),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: authState.isLoading
            ? const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Verify & Proceed',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildResendRow() {
    final active = _isCooldownActive;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Didn't get the code?",
          style: GoogleFonts.dmSans(
            color: _muted,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: active ? null : _resendOtp,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 3,
            ),
            child: Text(
              active
                  ? 'Resend in ${_cooldownSeconds}s'
                  : 'Resend OTP',
              style: GoogleFonts.dmSans(
                color: active ? _muted : _blue,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.privacy_tip_outlined,
            size: 17,
            color: Color(0xFF278B68),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Your verification code is used only to complete this secure sign-in.',
              style: GoogleFonts.dmSans(
                color: _muted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return TextButton.icon(
      onPressed: () => ref.read(authProvider.notifier).logout(),
      icon: Icon(
        Icons.arrow_back_rounded,
        size: 16,
      ),
      label: Text(
        'Back to Sign In',
        style: GoogleFonts.dmSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: _muted,
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 11,
        ),
      ),
    );
  }
}
