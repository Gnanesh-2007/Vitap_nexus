import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/main_nav_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // 1. Loading credentials or checking saved auth
    if (authState.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F2ED),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF172B4D),
          ),
        ),
      );
    }

    // 2. OTP Required (renders LoginScreen with OTP dialog on top)
    if (authState.otpRequired) {
      return const LoginScreen();
    }

    // 3. Authenticated - directly renders MainNavScreen (immune to recents/lifecycle tab issues)
    if (authState.isAuthenticated) {
      return const MainNavScreen();
    }

    // 4. Unauthenticated
    return const LoginScreen();
  }
}