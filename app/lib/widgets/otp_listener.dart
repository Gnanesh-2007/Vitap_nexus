import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// Global wrapper that listens for in-session VTOP OTP challenges (`ApiClient.onOtpRequired`)
/// and presents the OTP Verification modal bottom sheet styled with the VITAP Nexus theme.
class OtpListener extends ConsumerStatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  const OtpListener({super.key, required this.child, this.navigatorKey});

  @override
  ConsumerState<OtpListener> createState() => _OtpListenerState();
}

class _OtpListenerState extends ConsumerState<OtpListener> {
  Completer<bool>? _activeOtpCompleter;
  Completer<bool>? _activePasswordCompleter;

  @override
  void initState() {
    super.initState();
    ApiClient.onOtpRequired = _handleOtpRequired;
    ApiClient.onCredentialsRejected = _handleCredentialsRejected;
  }

  @override
  void dispose() {
    if (ApiClient.onOtpRequired == _handleOtpRequired) {
      ApiClient.onOtpRequired = null;
    }
    if (ApiClient.onCredentialsRejected == _handleCredentialsRejected) {
      ApiClient.onCredentialsRejected = null;
    }
    super.dispose();
  }

  Future<bool> _handleCredentialsRejected(
    String username,
    String reason,
  ) async {
    if (!mounted) return false;

    final authState = ref.read(authProvider);
    // Only show global password-changed popup when user is already signed in
    if (!authState.isAuthenticated) return false;

    if (_activePasswordCompleter != null &&
        !_activePasswordCompleter!.isCompleted) {
      return _activePasswordCompleter!.future;
    }

    final completer = Completer<bool>();
    _activePasswordCompleter = completer;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final navContext =
          (widget.navigatorKey ?? navigatorKey).currentContext;
      if (!mounted || navContext == null) {
        if (!completer.isCompleted) completer.complete(false);
        _activePasswordCompleter = null;
        return;
      }

      try {
        final result = await showModalBottomSheet<bool>(
          context: navContext,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          builder: (sheetCtx) => _PasswordChangedBottomSheet(
            username: username,
            reason: reason,
          ),
        );
        if (!completer.isCompleted) {
          completer.complete(result == true);
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      } finally {
        _activePasswordCompleter = null;
      }
    });

    return completer.future;
  }

  Future<bool> _handleOtpRequired(String sessionId) async {
    if (!mounted) return false;

    final authState = ref.read(authProvider);
    // Only show global modal if user is already logged into the app (in-session renewal).
    // Initial login OTP is handled directly by LoginScreen -> OtpScreen.
    if (!authState.isAuthenticated) return false;

    ref.read(authProvider.notifier).requireInSessionOtp(sessionId);

    if (_activeOtpCompleter != null && !_activeOtpCompleter!.isCompleted) {
      return _activeOtpCompleter!.future;
    }

    final completer = Completer<bool>();
    _activeOtpCompleter = completer;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final navContext =
          (widget.navigatorKey ?? navigatorKey).currentContext;
      if (!mounted || navContext == null) {
        if (!completer.isCompleted) completer.complete(false);
        _activeOtpCompleter = null;
        return;
      }

      try {
        final result = await showModalBottomSheet<bool>(
          context: navContext,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          builder: (sheetCtx) => _OtpBottomSheet(sessionId: sessionId),
        );
        if (!completer.isCompleted) {
          completer.complete(result == true);
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      } finally {
        _activeOtpCompleter = null;
      }
    });

    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Opens the unified VTOP Email OTP Verification Bottom Sheet Popup.
/// Used both during initial login (`isInitialLogin: true`) and in-session background syncs.
Future<bool> showOtpVerificationSheet(
  BuildContext context, {
  String sessionId = '',
  bool isInitialLogin = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => _OtpBottomSheet(
      sessionId: sessionId,
      isInitialLogin: isInitialLogin,
    ),
  );
  return result == true;
}

class _OtpBottomSheet extends ConsumerStatefulWidget {
  final String sessionId;
  final bool isInitialLogin;

  const _OtpBottomSheet({
    required this.sessionId,
    this.isInitialLogin = false,
  });

  @override
  ConsumerState<_OtpBottomSheet> createState() => _OtpBottomSheetState();
}

class _OtpBottomSheetState extends ConsumerState<_OtpBottomSheet>
    with WidgetsBindingObserver {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();

  bool _isSubmitting = false;
  int _cooldownSeconds = 180;
  Timer? _cooldownTimer;
  String? _localError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCooldown(180);
    _otpFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _otpFocusNode.requestFocus();
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_isSubmitting) {
      Future.delayed(const Duration(milliseconds: 220), () {
        if (!mounted || _isSubmitting) return;
        _otpFocusNode.requestFocus();
        SystemChannels.textInput.invokeMethod('TextInput.show');
      });
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text?.trim() ?? '';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;
    final trimmed = digits.length > 6 ? digits.substring(0, 6) : digits;
    setState(() {
      _otpController.text = trimmed;
      _localError = null;
    });
    if (trimmed.length == 6) {
      await _submitOtp();
    }
  }

  Future<void> _submitOtp() async {
    final code = _otpController.text.trim();
    if (code.length < 6) {
      setState(() => _localError = 'Please enter all 6 digits of the OTP.');
      return;
    }

    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _localError = null;
    });

    final bool success;
    if (widget.isInitialLogin) {
      success = await ref.read(authProvider.notifier).verifyOtp(code);
    } else {
      success = await ref.read(authProvider.notifier).verifyInSessionOtp(code);
    }

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      final err =
          ref.read(authProvider).errorMessage ??
          'Invalid OTP. Please try again.';
      setState(() {
        _isSubmitting = false;
        _localError = err;
      });
      _otpFocusNode.requestFocus();
    }
  }

  Future<void> _handleResend() async {
    if (_cooldownSeconds > 0 || _isSubmitting) return;
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
          'VIT-AP VTOP enforces two-factor email OTP verification whenever a new portal session is opened or renewed.\n\nOnce verified, your session remains active and your latest academic data is cached for instant offline access.',
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final code = _otpController.text;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 28, 24, 20 + bottomInset),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: palette.line, width: 1.2)),
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '6-DIGIT EMAIL CODE',
                  style: GoogleFonts.spaceGrotesk(
                    color: palette.inkMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                InkWell(
                  onTap: _isSubmitting ? null : _pasteFromClipboard,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.content_paste_rounded,
                          size: 13,
                          color: palette.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Paste OTP',
                          style: GoogleFonts.dmSans(
                            color: palette.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 6 Connected OTP Boxes with Single Hidden Controller
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
                          enabled: !_isSubmitting,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          maxLength: 6,
                          contextMenuBuilder: (context, editableTextState) =>
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

            if (_localError != null) ...[
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
                  _localError!,
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
                      onPressed: (_cooldownSeconds > 0 || _isSubmitting)
                          ? null
                          : _handleResend,
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
                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                      onPressed: _isSubmitting ? null : _submitOtp,
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.blue,
                        disabledBackgroundColor: palette.blue.withValues(
                          alpha: 0.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSubmitting
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
                onPressed: _isSubmitting
                    ? null
                    : () {
                        ref.read(authProvider.notifier).cancelOtp();
                        Navigator.of(context).pop(false);
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
    );
  }
}

class _PasswordChangedBottomSheet extends ConsumerStatefulWidget {
  final String username;
  final String reason;

  const _PasswordChangedBottomSheet({
    required this.username,
    required this.reason,
  });

  @override
  ConsumerState<_PasswordChangedBottomSheet> createState() =>
      _PasswordChangedBottomSheetState();
}

class _PasswordChangedBottomSheetState
    extends ConsumerState<_PasswordChangedBottomSheet> {
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isSaving = false;
  String? _localError;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final newPass = _passwordCtrl.text.trim();
    if (newPass.isEmpty) {
      setState(() => _localError = 'Please enter your new VTOP password.');
      return;
    }

    setState(() {
      _isSaving = true;
      _localError = null;
    });

    final auth = ref.read(authProvider);
    final user = widget.username.isNotEmpty
        ? widget.username
        : (auth.username ?? '');

    await ref.read(authProvider.notifier).updateSavedCredentials(
          username: user,
          password: newPass,
          semesterId: auth.activeSemesterId,
          semesterName: auth.activeSemesterName,
        );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 22 + bottomInset),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: palette.line, width: 1.2)),
        boxShadow: palette.elevatedShadow,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: palette.orange.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.lock_reset_rounded,
                    color: palette.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Password Changed on VTOP?',
                        style: GoogleFonts.spaceGrotesk(
                          color: palette.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Update your saved password to continue syncing',
                        style: GoogleFonts.dmSans(
                          color: palette.inkSoft,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.soft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.line),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: palette.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'VTOP rejected the saved password for ${widget.username}. If you changed your VTOP password recently, enter your new password below so VITAP Nexus can reconnect without losing your offline data.',
                      style: GoogleFonts.dmSans(
                        color: palette.inkSoft,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'NEW VTOP PASSWORD',
              style: GoogleFonts.spaceGrotesk(
                color: palette.inkMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordCtrl,
              autofocus: true,
              obscureText: _obscurePassword,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _handleSave(),
              style: GoogleFonts.dmSans(
                color: palette.ink,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: 'Enter your updated VTOP password',
                hintStyle: GoogleFonts.dmSans(
                  color: palette.inkMuted,
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.key_rounded,
                  color: palette.inkSoft,
                  size: 19,
                ),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: palette.inkSoft,
                    size: 19,
                  ),
                ),
                filled: true,
                fillColor: palette.soft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: palette.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: palette.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: palette.blue, width: 1.5),
                ),
              ),
            ),
            if (_localError != null) ...[
              const SizedBox(height: 10),
              Text(
                _localError!,
                style: GoogleFonts.dmSans(
                  color: palette.red,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: palette.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Later',
                        style: GoogleFonts.dmSans(
                          color: palette.inkSoft,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _handleSave,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sync_lock_rounded, size: 18),
                      label: Text(
                        'Update & Reconnect',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
