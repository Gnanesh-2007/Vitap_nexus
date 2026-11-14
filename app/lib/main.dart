import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'providers/theme_provider.dart';
import 'services/rust_vtop_engine.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_gate.dart';
import 'widgets/otp_listener.dart';
import 'widgets/widget_sync_listener.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;
  await Future.wait([
    StorageService.initCache(),
    RustVtopEngine.init(),
  ]);

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
    final themeMode = ref.watch(themeModeProvider);
    final seedTheme = ref.watch(seedThemeProvider);
    final isAmoled = ref.watch(amoledModeProvider);

    return MaterialApp(
      title: 'VITAP Nexus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getThemeData(
        seedTheme: seedTheme,
        isDarkMode: false,
      ),
      darkTheme: AppTheme.getThemeData(
        seedTheme: seedTheme,
        isDarkMode: true,
        isAmoled: isAmoled,
      ),
      themeMode: themeMode,
      themeAnimationDuration: Duration.zero,
      navigatorKey: navigatorKey,
      builder: (context, child) {
        return WidgetSyncListener(
          child: OtpListener(
            navigatorKey: navigatorKey,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const AuthGate(),
    );
  }
}
