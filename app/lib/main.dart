import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_nav_screen.dart';
import 'screens/otp_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: VitapNexusApp(),
    ),
  );
}

class VitapNexusApp extends ConsumerWidget {
  const VitapNexusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'VITAP Nexus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: authState.isLoading
          ? const Scaffold(
              backgroundColor: AppTheme.background,
              body: Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            )
          : authState.otpRequired
              ? const OtpScreen()
              : authState.isAuthenticated
                  ? const MainNavScreen()
                  : const LoginScreen(),
    );
  }
}
