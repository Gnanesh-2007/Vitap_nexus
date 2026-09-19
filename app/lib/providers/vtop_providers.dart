import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import 'auth_provider.dart';

// ============================================================================
// MVVM STATE MODEL (Offline-First / Stale-While-Revalidate)
// ============================================================================

class VtopDataState<T> {
  final T? data;
  final bool isLoading;
  final bool isSyncing;
  final String? error;
  final DateTime? lastSynced;

  const VtopDataState({
    this.data,
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.lastSynced,
  });

  bool get hasData => data != null;
  T? get value => data;

  R when<R>({
    required R Function(T data) data,
    required R Function(Object error, StackTrace stackTrace) error,
    required R Function() loading,
  }) {
    if (hasData) {
      return data(this.data as T);
    }
    if (this.error != null) {
      return error(this.error!, StackTrace.current);
    }
    return loading();
  }

  R maybeWhen<R>({
    R Function(T data)? data,
    R Function(Object error, StackTrace stackTrace)? error,
    R Function()? loading,
    required R Function() orElse,
  }) {
    if (hasData && data != null) {
      return data(this.data as T);
    }
    if (this.error != null && error != null) {
      return error(this.error!, StackTrace.current);
    }
    if (loading != null && !hasData) {
      return loading();
    }
    return orElse();
  }
}

// ============================================================================
// 1. DASHBOARD VIEWMODEL (all_data)
// ============================================================================

class DashboardNotifier extends StateNotifier<VtopDataState<Map<String, dynamic>>> {
  final Ref _ref;

  DashboardNotifier(this._ref) : super(const VtopDataState(isLoading: true)) {
    _initFromCacheAndSync();
  }

  Future<void> _initFromCacheAndSync() async {
    // ── STEP 1: INSTANT MEMORY CACHE (0 ms) ─────────────────────────────────
    final memData = StorageService.getMemoryCache('all_data');
    final memTs = StorageService.getMemoryTimestamp('all_data');

    if (memData is Map<String, dynamic>) {
      state = VtopDataState(
        data: memData,
        isLoading: false,
        isSyncing: true,
        lastSynced: memTs,
      );
      debugPrint('DashboardViewModel: Rendered instantly from memory cache in 0ms');
    } else {
      // ── STEP 2: FAST DISK CACHE (< 10 ms) ─────────────────────────────────
      final diskData = await StorageService.getCache('all_data');
      final diskTs = await StorageService.getLastSynced('all_data');

      if (diskData is Map<String, dynamic>) {
        state = VtopDataState(
          data: diskData,
          isLoading: false,
          isSyncing: true,
          lastSynced: diskTs,
        );
        debugPrint('DashboardViewModel: Rendered from disk cache in <10ms');
      }
    }

    // ── STEP 3: SILENT BACKGROUND SYNC ──────────────────────────────────────
    await sync(silent: state.hasData);
  }

  Future<void> refresh() => sync(silent: false);

  Future<void> sync({bool silent = true}) async {
    final auth = _ref.read(authProvider);
    if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
      if (!state.hasData) {
        state = VtopDataState(isLoading: false, error: 'Not authenticated');
      }
      return;
    }

    if (!silent && !state.hasData) {
      state = VtopDataState(isLoading: true, isSyncing: true);
    } else {
      state = VtopDataState(
        data: state.data,
        isLoading: false,
        isSyncing: true,
        lastSynced: state.lastSynced,
      );
    }

    try {
      final semId = auth.activeSemesterId ?? '';
      final fresh = await apiService.fetchAllData(
        username: auth.username!,
        password: auth.password!,
        semSubId: semId,
      );

      final now = DateTime.now();

      // Unpack into all sub-caches simultaneously!
      await StorageService.unpackAllData(fresh);

      state = VtopDataState(
        data: fresh,
        isLoading: false,
        isSyncing: false,
        lastSynced: now,
      );

      // Refresh child FutureProviders so screens update smoothly
      _ref.invalidate(attendanceProvider);
      _ref.invalidate(timetableProvider);
      _ref.invalidate(marksProvider);
      _ref.invalidate(profileProvider);
      _ref.invalidate(gradesProvider);

      debugPrint('DashboardViewModel: Background sync complete and all sub-caches updated');
    } catch (e) {
      debugPrint('DashboardViewModel: Sync error (falling back to cache): $e');
      state = VtopDataState(
        data: state.data,
        isSyncing: false,
        isLoading: false,
        error: state.hasData ? null : 'Could not fetch data from VTOP.',
        lastSynced: state.lastSynced,
      );
    }
  }
}

final dashboardProvider = StateNotifierProvider<DashboardNotifier, VtopDataState<Map<String, dynamic>>>((ref) {
  return DashboardNotifier(ref);
});

// ============================================================================
// 2. CORE FUTURE PROVIDERS (Instant Memory Cache -> Disk Cache -> Network)
// ============================================================================

/// Dashboard allDataProvider — returns cached all_data instantly (0ms)
final allDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final mem = StorageService.getMemoryCache('all_data');
  if (mem is Map<String, dynamic> && mem.isNotEmpty) {
    return mem;
  }

  final disk = await StorageService.getCache('all_data');
  if (disk is Map<String, dynamic> && disk.isNotEmpty) {
    return disk;
  }

  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    throw Exception('Not authenticated');
  }

  final semId = auth.activeSemesterId ?? '';
  final fresh = await apiService.fetchAllData(
    username: auth.username!,
    password: auth.password!,
    semSubId: semId,
  );
  await StorageService.unpackAllData(fresh);
  return fresh;
});

/// Attendance Provider — returns cached attendance instantly (0ms)
final attendanceProvider = FutureProvider<List<dynamic>>((ref) async {
  final mem = StorageService.getMemoryCache('attendance');
  if (mem is List && mem.isNotEmpty) {
    return mem;
  }

  final disk = await StorageService.getCache('attendance');
  if (disk is List && disk.isNotEmpty) {
    return disk;
  }

  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    return [];
  }

  final semId = auth.activeSemesterId ?? '';
  final fresh = await apiService.fetchAttendance(
    username: auth.username!,
    password: auth.password!,
    semSubId: semId,
  );
  await StorageService.setCache('attendance', fresh);
  return fresh;
});

/// Timetable Provider — returns cached timetable instantly (0ms)
final timetableProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final mem = StorageService.getMemoryCache('timetable');
  if (mem is Map<String, dynamic> && mem.isNotEmpty) {
    return mem;
  }

  final disk = await StorageService.getCache('timetable');
  if (disk is Map<String, dynamic> && disk.isNotEmpty) {
    return disk;
  }

  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    return {};
  }

  final semId = auth.activeSemesterId ?? '';
  final fresh = await apiService.fetchTimetable(
    username: auth.username!,
    password: auth.password!,
    semSubId: semId,
  );
  await StorageService.setCache('timetable', fresh);
  return fresh;
});

/// Marks Provider — returns cached marks instantly (0ms)
final marksProvider = FutureProvider<List<dynamic>>((ref) async {
  final mem = StorageService.getMemoryCache('marks');
  if (mem is List && mem.isNotEmpty) {
    return mem;
  }

  final disk = await StorageService.getCache('marks');
  if (disk is List && disk.isNotEmpty) {
    return disk;
  }

  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    return [];
  }

  final semId = auth.activeSemesterId ?? '';
  final fresh = await apiService.fetchMarks(
    username: auth.username!,
    password: auth.password!,
    semSubId: semId,
  );
  await StorageService.setCache('marks', fresh);
  return fresh;
});

/// Profile Provider — returns cached profile instantly (0ms)
final profileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final mem = StorageService.getMemoryCache('profile');
  if (mem is Map<String, dynamic> && mem.isNotEmpty) {
    return mem;
  }

  final disk = await StorageService.getCache('profile');
  if (disk is Map<String, dynamic> && disk.isNotEmpty) {
    return disk;
  }

  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    return {};
  }

  final fresh = await apiService.fetchProfile(
    auth.username!,
    auth.password!,
  );
  await StorageService.setCache('profile', fresh);
  return fresh;
});

/// Grades Provider — returns cached grade history instantly (0ms)
final gradesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final mem = StorageService.getMemoryCache('grades');
  if (mem is Map<String, dynamic> && mem.isNotEmpty) {
    return mem;
  }

  final disk = await StorageService.getCache('grades');
  if (disk is Map<String, dynamic> && disk.isNotEmpty) {
    return disk;
  }

  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    return {};
  }

  final fresh = await apiService.fetchGradeHistory(
    username: auth.username!,
    password: auth.password!,
  );
  await StorageService.setCache('grades', fresh);
  return fresh;
});

/// Exam Schedule Provider — returns cached exam schedule instantly (0ms)
final examScheduleProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final mem = StorageService.getMemoryCache('exam_schedule');
  if (mem is Map<String, dynamic> && mem.isNotEmpty) {
    return mem;
  }

  final disk = await StorageService.getCache('exam_schedule');
  if (disk is Map<String, dynamic> && disk.isNotEmpty) {
    return disk;
  }

  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    return {};
  }

  final semId = auth.activeSemesterId ?? '';
  final fresh = await apiService.fetchExamSchedule(
    username: auth.username!,
    password: auth.password!,
    semSubId: semId,
  );
  await StorageService.setCache('exam_schedule', fresh);
  return fresh;
});
