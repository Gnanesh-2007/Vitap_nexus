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
// SEMESTER RESOLVER HELPER
// ============================================================================

Future<String> _resolveSemesterId(dynamic ref, AuthState auth) async {
  if (auth.activeSemesterId != null && auth.activeSemesterId!.isNotEmpty) {
    return auth.activeSemesterId!;
  }
  final creds = await StorageService.getCredentials();
  if (creds['semesterId'] != null && creds['semesterId']!.isNotEmpty) {
    return creds['semesterId']!;
  }
  if (auth.username != null && auth.password != null) {
    try {
      final semsData = await apiService.fetchSemesters(auth.username!, auth.password!);
      final list = (semsData['semesters'] as List<dynamic>?) ?? [];
      if (list.isNotEmpty && list.first is Map) {
        final first = list.first as Map;
        final id = first['id']?.toString() ?? '';
        final name = first['name']?.toString() ?? id;
        if (id.isNotEmpty) {
          await StorageService.saveSemester(id, name);
          return id;
        }
      }
    } catch (_) {}
  }
  return '';
}

// ============================================================================
// 1. DASHBOARD VIEWMODEL (all_data)
// ============================================================================

class DashboardNotifier extends StateNotifier<VtopDataState<Map<String, dynamic>>> {
  final Ref _ref;

  DashboardNotifier(this._ref) : super(_loadInitialState()) {
    _initFromCache();

    // Listen for auth state & user changes reactively
    _ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.username != next.username || previous?.isAuthenticated != next.isAuthenticated) {
        if (!next.isAuthenticated || next.username == null) {
          reset();
        } else if (next.isAuthenticated) {
          reloadForCurrentUser();
        }
      }
    });
  }

  void reset() {
    state = const VtopDataState(isLoading: false);
  }

  Future<void> reloadForCurrentUser() async {
    final auth = _ref.read(authProvider);
    if (!auth.isAuthenticated || auth.username == null) {
      reset();
      return;
    }

    final memData = StorageService.getMemoryCache('all_data', username: auth.username);
    final memTs = StorageService.getMemoryTimestamp('all_data', username: auth.username);
    if (memData is Map && memData.isNotEmpty) {
      state = VtopDataState(
        data: Map<String, dynamic>.from(memData),
        isLoading: false,
        isSyncing: false,
        lastSynced: memTs,
      );
      return;
    }

    final diskData = await StorageService.getCache('all_data', username: auth.username);
    final diskTs = await StorageService.getLastSynced('all_data', username: auth.username);
    if (diskData is Map && diskData.isNotEmpty) {
      state = VtopDataState(
        data: Map<String, dynamic>.from(diskData),
        isLoading: false,
        isSyncing: false,
        lastSynced: diskTs,
      );
    } else {
      state = const VtopDataState(isLoading: true);
      await syncAll();
    }
  }

  static VtopDataState<Map<String, dynamic>> _loadInitialState() {
    final memData = StorageService.getMemoryCache('all_data');
    final memTs = StorageService.getMemoryTimestamp('all_data');

    if (memData is Map && memData.isNotEmpty) {
      return VtopDataState(
        data: Map<String, dynamic>.from(memData),
        isLoading: false,
        isSyncing: false,
        lastSynced: memTs,
      );
    }
    return const VtopDataState(isLoading: false);
  }

  Future<void> _initFromCache() async {
    final auth = _ref.read(authProvider);
    final currentUser = auth.username ?? StorageService.currentUsername;

    if (!auth.isAuthenticated || currentUser == null) return;

    final memData = StorageService.getMemoryCache('all_data', username: currentUser);
    final memTs = StorageService.getMemoryTimestamp('all_data', username: currentUser);
    if (memData is Map && memData.isNotEmpty) {
      state = VtopDataState(
        data: Map<String, dynamic>.from(memData),
        isLoading: false,
        isSyncing: false,
        lastSynced: memTs,
      );
      return;
    }

    final diskData = await StorageService.getCache('all_data', username: currentUser);
    final diskTs = await StorageService.getLastSynced('all_data', username: currentUser);

    if (diskData is Map && diskData.isNotEmpty) {
      state = VtopDataState(
        data: Map<String, dynamic>.from(diskData),
        isLoading: false,
        isSyncing: false,
        lastSynced: diskTs,
      );
      debugPrint('DashboardViewModel: Loaded from disk cache for $currentUser');
      return;
    }

    // ONLY IF NEVER CACHED BEFORE (FIRST LOGIN), SYNC INITIAL DATA
    if (auth.isAuthenticated && auth.username != null && auth.password != null) {
      state = const VtopDataState(isLoading: true);
      await syncAll();
    }
  }

  Future<void> refresh() => syncAll();

  Future<void> syncAll() async {
    final auth = _ref.read(authProvider);
    if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
      if (!state.hasData) {
        state = const VtopDataState(isLoading: false, error: 'Not authenticated');
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
        final bool otpReq = loginRes['otp_required'] == true;
        if (sid != null && sid.isNotEmpty) {
          apiService.setVtopSessionId(sid);
          if (otpReq) {
            debugPrint('DashboardViewModel: OTP required during sync! Invoking onOtpRequired...');
            ApiClient.onOtpRequired?.call(sid);
            state = VtopDataState(
              data: state.data,
              isLoading: false,
              isSyncing: false,
              error: 'Please verify OTP to sync your data',
              lastSynced: state.lastSynced,
            );
            return;
          }
        }
      }

      final semId = await _resolveSemesterId(_ref, auth);
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

      // Unpack into all sub-caches simultaneously for the current user!
      await StorageService.unpackAllData(fresh, username: auth.username);

      // Also pre-fetch and cache secondary features in background so each and every feature is stored forever
      unawaited(Future.wait([
        apiService.fetchMentor(username: auth.username!, password: auth.password!)
            .then((m) => StorageService.setCache('mentor', m, username: auth.username)).catchError((_) {}),
        apiService.fetchBiometric(
          username: auth.username!,
          password: auth.password!,
          date: '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
        ).then((b) {
          final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          StorageService.setCache('biometric', b, username: auth.username);
          StorageService.setCache('biometric_$dateKey', b, username: auth.username);
        }).catchError((_) {}),
        apiService.fetchPendingPayments(username: auth.username!, password: auth.password!)
            .then((p) => StorageService.setCache('payments', p, username: auth.username)).catchError((_) {}),
        apiService.fetchPaymentReceipts(username: auth.username!, password: auth.password!)
            .then((r) => StorageService.setCache('receipts', r, username: auth.username)).catchError((_) {}),
        if (semId.isNotEmpty) ...[
          apiService.fetchCoursePageCourses(username: auth.username!, password: auth.password!, semSubId: semId)
              .then((c) => StorageService.setCache('courses', c, username: auth.username)).catchError((_) {}),
          apiService.fetchDigitalAssignments(username: auth.username!, password: auth.password!, semSubId: semId)
              .then((a) => StorageService.setCache('assignments', a, username: auth.username)).catchError((_) {}),
          apiService.fetchExamSchedule(username: auth.username!, password: auth.password!, semSubId: semId)
              .then((e) => StorageService.setCache('exam_schedule', e, username: auth.username)).catchError((_) {}),
        ],
      ]));

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

      debugPrint('DashboardViewModel: Full sync complete for ${auth.username} at $now');
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

/// Resets all VTOP providers and clears caches across the entire Riverpod container.
void resetAllVtopProviders(dynamic ref) {
  try {
    if (ref is WidgetRef) {
      ref.read(dashboardProvider.notifier).reset();
      ref.invalidate(dashboardProvider);
      ref.invalidate(allDataProvider);
      ref.invalidate(attendanceProvider);
      ref.invalidate(timetableProvider);
      ref.invalidate(marksProvider);
      ref.invalidate(profileProvider);
      ref.invalidate(gradesProvider);
      ref.invalidate(examScheduleProvider);
    } else if (ref is Ref) {
      ref.read(dashboardProvider.notifier).reset();
      ref.invalidate(dashboardProvider);
      ref.invalidate(allDataProvider);
      ref.invalidate(attendanceProvider);
      ref.invalidate(timetableProvider);
      ref.invalidate(marksProvider);
      ref.invalidate(profileProvider);
      ref.invalidate(gradesProvider);
      ref.invalidate(examScheduleProvider);
    }
  } catch (e) {
    debugPrint('resetAllVtopProviders error: $e');
  }
}

// ============================================================================
// 2. CORE FUTURE PROVIDERS (Instant Memory Cache -> Disk Cache -> Network)
// ============================================================================

/// Dashboard allDataProvider — returns cached all_data instantly (0ms)
final allDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.username ?? StorageService.currentUsername;

  final mem = StorageService.getMemoryCache('all_data', username: user);
  if (mem is Map && mem.isNotEmpty) {
    return Map<String, dynamic>.from(mem);
  }

  final disk = await StorageService.getCache('all_data', username: user);
  if (disk is Map && disk.isNotEmpty) {
    return Map<String, dynamic>.from(disk);
  }

  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    throw Exception('Not authenticated');
  }

  final semId = await _resolveSemesterId(ref, auth);
  final fresh = await apiService.fetchAllData(
    username: auth.username!,
    password: auth.password!,
    semSubId: semId,
  );
  await StorageService.unpackAllData(fresh, username: auth.username);
  return fresh;
});

/// Attendance Provider — returns cached attendance instantly (0ms)
final attendanceProvider = FutureProvider<List<dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.username ?? StorageService.currentUsername;

  final mem = StorageService.getMemoryCache('attendance', username: user);
  if (mem is List && mem.isNotEmpty) {
    return List<dynamic>.from(mem);
  }

  final disk = await StorageService.getCache('attendance', username: user);
  if (disk is List && disk.isNotEmpty) {
    return List<dynamic>.from(disk);
  }

  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    return [];
  }

  try {
    final semId = await _resolveSemesterId(ref, auth);
    final fresh = await apiService.fetchAttendance(
      username: auth.username!,
      password: auth.password!,
      semSubId: semId,
    );
    await StorageService.setCache('attendance', fresh, username: auth.username);
    return fresh;
  } catch (e) {
    debugPrint('attendanceProvider network error (falling back to cache): $e');
    final fallback = await StorageService.getCache('attendance', username: auth.username);
    if (fallback is List && fallback.isNotEmpty) {
      return List<dynamic>.from(fallback);
    }
    rethrow;
  }
});

/// Timetable Provider — returns cached timetable instantly (0ms)
final timetableProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.username ?? StorageService.currentUsername;

  final mem = StorageService.getMemoryCache('timetable', username: user);
  if (mem is Map && mem.isNotEmpty) {
    return Map<String, dynamic>.from(mem);
  }

  final disk = await StorageService.getCache('timetable', username: user);
  if (disk is Map && disk.isNotEmpty) {
    return Map<String, dynamic>.from(disk);
  }

  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    return {};
  }

  try {
    final semId = await _resolveSemesterId(ref, auth);
    final fresh = await apiService.fetchTimetable(
      username: auth.username!,
      password: auth.password!,
      semSubId: semId,
    );
    await StorageService.setCache('timetable', fresh, username: auth.username);
    return fresh;
  } catch (e) {
    debugPrint('timetableProvider network error (falling back to cache): $e');
    final fallback = await StorageService.getCache('timetable', username: auth.username);
    if (fallback is Map && fallback.isNotEmpty) {
      return Map<String, dynamic>.from(fallback);
    }
    rethrow;
  }
});

/// Marks Provider — returns cached marks instantly (0ms)
final marksProvider = FutureProvider<List<dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.username ?? StorageService.currentUsername;

  final mem = StorageService.getMemoryCache('marks', username: user);
  if (mem is List && mem.isNotEmpty) {
    return List<dynamic>.from(mem);
  }

  final disk = await StorageService.getCache('marks', username: user);
  if (disk is List && disk.isNotEmpty) {
    return List<dynamic>.from(disk);
  }

  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    return [];
  }

  try {
    final semId = await _resolveSemesterId(ref, auth);
    final fresh = await apiService.fetchMarks(
      username: auth.username!,
      password: auth.password!,
      semSubId: semId,
    );
    await StorageService.setCache('marks', fresh, username: auth.username);
    return fresh;
  } catch (e) {
    debugPrint('marksProvider network error (falling back to cache): $e');
    final fallback = await StorageService.getCache('marks', username: auth.username);
    if (fallback is List && fallback.isNotEmpty) {
      return List<dynamic>.from(fallback);
    }
    rethrow;
  }
});

/// Profile Provider — returns cached profile instantly (0ms)
final profileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.username ?? StorageService.currentUsername;

  final mem = StorageService.getMemoryCache('profile', username: user);
  if (mem is Map && mem.isNotEmpty) {
    return Map<String, dynamic>.from(mem);
  }

  final disk = await StorageService.getCache('profile', username: user);
  if (disk is Map && disk.isNotEmpty) {
    return Map<String, dynamic>.from(disk);
  }

  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    return {};
  }

  try {
    final fresh = await apiService.fetchProfile(
      auth.username!,
      auth.password!,
    );
    await StorageService.setCache('profile', fresh, username: auth.username);
    return fresh;
  } catch (e) {
    debugPrint('profileProvider network error (falling back to cache): $e');
    final fallback = await StorageService.getCache('profile', username: auth.username);
    if (fallback is Map && fallback.isNotEmpty) {
      return Map<String, dynamic>.from(fallback);
    }
    rethrow;
  }
});

/// Grades Provider — returns cached grade history instantly (0ms)
final gradesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.username ?? StorageService.currentUsername;

  final mem = StorageService.getMemoryCache('grades', username: user);
  if (mem is Map && mem.isNotEmpty) {
    return Map<String, dynamic>.from(mem);
  }

  final disk = await StorageService.getCache('grades', username: user);
  if (disk is Map && disk.isNotEmpty) {
    return Map<String, dynamic>.from(disk);
  }

  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    return {};
  }

  try {
    final fresh = await apiService.fetchGradeHistory(
      username: auth.username!,
      password: auth.password!,
    );
    await StorageService.setCache('grades', fresh, username: auth.username);
    return fresh;
  } catch (e) {
    debugPrint('gradesProvider network error (falling back to cache): $e');
    final fallback = await StorageService.getCache('grades', username: auth.username);
    if (fallback is Map && fallback.isNotEmpty) {
      return Map<String, dynamic>.from(fallback);
    }
    rethrow;
  }
});

/// Exam Schedule Provider — returns cached exam schedule instantly (0ms)
final examScheduleProvider = FutureProvider<List<dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.username ?? StorageService.currentUsername;

  final mem = StorageService.getMemoryCache('exam_schedule', username: user);
  if (mem is List && mem.isNotEmpty) {
    return List<dynamic>.from(mem);
  }

  final disk = await StorageService.getCache('exam_schedule', username: user);
  if (disk is List && disk.isNotEmpty) {
    return List<dynamic>.from(disk);
  }

  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    return [];
  }

  try {
    final semId = await _resolveSemesterId(ref, auth);
    final fresh = await apiService.fetchExamSchedule(
      username: auth.username!,
      password: auth.password!,
      semSubId: semId,
    );
    final result = fresh is List ? fresh : <dynamic>[];
    await StorageService.setCache('exam_schedule', result, username: auth.username);
    return List<dynamic>.from(result);
  } catch (e) {
    debugPrint('examScheduleProvider network error (falling back to cache): $e');
    final fallback = await StorageService.getCache('exam_schedule', username: auth.username);
    if (fallback is List && fallback.isNotEmpty) {
      return List<dynamic>.from(fallback);
    }
    rethrow;
  }
});

// ============================================================================
// 3. SINGLE-FEATURE REFRESH FUNCTIONS (PULL-TO-REFRESH)
// Only fetches latest data for the specific screen/feature
// ============================================================================

/// Forces a network fetch for ONLY attendance data, updating cache & UI
Future<List<dynamic>> refreshAttendance(dynamic ref) async {
  final AuthState auth = (ref is WidgetRef ? ref.read(authProvider) : (ref as Ref).read(authProvider));
  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    throw Exception('Not authenticated');
  }
  final semId = await _resolveSemesterId(ref, auth);
  final fresh = await apiService.fetchAttendance(
    username: auth.username!,
    password: auth.password!,
    semSubId: semId,
  );
  await StorageService.setCache('attendance', fresh);
  if (ref is WidgetRef) {
    ref.invalidate(attendanceProvider);
  } else if (ref is Ref) {
    ref.invalidate(attendanceProvider);
  }
  return fresh;
}

/// Forces a network fetch for ONLY marks data, updating cache & UI
Future<List<dynamic>> refreshMarks(dynamic ref) async {
  final AuthState auth = (ref is WidgetRef ? ref.read(authProvider) : (ref as Ref).read(authProvider));
  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    throw Exception('Not authenticated');
  }
  final semId = await _resolveSemesterId(ref, auth);
  final fresh = await apiService.fetchMarks(
    username: auth.username!,
    password: auth.password!,
    semSubId: semId,
  );
  await StorageService.setCache('marks', fresh);
  if (ref is WidgetRef) {
    ref.invalidate(marksProvider);
  } else if (ref is Ref) {
    ref.invalidate(marksProvider);
  }
  return fresh;
}

/// Forces a network fetch for ONLY exam schedule data, updating cache & UI
Future<List<dynamic>> refreshExamSchedule(dynamic ref) async {
  final AuthState auth = (ref is WidgetRef ? ref.read(authProvider) : (ref as Ref).read(authProvider));
  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    throw Exception('Not authenticated');
  }
  final semId = await _resolveSemesterId(ref, auth);
  final fresh = await apiService.fetchExamSchedule(
    username: auth.username!,
    password: auth.password!,
    semSubId: semId,
  );
  final result = fresh is List ? fresh : <dynamic>[];
  await StorageService.setCache('exam_schedule', result);
  if (ref is WidgetRef) {
    ref.invalidate(examScheduleProvider);
  } else if (ref is Ref) {
    ref.invalidate(examScheduleProvider);
  }
  return result;
}

/// Forces a network fetch for ONLY timetable data, updating cache & UI
Future<Map<String, dynamic>> refreshTimetable(dynamic ref) async {
  final AuthState auth = (ref is WidgetRef ? ref.read(authProvider) : (ref as Ref).read(authProvider));
  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    throw Exception('Not authenticated');
  }
  final semId = await _resolveSemesterId(ref, auth);
  final fresh = await apiService.fetchTimetable(
    username: auth.username!,
    password: auth.password!,
    semSubId: semId,
  );
  await StorageService.setCache('timetable', fresh);
  if (ref is WidgetRef) {
    ref.invalidate(timetableProvider);
  } else if (ref is Ref) {
    ref.invalidate(timetableProvider);
  }
  return fresh;
}

/// Fetches per-course day-wise attendance detail with cache support (0ms if cached)
Future<List<dynamic>> getAttendanceDetail({
  required dynamic ref,
  required String courseId,
  required String courseType,
  bool forceRefresh = false,
}) async {
  final cacheKey = 'att_detail_${courseId}_$courseType';
  if (!forceRefresh) {
    final mem = StorageService.getMemoryCache(cacheKey);
    if (mem is List && mem.isNotEmpty) {
      return List<dynamic>.from(mem);
    }
    final disk = await StorageService.getCache(cacheKey);
    if (disk is List && disk.isNotEmpty) {
      return List<dynamic>.from(disk);
    }
  }

  final AuthState auth = (ref is WidgetRef ? ref.read(authProvider) : (ref as Ref).read(authProvider));
  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    throw Exception('Not authenticated');
  }

  final semId = await _resolveSemesterId(ref, auth);
  final fresh = await apiService.fetchAttendanceDetail(
    username: auth.username!,
    password: auth.password!,
    semSubId: semId,
    courseId: courseId,
    courseType: courseType,
  );
  await StorageService.setCache(cacheKey, fresh);
  return fresh;
}
