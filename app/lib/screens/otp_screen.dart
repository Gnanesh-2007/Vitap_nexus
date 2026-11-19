import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/vtop_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/auth/auth_kit.dart';
import '../widgets/auth/otp_panel.dart';
import 'semester_selection_screen.dart';

/// Full-page version of the VTOP email-code step. The popup in
/// `otp_listener.dart` shows the same [OtpVerificationPanel]; this page just
/// gives it a whole screen and the shared backdrop.
class OtpScreen extends ConsumerWidget {
  final String? username;
  final String? password;

  const OtpScreen({super.key, this.username, this.password});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);

    void close() {
      ref.read(authProvider.notifier).cancelOtp();
      Navigator.of(context).pop();
    }

    return Scaffold(
      backgroundColor: palette.paper,
      body: AuthBackdrop(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: IconButton(
                  tooltip: 'Back to sign in',
                  onPressed: close,
                  style: IconButton.styleFrom(
                    backgroundColor: palette.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: palette.line),
                    ),
                  ),
                  icon: Icon(Icons.arrow_back_rounded, size: 20, color: palette.ink),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: OtpVerificationPanel(
                        isInitialLogin: true,
                        onCancelled: () => Navigator.of(context).pop(),
                        onVerified: () {
                          resetAllVtopProviders(ref);
                          final auth = ref.read(authProvider);
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => SemesterSelectionScreen(
                                registrationNumber: username ?? auth.username ?? '',
                                password: password ?? auth.password ?? '',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
