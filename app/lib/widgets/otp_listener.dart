import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../providers/vtop_providers.dart';
import '../utils/error_formatter.dart';

class OtpListener extends ConsumerStatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const OtpListener({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  ConsumerState<OtpListener> createState() => _OtpListenerState();
}

class _OtpListenerState extends ConsumerState<OtpListener> {
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();

    // Listen for in-session OTP requests after the widget tree is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ref.listenManual<AuthState>(
        authProvider,
        (previous, next) {
          if (next.otpRequired && !_dialogShowing && next.isAuthenticated) {
            _showOtpDialog();
          }
        },
      );

      // Handle cases where otpRequired was already active in an authenticated session.
      final state = ref.read(authProvider);
      if (state.otpRequired && !_dialogShowing && state.isAuthenticated) {
        _showOtpDialog();
      }
    });
  }

  Future<void> _showOtpDialog() async {
    if (!mounted || _dialogShowing) return;

    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('OTP LISTENER → Navigator is not ready.');
      return;
    }

    _dialogShowing = true;

    try {
      final verified = await showDialog<bool>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (dialogContext) => const _SessionOtpModal(),
      );

      if (verified == true && mounted) {
        // Silently sync freshly authenticated data without popping or navigating
        ref.read(dashboardProvider.notifier).syncAll();
      }
    } finally {
      _dialogShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _SessionOtpModal extends ConsumerStatefulWidget {
  const _SessionOtpModal();

  @override
  ConsumerState<_SessionOtpModal> createState() => _SessionOtpModalState();
}

class _SessionOtpModalState extends ConsumerState<_SessionOtpModal>
    with SingleTickerProviderStateMixin {
  static const int _otpLength = 6;

  final List<TextEditingController> _controllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  Timer? _cooldownTimer;
  int _cooldownSeconds = 30;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  // Editorial campus design tokens
  static const _surface = Color(0xFFFFFEFB);
  static const _ink = Color(0xFF17202A);
  static const _inkSoft = Color(0xFF56616D);
  static const _navy = Color(0xFF172B4D);
  static const _blue = Color(0xFF356AE6);
  static const _red = Color(0xFFC84C43);
  static const _muted = Color(0xFF6E7681);
  static const _line = Color(0xFFE2DED5);
  static const _soft = Color(0xFFF0EEE8);

  bool get _isCooldownActive => _cooldownSeconds > 0;
  String get _otp => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startCooldownTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  void _setupAnimations() {
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
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

  void _startCooldownTimer() {
    _cooldownSeconds = 30;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
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

  void _triggerError(String message) {
    setState(() => _errorMessage = message);
    _shakeController.forward(from: 0);
    HapticFeedback.vibrate();

    for (final c in _controllers) {
      c.clear();
    }
    if (mounted) _focusNodes[0].requestFocus();
  }

  Future<void> _submitOtp() async {
    if (_isVerifying) return;

    final otp = _otp.trim();
    if (otp.length != _otpLength) {
      _triggerError('Please enter a valid 6-digit OTP.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final success = await ref.read(authProvider.notifier).verifyOtp(otp);

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
      } else {
        final rawErr = ref.read(authProvider).errorMessage;
        final err = ErrorFormatter.cleanRawMessage(
          rawErr ?? 'Invalid OTP code.',
          fallback: 'The OTP entered is incorrect. Please check and re-enter.',
        );
        _triggerError(err);
      }
    } catch (e) {
      if (!mounted) return;
      _triggerError(ErrorFormatter.format(e, fallback: 'Failed to verify OTP. Please try again.'));
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_isCooldownActive || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });
    _startCooldownTimer();

    try {
      final ok = await ref.read(authProvider.notifier).resendOtp();
      if (!mounted) return;
      if (!ok) {
        setState(() => _errorMessage = 'Could not resend OTP. Please wait a moment and try again.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = ErrorFormatter.format(e, fallback: 'Could not resend OTP. Please try again.'));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _cancel() {
    ref.read(authProvider.notifier).cancelOtp();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          ref.read(authProvider.notifier).cancelOtp();
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _line),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Security Badge & Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _soft,
                    shape: BoxShape.circle,
                    border: Border.all(color: _line),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    size: 24,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 14),

                // Title
                Text(
                  'Security Verification',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 6),

                // Subtitle
                Text(
                  'An OTP has been sent to your registered VTOP contact to verify this action.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: _inkSoft,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),

                // 6-digit OTP Boxes
                AnimatedBuilder(
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
                            right: index == _otpLength - 1 ? 0 : 6,
                          ),
                          child: _buildDigitBox(index),
                        ),
                      );
                    }),
                  ),
                ),

                // Error Message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCEDEA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 14, color: _red),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.dmSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: _red,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 200.ms),
                ],

                const SizedBox(height: 16),

                // Resend OTP Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive code?",
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _isCooldownActive || _isResending ? null : _resendOtp,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          _isCooldownActive
                              ? 'Resend in ${_cooldownSeconds}s'
                              : 'Resend OTP',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _isCooldownActive ? _muted : _blue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // Bottom Buttons: Cancel & Verify
                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _isVerifying ? null : _cancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _ink,
                            side: const BorderSide(color: _line, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Verify Button
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isVerifying ? null : _submitOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isVerifying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Verify',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
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
    );
  }

  Widget _buildDigitBox(int index) {
    return AnimatedBuilder(
      animation: _focusNodes[index],
      builder: (context, _) {
        final isFocused = _focusNodes[index].hasFocus;
        final hasText = _controllers[index].text.isNotEmpty;

        return Container(
          height: 50,
          decoration: BoxDecoration(
            color: isFocused ? _surface : _soft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFocused
                  ? _blue
                  : hasText
                      ? const Color(0xFF9BB3E8)
                      : _line,
              width: isFocused ? 1.8 : 1,
            ),
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
            inputFormatters: [
              LengthLimitingTextInputFormatter(1),
              FilteringTextInputFormatter.digitsOnly,
            ],
            style: GoogleFonts.spaceGrotesk(
              color: _ink,
              fontSize: 20,
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
}