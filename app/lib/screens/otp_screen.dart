import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/vtop_providers.dart';
import '../theme/app_theme.dart';
import 'semester_selection_screen.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String? username;
  final String? password;

  const OtpScreen({super.key, this.username, this.password});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();

  int _cooldownSeconds = 180;
  Timer? _cooldownTimer;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _startCooldown(180);
    _otpFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _otpFocusNode.requestFocus();
      }
    });
  }

  void _startCooldown([int seconds = 180]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
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
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      setState(() => _localError = 'Please enter all 6 digits of the OTP.');
      return;
    }

    setState(() => _localError = null);

    final success = await ref.read(authProvider.notifier).verifyOtp(otp);

    if (success && mounted) {
      resetAllVtopProviders(ref);
      final authState = ref.read(authProvider);
      final resolvedUser = widget.username ?? authState.username ?? '';
      final resolvedPass = widget.password ?? authState.password ?? '';
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SemesterSelectionScreen(
            registrationNumber: resolvedUser,
            password: resolvedPass,
          ),
        ),
      );
    } else if (mounted) {
      final err =
          ref.read(authProvider).errorMessage ??
          'Invalid OTP. Please try again.';
      setState(() => _localError = err);
      _otpFocusNode.requestFocus();
    }
  }

  Future<void> _resendOtp() async {
    if (_cooldownSeconds > 0) return;
    setState(() => _localError = null);
    await ref.read(authProvider.notifier).resendOtp();
    if (!mounted) return;
    _startCooldown(180);
  }

  void _showWhyNeededDialog(AppPalette palette) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: palette.line),
        ),
        title: Text(
          'Why is OTP Verification Needed?',
          style: GoogleFonts.spaceGrotesk(
            color: palette.ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'VIT-AP VTOP enforces two-factor email OTP verification whenever a new portal session is opened.\n\nOnce verified, your session remains active and your academic data is cached for instant offline access.',
          style: GoogleFonts.dmSans(
            color: palette.inkSoft,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Got it',
              style: GoogleFonts.dmSans(
                color: palette.blue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final authState = ref.watch(authProvider);
    final isSubmitting = authState.isLoading;
    final code = _otpController.text;
    final errorMsg = _localError ?? authState.errorMessage;

    return Scaffold(
      backgroundColor: palette.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top bar styled with AppPalette
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(bottom: BorderSide(color: palette.line)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: palette.ink,
                      size: 24,
                    ),
                    onPressed: () {
                      ref.read(authProvider.notifier).cancelOtp();
                      Navigator.of(context).pop();
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: palette.soft,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: palette.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_open_rounded,
                          color: palette.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'VTOP',
                          style: GoogleFonts.spaceGrotesk(
                            color: palette.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const Spacer(),

            // Bottom Sheet Card styled with AppPalette
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                24,
                28,
                24,
                20 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(color: palette.line, width: 1.2),
                ),
                boxShadow: palette.elevatedShadow,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OTP Verification',
                      style: GoogleFonts.spaceGrotesk(
                        color: palette.ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'An OTP has been sent to your registered email. Please enter it below to continue.',
                      style: GoogleFonts.dmSans(
                        color: palette.inkSoft,
                        fontSize: 14.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Info Callout Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: palette.soft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: palette.line),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.info_outline_rounded,
                              color: palette.blue,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "VTOP requires this verification when the app opens a new session. It is the university's security step — the app cannot skip it.",
                                  style: GoogleFonts.dmSans(
                                    color: palette.inkSoft,
                                    fontSize: 13.5,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => _showWhyNeededDialog(palette),
                                  child: Text(
                                    'Why is this needed?',
                                    style: GoogleFonts.dmSans(
                                      color: palette.blue,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      decorationColor: palette.blue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // 6 Connected OTP Boxes
                    GestureDetector(
                      onTap: () {
                        _otpFocusNode.requestFocus();
                        _otpController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _otpController.text.length),
                        );
                      },
                      child: SizedBox(
                        height: 64,
                        child: Stack(
                          children: [
                            Container(
                              height: 64,
                              decoration: BoxDecoration(
                                color: palette.soft,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _otpFocusNode.hasFocus
                                      ? palette.blue
                                      : palette.line,
                                  width: _otpFocusNode.hasFocus ? 1.5 : 1.2,
                                ),
                              ),
                              child: Row(
                                children: List.generate(11, (itemIndex) {
                                  if (itemIndex.isOdd) {
                                    return Container(
                                      width: 1.2,
                                      height: 64,
                                      color: palette.line,
                                    );
                                  }
                                  final boxIndex = itemIndex ~/ 2;
                                  final char = boxIndex < code.length
                                      ? code[boxIndex]
                                      : '';
                                  final isActiveBox =
                                      _otpFocusNode.hasFocus &&
                                      (boxIndex == code.length ||
                                          (code.length == 6 && boxIndex == 5));
                                  return Expanded(
                                    child: Container(
                                      alignment: Alignment.center,
                                      child: char.isNotEmpty
                                          ? Text(
                                              char,
                                              style: GoogleFonts.spaceGrotesk(
                                                color: palette.ink,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            )
                                          : isActiveBox
                                          ? Container(
                                              width: 2,
                                              height: 24,
                                              color: palette.blue,
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.0,
                                child: TextField(
                                  controller: _otpController,
                                  focusNode: _otpFocusNode,
                                  autofocus: true,
                                  enabled: !isSubmitting,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  maxLength: 6,
                                  contextMenuBuilder:
                                      (context, editableTextState) =>
                                          const SizedBox.shrink(),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(6),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _localError = null;
                                    });
                                  },
                                  onSubmitted: (_) => _submitOtp(),
                                  decoration: const InputDecoration(
                                    counterText: '',
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (errorMsg != null && errorMsg.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: palette.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: palette.red.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          errorMsg,
                          style: GoogleFonts.dmSans(
                            color: palette.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),

                    // Resend OTP + Verify Row
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: OutlinedButton(
                              onPressed: (_cooldownSeconds > 0 || isSubmitting)
                                  ? null
                                  : _resendOtp,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: _cooldownSeconds > 0
                                      ? palette.line
                                      : palette.blue,
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              child: Text(
                                _cooldownSeconds > 0
                                    ? 'Resend OTP\n(${_cooldownSeconds}s)'
                                    : 'Resend OTP',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.dmSans(
                                  color: _cooldownSeconds > 0
                                      ? palette.inkMuted
                                      : palette.blue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: FilledButton(
                              onPressed: isSubmitting ? null : _submitOtp,
                              style: FilledButton.styleFrom(
                                backgroundColor: palette.blue,
                                disabledBackgroundColor: palette.blue
                                    .withValues(alpha: 0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Verify',
                                      style: GoogleFonts.dmSans(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Cancel Button
                    Center(
                      child: TextButton(
                        onPressed: isSubmitting
                            ? null
                            : () {
                                ref.read(authProvider.notifier).cancelOtp();
                                Navigator.of(context).pop();
                              },
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.dmSans(
                            color: palette.inkSoft,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
