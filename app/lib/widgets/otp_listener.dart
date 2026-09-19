import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/vtop_providers.dart';
import '../screens/main_nav_screen.dart';

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

    // Listen for OTP requirement after the widget tree is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ref.listenManual<AuthState>(
        authProvider,
        (previous, next) {
          if (next.otpRequired && !_dialogShowing) {
            _showOtpDialog();
          }
        },
      );

      // Handle the case where otpRequired was already true
      // before the listener was registered.
      final state = ref.read(authProvider);

      if (state.otpRequired && !_dialogShowing) {
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

    final controller = TextEditingController();

    try {
      bool verified = false;

      await showDialog<void>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (dialogContext) {
          bool isVerifying = false;

          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text(
                  'Enter OTP',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'An OTP has been sent to your registered VTOP contact.',
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'OTP',
                        hintText: '000000',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isVerifying
                        ? null
                        : () {
                            ref.read(authProvider.notifier).cancelOtp();
                            Navigator.of(context).pop();
                          },
                    child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                  ),
                  TextButton(
                    onPressed: isVerifying
                        ? null
                        : () async {
                            final ok = await ref.read(authProvider.notifier).resendOtp();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok ? 'OTP resent successfully.' : 'Failed to resend OTP.',
                                ),
                              ),
                            );
                          },
                    child: const Text('Resend OTP'),
                  ),
                  ElevatedButton(
                    onPressed: isVerifying
                        ? null
                        : () async {
                            final otp = controller.text.trim();

                            if (otp.length != 6) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enter a valid 6-digit OTP.',
                                  ),
                                ),
                              );
                              return;
                            }

                            setState(() {
                              isVerifying = true;
                            });

                            try {
                              final success = await ref
                                  .read(authProvider.notifier)
                                  .verifyOtp(otp);

                              if (!context.mounted) return;

                              if (success) {
                                debugPrint(
                                  'OTP LISTENER → OTP verified successfully.',
                                );

                                verified = true;

                                // Close ONLY the OTP dialog.
                                Navigator.of(context).pop();
                              } else {
                                setState(() {
                                  isVerifying = false;
                                });

                                final error =
                                    ref.read(authProvider).errorMessage;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      error ??
                                          'Invalid OTP. Please try again.',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (!context.mounted) return;

                              setState(() {
                                isVerifying = false;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString(),
                                  ),
                                ),
                              );
                            }
                          },
                    child: isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Verify',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              );
            },
          );
        },
      );

      // IMPORTANT:
      // Wait until the dialog route has completely finished popping
      // before refreshing data / navigating.
      if (verified && mounted) {
        await Future<void>.delayed(
          const Duration(milliseconds: 150),
        );

        if (!mounted) return;

        // Auto-sync all student data with the freshly authenticated VTOP session!
        ref.read(dashboardProvider.notifier).syncAll();

        final currentNavigator = widget.navigatorKey.currentState;

        if (currentNavigator != null && !currentNavigator.canPop()) {
          debugPrint(
            'OTP LISTENER → Opening dashboard from root.',
          );

          currentNavigator.pushReplacement(
            MaterialPageRoute(
              builder: (_) => const MainNavScreen(),
            ),
          );
        } else {
          debugPrint(
            'OTP LISTENER → Session verified. Remaining on active screen.',
          );
        }
      }
    } finally {
      controller.dispose();
      _dialogShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}