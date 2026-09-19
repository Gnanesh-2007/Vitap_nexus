import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_theme.dart';
import 'widgets/auth_gate.dart';
import 'widgets/otp_listener.dart';

import 'services/storage_service.dart';
import 'services/rust_vtop_engine.dart';

final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.initCache();
  await RustVtopEngine.init();

  runApp(
    const ProviderScope(
      child: VitapNexusApp(),
    ),
  );
}

class VitapNexusApp extends StatelessWidget {
  const VitapNexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VITAP Nexus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,

      navigatorKey: navigatorKey,

      builder: (context, child) {
        return OtpListener(
          navigatorKey: navigatorKey,
          child: child ?? const SizedBox.shrink(),
        );
      },

      home: const AuthGate(),
    );
  }
}