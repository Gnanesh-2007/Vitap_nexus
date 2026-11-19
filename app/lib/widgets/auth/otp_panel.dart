import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'auth_kit.dart';

/// The whole "enter the code VTOP emailed you" experience, used by both the
/// bottom-sheet popup and the full-page OTP screen so they can never drift
/// apart.
///
/// Behaviour:
///  * one invisible text field drives six visual cells;
///  * the code is submitted as soon as the sixth digit lands (typed or pasted);
///  * a thin bar counts down the 3 minutes VTOP gives the code, after which
///    "Send a new code" unlocks;
///  * a wrong code shakes the cells; a right one turns them green for a beat
///    before [onVerified] fires.
class OtpVerificationPanel extends ConsumerStatefulWidget {
  /// true = finishing the first login, false = renewing a session mid-use.
  final bool isInitialLogin;
  final VoidCallback onVerified;
  final VoidCallback onCancelled;

  const OtpVerificationPanel({
    super.key,
    required this.isInitialLogin,
    required this.onVerified,
    required this.onCancelled,
  });

  @override
  ConsumerState<OtpVerificationPanel> createState() => _OtpVerificationPanelState();
}

class _OtpVerificationPanelState extends ConsumerState<OtpVerificationPanel>
    with WidgetsBindingObserver {
  static const int _codeLifetime = 180;

  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();

  bool _isSubmitting = false;
  bool _verified = false;
  int _secondsLeft = _codeLifetime;
  int _shakeTick = 0;
  Timer? _timer;
  String? _localError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCountdown();
    _otpFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusField());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // People leave to read the email; bring the keyboard back when they return.
    if (state == AppLifecycleState.resumed && mounted && !_isSubmitting) {
      Future.delayed(const Duration(milliseconds: 220), _focusField);
    }
  }

  void _focusField() {
    if (!mounted || _isSubmitting || _verified) return;
    _otpFocusNode.requestFocus();
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _codeLifetime);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final digits = (data?.text ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      setState(() => _localError = 'Nothing to paste. Copy the 6-digit code from the email first.');
      return;
    }
    final trimmed = digits.length > 6 ? digits.substring(0, 6) : digits;
    setState(() {
      _otpController.text = trimmed;
      _localError = null;
    });
    if (trimmed.length == 6) await _submitOtp();
  }

  Future<void> _submitOtp() async {
    final code = _otpController.text.trim();
    if (code.length < 6) {
      setState(() {
        _localError = 'Enter all 6 digits of the code.';
        _shakeTick++;
      });
      return;
    }
    if (_isSubmitting || _verified) return;

    setState(() {
      _isSubmitting = true;
      _localError = null;
    });

    final notifier = ref.read(authProvider.notifier);
    final bool success = widget.isInitialLogin
        ? await notifier.verifyOtp(code)
        : await notifier.verifyInSessionOtp(code);

    if (!mounted) return;

    if (success) {
      HapticFeedback.mediumImpact();
      setState(() {
        _isSubmitting = false;
        _verified = true;
      });
      // Let the green confirmation register before moving on.
      await Future<void>.delayed(const Duration(milliseconds: 520));
      if (mounted) widget.onVerified();
    } else {
      HapticFeedback.heavyImpact();
      final err = ref.read(authProvider).errorMessage ?? 'That code did not work. Try again.';
      setState(() {
        _isSubmitting = false;
        _localError = err;
        _shakeTick++;
        _otpController.clear();
      });
      _focusField();
    }
  }

  Future<void> _handleResend() async {
    if (_secondsLeft > 0 || _isSubmitting) return;
    setState(() {
      _localError = null;
      _otpController.clear();
    });
    await ref.read(authProvider.notifier).resendOtp();
    if (!mounted) return;
    _startCountdown();
    _focusField();
  }

  void _showWhyNeeded(AppPalette palette) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.line),
        ),
        title: Text(
          'Why VTOP asks for a code',
          style: GoogleFonts.bricolageGrotesque(
            color: palette.ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'VTOP emails a one-time code whenever a new portal session is opened '
          'or renewed. It is the university\'s own security step, so Nexus '
          'cannot skip it.\n\n'
          'Once you are verified, the session stays active and your latest '
          'data is saved on this phone for offline use.',
          style: GoogleFonts.dmSans(
            color: palette.inkSoft,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Got it',
              style: GoogleFonts.dmSans(color: palette.blue, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final code = _otpController.text;
    final expired = _secondsLeft == 0;

    final cellsState = _verified
        ? OtpCellsState.success
        : (_localError != null && code.isEmpty ? OtpCellsState.error : OtpCellsState.idle);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- header
        Transform.translate(
          offset: const Offset(-16, -8),
          child: AuthPulseBadge(
            icon: _verified ? Icons.check_rounded : Icons.mark_email_unread_outlined,
            color: _verified ? p.green : p.blue,
            pulsing: !_verified,
          ),
        ),
        Text(
          _verified ? 'You\'re in.' : 'Check your email.',
          style: GoogleFonts.bricolageGrotesque(
            color: p.ink,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.9,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.isInitialLogin
              ? 'VTOP sent a 6-digit code to your college inbox. Enter it to finish signing in.'
              : 'VTOP wants to confirm it\'s you before syncing. Enter the 6-digit code from your college inbox.',
          style: GoogleFonts.dmSans(color: p.inkSoft, fontSize: 14, height: 1.45),
        ),
        const SizedBox(height: 24),

        // ---- label + paste
        Row(
          children: [
            const AuthEyebrow('6-digit code'),
            const Spacer(),
            _QuietChip(
              icon: Icons.content_paste_rounded,
              label: 'Paste',
              onTap: (_isSubmitting || _verified) ? null : _pasteFromClipboard,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ---- cells over one invisible field
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _focusField();
            _otpController.selection = TextSelection.fromPosition(
              TextPosition(offset: _otpController.text.length),
            );
          },
          child: Stack(
            children: [
              OtpCodeCells(
                code: code,
                hasFocus: _otpFocusNode.hasFocus,
                dimmed: _isSubmitting,
                state: cellsState,
                shakeTick: _shakeTick,
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _otpController,
                    focusNode: _otpFocusNode,
                    autofocus: true,
                    enabled: !_isSubmitting && !_verified,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: 6,
                    showCursor: false,
                    contextMenuBuilder: (_, _) => const SizedBox.shrink(),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (value) {
                      setState(() => _localError = null);
                      if (value.length == 6) _submitOtp();
                    },
                    onSubmitted: (_) => _submitOtp(),
                    decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ---- inline error (no box, just a line that eases in)
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topLeft,
          child: _localError == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1.5),
                        child: Icon(Icons.error_outline_rounded, size: 15, color: p.red),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _localError!,
                          style: GoogleFonts.dmSans(
                            color: p.red,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        const SizedBox(height: 18),

        // ---- expiry + resend
        OtpExpiryBar(secondsLeft: _secondsLeft, totalSeconds: _codeLifetime),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              expired ? Icons.timer_off_outlined : Icons.timer_outlined,
              size: 14,
              color: p.inkMuted,
            ),
            const SizedBox(width: 6),
            Text(
              expired ? 'That code has expired' : 'Code expires in ${otpClock(_secondsLeft)}',
              style: GoogleFonts.dmSans(
                color: p.inkSoft,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: expired ? 1 : 0.4,
              child: InkWell(
                onTap: (expired && !_isSubmitting) ? _handleResend : null,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    'Send a new code',
                    style: GoogleFonts.dmSans(
                      color: expired ? p.blue : p.inkMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        // ---- primary action
        SizedBox(
          height: 56,
          width: double.infinity,
          child: FilledButton(
            onPressed: (_isSubmitting || _verified) ? null : _submitOtp,
            style: FilledButton.styleFrom(
              backgroundColor: p.navy,
              foregroundColor: p.onNavy,
              disabledBackgroundColor:
                  _verified ? p.green.withValues(alpha: 0.9) : p.navy.withValues(alpha: 0.55),
              disabledForegroundColor: p.onNavy,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _verified
                  ? Row(
                      key: const ValueKey('done'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded, size: 19),
                        const SizedBox(width: 8),
                        Text('Verified', style: _buttonText),
                      ],
                    )
                  : _isSubmitting
                      ? Row(
                          key: const ValueKey('busy'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Checking with VTOP', style: _buttonText),
                            const SizedBox(width: 10),
                            AuthWaitingDots(color: p.onNavy),
                          ],
                        )
                      : Text('Verify', key: const ValueKey('idle'), style: _buttonText),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // ---- quiet footer
        Row(
          children: [
            TextButton(
              onPressed: () => _showWhyNeeded(p),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                foregroundColor: p.inkSoft,
              ),
              child: Text(
                'Why does VTOP ask for this?',
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: p.inkSoft,
                  decoration: TextDecoration.underline,
                  decorationColor: p.line,
                ),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: (_isSubmitting || _verified)
                  ? null
                  : () {
                      ref.read(authProvider.notifier).cancelOtp();
                      widget.onCancelled();
                    },
              style: TextButton.styleFrom(foregroundColor: p.inkSoft),
              child: Text(
                'Cancel',
                style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }

  TextStyle get _buttonText => GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.1,
      );
}

class _QuietChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuietChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: p.soft,
      shape: StadiumBorder(side: BorderSide(color: p.line)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: p.inkSoft),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  color: p.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
