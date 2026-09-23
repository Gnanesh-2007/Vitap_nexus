import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

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

  void toggleTheme() {
    if (state == ThemeMode.dark) {
      setTheme(ThemeMode.light);
    } else {
      setTheme(ThemeMode.dark);
    }
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
