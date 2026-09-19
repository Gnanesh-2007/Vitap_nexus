import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/main_nav_screen.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _openingDashboard = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // ------------------------------------------------------------
    // Still checking saved credentials / creating VTOP session
    // ------------------------------------------------------------
    if (authState.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // ------------------------------------------------------------
    // OTP required
    //
    // Keep LoginScreen underneath temporarily.
    // OtpListener will show the OTP popup.
    // After successful OTP verification, OtpListener opens
    // MainNavScreen.
    // ------------------------------------------------------------
    if (authState.otpRequired) {
      return const LoginScreen();
    }

    // ------------------------------------------------------------
    // Already authenticated
    // ------------------------------------------------------------
    if (authState.isAuthenticated) {
      if (!_openingDashboard) {
        _openingDashboard = true;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const MainNavScreen(),
            ),
          );
        });
      }

      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // ------------------------------------------------------------
    // Not authenticated
    //
    // This is the normal LoginScreen:
    // - first-time user
    // - logged out user
    // - invalid/changed password
    // ------------------------------------------------------------
    return const LoginScreen();
  }
}