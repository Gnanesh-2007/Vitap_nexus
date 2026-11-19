import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'auth/auth_kit.dart';
import 'auth/otp_panel.dart';

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

class _OtpBottomSheet extends StatelessWidget {
  final String sessionId;
  final bool isInitialLogin;

  const _OtpBottomSheet({
    required this.sessionId,
    this.isInitialLogin = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        border: Border.all(color: palette.line),
        boxShadow: palette.elevatedShadow,
      ),
      padding: EdgeInsets.fromLTRB(24, 14, 24, 10 + bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: palette.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              OtpVerificationPanel(
                isInitialLogin: isInitialLogin,
                onVerified: () => Navigator.of(context).pop(true),
                onCancelled: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
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
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Transform.translate(
              offset: const Offset(-16, -6),
              child: AuthPulseBadge(
                icon: Icons.lock_reset_rounded,
                color: palette.orange,
                pulsing: !_isSaving,
              ),
            ),
            Text(
              'Password changed?',
              style: GoogleFonts.bricolageGrotesque(
                color: palette.ink,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                height: 1.08,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'VTOP rejected the saved password for ${widget.username}. Enter your updated VTOP password to reconnect without losing your offline data.',
              style: GoogleFonts.dmSans(
                color: palette.inkSoft,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            const AuthEyebrow('New VTOP password'),
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
