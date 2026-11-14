import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/vtop_providers.dart';
import '../services/widget_sync_service.dart';

/// Keeps the Android home-screen widgets in step with the app's cached data.
/// Wrap it around the app content; it renders [child] untouched.
class WidgetSyncListener extends ConsumerWidget {
  const WidgetSyncListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authed = ref.watch(authProvider.select((a) => a.isAuthenticated));
    final seed = ref.watch(seedThemeProvider);
    final accent = seed.seedColor.toARGB32();

    if (authed) {
      ref.listen(timetableProvider, (_, next) {
        final v = next.valueOrNull;
        if (v != null) {
          WidgetSyncService.update(timetable: v, accent: accent);
        }
      });
      ref.listen(attendanceProvider, (_, next) {
        final v = next.valueOrNull;
        if (v != null) {
          WidgetSyncService.update(attendance: v, accent: accent);
        }
      });
      ref.listen(examScheduleProvider, (_, next) {
        final v = next.valueOrNull;
        if (v != null) {
          WidgetSyncService.update(exams: v, accent: accent);
        }
      });
    } else {
      // Signed out: make sure widgets don't keep showing the last user's data.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetSyncService.clear();
      });
    }

    return child;
  }
}
