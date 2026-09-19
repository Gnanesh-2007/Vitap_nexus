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
    _initFromCache();
  }

  Future<void> _initFromCache() async {
    // ── STEP 1: INSTANT MEMORY CACHE (0 ms) ─────────────────────────────────
    final memData = StorageService.getMemoryCache('all_data');
    final memTs = StorageService.getMemoryTimestamp('all_data');

    if (memData is Map<String, dynamic> && memData.isNotEmpty) {
      state = VtopDataState(
        data: memData,
        isLoading: false,
        isSyncing: false,
        lastSynced: memTs,
      );
      debugPrint('DashboardViewModel: Loaded from memory cache in 0ms (no auto-sync on reopen)');
      return;
    }

    // ── STEP 2: FAST DISK CACHE (< 10 ms) ─────────────────────────────────
    final diskData = await StorageService.getCache('all_data');
    final diskTs = await StorageService.getLastSynced('all_data');

    if (diskData is Map<String, dynamic> && diskData.isNotEmpty) {
      state = VtopDataState(
        data: diskData,
        isLoading: false,
        isSyncing: false,
        lastSynced: diskTs,
      );
      debugPrint('DashboardViewModel: Loaded from disk cache in <10ms (no auto-sync on reopen)');
      return;
    }

    // ── STEP 3: ONLY IF NEVER CACHED BEFORE (FIRST LOGIN), SYNC INITIAL DATA
    await syncAll();
  }

  Future<void> refresh() => syncAll();

  Future<void> syncAll() async {
    final auth = _ref.read(authProvider);
    if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
      if (!state.hasData) {
        state = VtopDataState(isLoading: false, error: 'Not authenticated');
      }
      return;
    }

    state = VtopDataState(
      data: state.data,
      isLoading: !state.hasData,
      isSyncing: true,
      lastSynced: state.lastSynced,
    );

    try {
      // 1. Ensure VTOP session is established
      if (apiService.vtopSessionId == null) {
        debugPrint('DashboardViewModel: Establishing VTOP session...');
        final loginRes = await apiService.initiateLogin(
          username: auth.username!,
          password: auth.password!,
        );
        final sid = loginRes['session_id']?.toString();
        if (sid != null && sid.isNotEmpty) {
          apiService.setVtopSessionId(sid);
        }
      }

      final semId = auth.activeSemesterId ?? '';
      Map<String, dynamic> fresh;

      try {
        fresh = await apiService.fetchAllData(
          username: auth.username!,
          password: auth.password!,
          semSubId: semId,
        );
      } catch (allDataErr) {
        debugPrint('DashboardViewModel: fetchAllData failed ($allDataErr), falling back to individual endpoints...');
        
        final results = await Future.wait([
          apiService.fetchProfile(auth.username!, auth.password!).catchError((e) => <String, dynamic>{}),
          apiService.fetchTimetable(username: auth.username!, password: auth.password!, semSubId: semId).catchError((e) => <String, dynamic>{}),
          apiService.fetchAttendance(username: auth.username!, password: auth.password!, semSubId: semId).catchError((e) => <dynamic>[]),
          apiService.fetchMarks(username: auth.username!, password: auth.password!, semSubId: semId).catchError((e) => <dynamic>[]),
          apiService.fetchGradeHistory(username: auth.username!, password: auth.password!).catchError((e) => <String, dynamic>{}),
        ]);

        fresh = {
          'profile': results[0] as Map<String, dynamic>,
          'timetable': results[1] as Map<String, dynamic>,
          'attendance': results[2] as List<dynamic>,
          'marks': results[3] as List<dynamic>,
          'grade_history': results[4] as Map<String, dynamic>,
        };
      }

      final now = DateTime.now();

      // Unpack into all sub-caches simultaneously!
      await StorageService.unpackAllData(fresh);

      state = VtopDataState(
        data: fresh,
        isLoading: false,
        isSyncing: false,
        lastSynced: now,
      );

      // Refresh child FutureProviders so screens update with new synced data
      _ref.invalidate(attendanceProvider);
      _ref.invalidate(timetableProvider);
      _ref.invalidate(marksProvider);
      _ref.invalidate(profileProvider);
      _ref.invalidate(gradesProvider);
      _ref.invalidate(examScheduleProvider);

      debugPrint('DashboardViewModel: Full sync complete and all sub-caches updated at $now');
    } catch (e) {
      debugPrint('DashboardViewModel: Sync error (retaining local data): $e');
      state = VtopDataState(
        data: state.data,
        isSyncing: false,
        isLoading: false,
        error: state.hasData ? null : 'Could not sync data from VTOP.',
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

  try {
    final semId = auth.activeSemesterId ?? '';
    final fresh = await apiService.fetchAttendance(
      username: auth.username!,
      password: auth.password!,
      semSubId: semId,
    );
    await StorageService.setCache('attendance', fresh);
    return fresh;
  } catch (e) {
    debugPrint('attendanceProvider network error (falling back to cache): $e');
    final fallback = await StorageService.getCache('attendance');
    if (fallback is List && fallback.isNotEmpty) {
      return fallback;
    }
    rethrow;
  }
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

  try {
    final semId = auth.activeSemesterId ?? '';
    final fresh = await apiService.fetchTimetable(
      username: auth.username!,
      password: auth.password!,
      semSubId: semId,
    );
    await StorageService.setCache('timetable', fresh);
    return fresh;
  } catch (e) {
    debugPrint('timetableProvider network error (falling back to cache): $e');
    final fallback = await StorageService.getCache('timetable');
    if (fallback is Map<String, dynamic> && fallback.isNotEmpty) {
      return fallback;
    }
    rethrow;
  }
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

  try {
    final semId = auth.activeSemesterId ?? '';
    final fresh = await apiService.fetchMarks(
      username: auth.username!,
      password: auth.password!,
      semSubId: semId,
    );
    await StorageService.setCache('marks', fresh);
    return fresh;
  } catch (e) {
    debugPrint('marksProvider network error (falling back to cache): $e');
    final fallback = await StorageService.getCache('marks');
    if (fallback is List && fallback.isNotEmpty) {
      return fallback;
    }
    rethrow;
  }
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

  try {
    final fresh = await apiService.fetchProfile(
      auth.username!,
      auth.password!,
    );
    await StorageService.setCache('profile', fresh);
    return fresh;
  } catch (e) {
    debugPrint('profileProvider network error (falling back to cache): $e');
    final fallback = await StorageService.getCache('profile');
    if (fallback is Map<String, dynamic> && fallback.isNotEmpty) {
      return fallback;
    }
    rethrow;
  }
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

  try {
    final fresh = await apiService.fetchGradeHistory(
      username: auth.username!,
      password: auth.password!,
    );
    await StorageService.setCache('grades', fresh);
    return fresh;
  } catch (e) {
    debugPrint('gradesProvider network error (falling back to cache): $e');
    final fallback = await StorageService.getCache('grades');
    if (fallback is Map<String, dynamic> && fallback.isNotEmpty) {
      return fallback;
    }
    rethrow;
  }
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

  try {
    final semId = auth.activeSemesterId ?? '';
    final fresh = await apiService.fetchExamSchedule(
      username: auth.username!,
      password: auth.password!,
      semSubId: semId,
    );
    await StorageService.setCache('exam_schedule', fresh);
    return fresh;
  } catch (e) {
    debugPrint('examScheduleProvider network error (falling back to cache): $e');
    final fallback = await StorageService.getCache('exam_schedule');
    if (fallback is Map<String, dynamic> && fallback.isNotEmpty) {
      return fallback;
    }
    rethrow;
  }
});
