import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/main_nav_screen.dart';
import '../screens/otp_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // 1. Loading credentials or checking saved auth from cold start
    if (authState.isLoading && !authState.isAuthenticated) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F2ED),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF172B4D),
          ),
        ),
      );
    }

    // 2. If authenticated, always keep MainNavScreen active.
    // In-session OTP requests are handled cleanly via OtpListener overlay dialog.
    if (authState.isAuthenticated) {
      return const MainNavScreen();
    }

    // 3. Initial login OTP required (cold login flow)
    if (authState.otpRequired) {
      return const OtpScreen();
    }

    // 4. Unauthenticated
    return const LoginScreen();
  }
}