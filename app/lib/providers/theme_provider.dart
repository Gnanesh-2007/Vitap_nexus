import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(_initialThemeMode());

  static ThemeMode _initialThemeMode() {
    return StorageService.getThemeMode();
  }

  bool get isDarkMode => state == ThemeMode.dark;

  void setTheme(ThemeMode mode) {
    if (state == mode) return;
    state = mode;
    unawaited(StorageService.setThemeMode(mode));
  }

  void toggleTheme({bool? currentIsDark}) {
    final currentlyDark = currentIsDark ?? (state == ThemeMode.dark);
    if (currentlyDark) {
      setTheme(ThemeMode.light);
    } else {
      setTheme(ThemeMode.dark);
    }
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class SeedThemeNotifier extends StateNotifier<NexusSeedTheme> {
  SeedThemeNotifier()
      : super(NexusSeedTheme.fromName(StorageService.getAppThemeNameSync()));

  void setSeedTheme(NexusSeedTheme theme) {
    if (state == theme) return;
    state = theme;
    unawaited(StorageService.setAppThemeName(theme.name));
  }
}

final seedThemeProvider =
    StateNotifierProvider<SeedThemeNotifier, NexusSeedTheme>((ref) {
  return SeedThemeNotifier();
});

class AmoledModeNotifier extends StateNotifier<bool> {
  AmoledModeNotifier() : super(StorageService.isAmoledModeEnabledSync());

  void setAmoledMode(bool enabled) {
    if (state == enabled) return;
    state = enabled;
    unawaited(StorageService.setAmoledModeEnabled(enabled));
  }

  void toggleAmoledMode() => setAmoledMode(!state);
}

final amoledModeProvider =
    StateNotifierProvider<AmoledModeNotifier, bool>((ref) {
  return AmoledModeNotifier();
});
