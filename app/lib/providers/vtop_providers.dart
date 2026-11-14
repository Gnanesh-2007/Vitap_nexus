import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../utils/error_formatter.dart';
import 'auth_provider.dart';

// ============================================================================
// MVVM STATE MODEL (Offline-First / Stale-While-Revalidate / Sync State Machine)
// ============================================================================

enum SyncStatus {
  idle,
  loading,
  refreshing,
  success,
  stale,
  offline,
  error,
  authenticationRequired,
}

class VtopDataState<T> {
  final T? data;
  final SyncStatus syncStatus;
  final bool isLoading;
  final bool isSyncing;
  final String? error;
  final DateTime? lastSynced;
  final int syncEpoch;

  const VtopDataState({
    this.data,
    this.syncStatus = SyncStatus.idle,
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.lastSynced,
    this.syncEpoch = 0,
  });

  bool get hasData => data != null;
  bool get hasError => error != null && error!.isNotEmpty;
  bool get isOffline => syncStatus == SyncStatus.offline;
  bool get isStale => syncStatus == SyncStatus.stale;
  bool get isAuthRequired => syncStatus == SyncStatus.authenticationRequired;
  T? get value => data;

  VtopDataState<T> copyWith({
    T? data,
    SyncStatus? syncStatus,
    bool? isLoading,
    bool? isSyncing,
    String? error,
    DateTime? lastSynced,
    int? syncEpoch,
  }) {
    return VtopDataState<T>(
      data: data ?? this.data,
      syncStatus: syncStatus ?? this.syncStatus,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error,
      lastSynced: lastSynced ?? this.lastSynced,
      syncEpoch: syncEpoch ?? this.syncEpoch,
    );
  }

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
// SEMESTER RESOLVER HELPER (DEDUPLICATED)
// ============================================================================

Future<String>? _activeSemesterResolution;

Future<String> _resolveSemesterId(dynamic ref, AuthState auth) async {
  if (auth.activeSemesterId != null && auth.activeSemesterId!.isNotEmpty) {
    return auth.activeSemesterId!;
  }
  final creds = await StorageService.getCredentials();
  if (creds['semesterId'] != null && creds['semesterId']!.isNotEmpty) {
    return creds['semesterId']!;
  }
  if (auth.username != null && auth.password != null) {
    if (_activeSemesterResolution != null) {
      return _activeSemesterResolution!;
    }
    final future = _performSemesterResolution(auth);
    _activeSemesterResolution = future;
    future.whenComplete(() => _activeSemesterResolution = null);
    return future;
  }
  return '';
}

Future<String> _performSemesterResolution(AuthState auth) async {
  try {
    final semsData = await apiService.fetchSemesters(auth.username!, auth.password!);
    final list = (semsData['semesters'] as List<dynamic>?) ?? [];
    if (list.isNotEmpty && list.first is Map) {
      final first = list.first as Map;
      final id = first['id']?.toString() ?? '';
      final name = first['name']?.toString() ?? id;
      if (id.isNotEmpty) {
        await StorageService.saveSemester(id, name, username: auth.username);
        return id;
      }
    }
  } catch (_) {}
  return '';
}

// ============================================================================
// 1. DASHBOARD VIEWMODEL (all_data)
// ============================================================================

class DashboardNotifier extends StateNotifier<VtopDataState<Map<String, dynamic>>> {
  final Ref _ref;
  int _currentEpoch = 0;

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
      } else if (previous?.activeSemesterId != next.activeSemesterId && next.activeSemesterId != null) {
        // Active semester changed: load semester cache and automatically sync to that semester
        _currentEpoch++;
        reloadForCurrentUser(forceSync: true);
      }
    });
  }

  void reset() {
    _currentEpoch++;
    state = const VtopDataState(isLoading: false, syncStatus: SyncStatus.idle);
  }

  static Map<String, dynamic>? _getCompositeFromMemory({String? username, String? semesterId}) {
    final all = StorageService.getMemoryCache('all_data', username: username, semesterId: semesterId) ??
        StorageService.getMemoryCache('all_data', username: username);
    if (all is Map && all.isNotEmpty) {
      return Map<String, dynamic>.from(all);
    }

    final composite = <String, dynamic>{};
    final profile = StorageService.getMemoryCache('profile', username: username);
    if (profile is Map && profile.isNotEmpty) composite['profile'] = profile;

    final timetable = StorageService.getMemoryCache('timetable', username: username, semesterId: semesterId) ??
        StorageService.getMemoryCache('timetable', username: username);
    if (timetable != null) composite['timetable'] = timetable;

    final attendance = StorageService.getMemoryCache('attendance', username: username, semesterId: semesterId) ??
        StorageService.getMemoryCache('attendance', username: username);
    if (attendance != null) composite['attendance'] = attendance;

    final marks = StorageService.getMemoryCache('marks', username: username, semesterId: semesterId) ??
        StorageService.getMemoryCache('marks', username: username);
    if (marks != null) composite['marks'] = marks;

    final grades = StorageService.getMemoryCache('grades', username: username, semesterId: semesterId) ??
        StorageService.getMemoryCache('grades', username: username);
    if (grades != null) composite['grade_history'] = grades;

    final exam = StorageService.getMemoryCache('exam_schedule', username: username, semesterId: semesterId) ??
        StorageService.getMemoryCache('exam_schedule', username: username);
    if (exam != null) composite['exam_schedule'] = exam;

    return composite.isNotEmpty ? composite : null;
  }

  static Future<Map<String, dynamic>?> _getCompositeFromDisk({String? username, String? semesterId}) async {
    final all = await StorageService.getCache('all_data', username: username, semesterId: semesterId) ??
        await StorageService.getCache('all_data', username: username);
    if (all is Map && all.isNotEmpty) {
      return Map<String, dynamic>.from(all);
    }

    final composite = <String, dynamic>{};
    final profile = await StorageService.getCache('profile', username: username);
    if (profile is Map && profile.isNotEmpty) composite['profile'] = profile;

    final timetable = await StorageService.getCache('timetable', username: username, semesterId: semesterId) ??
        await StorageService.getCache('timetable', username: username);
    if (timetable != null) composite['timetable'] = timetable;

    final attendance = await StorageService.getCache('attendance', username: username, semesterId: semesterId) ??
        await StorageService.getCache('attendance', username: username);
    if (attendance != null) composite['attendance'] = attendance;

    final marks = await StorageService.getCache('marks', username: username, semesterId: semesterId) ??
        await StorageService.getCache('marks', username: username);
    if (marks != null) composite['marks'] = marks;

    final grades = await StorageService.getCache('grades', username: username, semesterId: semesterId) ??
        await StorageService.getCache('grades', username: username);
    if (grades != null) composite['grade_history'] = grades;

    final exam = await StorageService.getCache('exam_schedule', username: username, semesterId: semesterId) ??
        await StorageService.getCache('exam_schedule', username: username);
    if (exam != null) composite['exam_schedule'] = exam;

    return composite.isNotEmpty ? composite : null;
  }

  Future<void> reloadForCurrentUser({bool forceSync = false}) async {
    final auth = _ref.read(authProvider);
    if (!auth.isAuthenticated || auth.username == null) {
      reset();
      return;
    }

    final semId = auth.activeSemesterId;
    final epoch = ++_currentEpoch;

    // 1. Instant check in memory
    final memComposite = _getCompositeFromMemory(username: auth.username, semesterId: semId);
    final memTs = StorageService.getMemoryTimestamp('all_data', username: auth.username, semesterId: semId);
    if (memComposite != null && memComposite.isNotEmpty) {
      final isStale = StorageService.isFeatureStale('all_data', user: auth.username, semesterId: semId);
      state = VtopDataState(
        data: memComposite,
        syncStatus: isStale ? SyncStatus.stale : SyncStatus.success,
        isLoading: false,
        isSyncing: forceSync,
        lastSynced: memTs,
        syncEpoch: epoch,
      );
      if (forceSync) {
        unawaited(syncAll(isUserInitiated: true));
      } else if (isStale) {
        unawaited(syncAll(isUserInitiated: false));
      }
      return;
    }

    // 2. Fallback to disk cache
    final diskComposite = await _getCompositeFromDisk(username: auth.username, semesterId: semId);
    final diskTs = await StorageService.getLastSynced('all_data', username: auth.username, semesterId: semId);
    if (diskComposite != null && diskComposite.isNotEmpty) {
      final isStale = StorageService.isFeatureStale('all_data', user: auth.username, semesterId: semId);
      state = VtopDataState(
        data: diskComposite,
        syncStatus: isStale ? SyncStatus.stale : SyncStatus.success,
        isLoading: false,
        isSyncing: forceSync,
        lastSynced: diskTs,
        syncEpoch: epoch,
      );
      if (forceSync) {
        unawaited(syncAll(isUserInitiated: true));
      } else if (isStale) {
        unawaited(syncAll(isUserInitiated: false));
      }
    } else {
      // No cached data on device: initial network sync
      state = VtopDataState(isLoading: true, syncStatus: SyncStatus.loading, syncEpoch: epoch);
      await syncAll(isUserInitiated: true);
    }
  }

  static VtopDataState<Map<String, dynamic>> _loadInitialState() {
    final composite = _getCompositeFromMemory();
    final memTs = StorageService.getMemoryTimestamp('all_data');

    if (composite != null && composite.isNotEmpty) {
      return VtopDataState(
        data: composite,
        syncStatus: SyncStatus.success,
        isLoading: false,
        isSyncing: false,
        lastSynced: memTs,
      );
    }
    return const VtopDataState(isLoading: false, syncStatus: SyncStatus.idle);
  }

  Future<void> _initFromCache() async {
    final auth = _ref.read(authProvider);
    final currentUser = auth.username ?? StorageService.currentUsername;
    final semId = auth.activeSemesterId;

    if (!auth.isAuthenticated || currentUser == null) return;

    final memComposite = _getCompositeFromMemory(username: currentUser, semesterId: semId);
    final memTs = StorageService.getMemoryTimestamp('all_data', username: currentUser, semesterId: semId);
    if (memComposite != null && memComposite.isNotEmpty) {
      final isStale = StorageService.isFeatureStale('all_data', user: currentUser, semesterId: semId);
      state = VtopDataState(
        data: memComposite,
        syncStatus: isStale ? SyncStatus.stale : SyncStatus.success,
        isLoading: false,
        isSyncing: false,
        lastSynced: memTs,
      );
      if (isStale) {
        unawaited(syncAll(isUserInitiated: false));
      }
      return;
    }

    final diskComposite = await _getCompositeFromDisk(username: currentUser, semesterId: semId);
    final diskTs = await StorageService.getLastSynced('all_data', username: currentUser, semesterId: semId);

    if (diskComposite != null && diskComposite.isNotEmpty) {
      final isStale = StorageService.isFeatureStale('all_data', user: currentUser, semesterId: semId);
      state = VtopDataState(
        data: diskComposite,
        syncStatus: isStale ? SyncStatus.stale : SyncStatus.success,
        isLoading: false,
        isSyncing: false,
        lastSynced: diskTs,
      );
      debugPrint('DashboardViewModel: Loaded from disk cache for $currentUser');
      if (isStale) {
        unawaited(syncAll(isUserInitiated: false));
      }
      return;
    }

    // First login / fresh cache: sync
    if (auth.isAuthenticated && auth.username != null && auth.password != null) {
      state = const VtopDataState(isLoading: true, syncStatus: SyncStatus.loading);
      await syncAll(isUserInitiated: true);
    }
  }

  Future<void> refresh() => syncAll(isUserInitiated: true);

  Future<bool> _establishVtopSession(AuthState auth, int requestEpoch) async {
    debugPrint('DashboardViewModel: Establishing VTOP session via single-flight ensureSession...');
    final ok = await apiService.ensureSession(auth.username!, auth.password!);
    if (!ok) {
      state = VtopDataState(
        data: state.data,
        syncStatus: SyncStatus.authenticationRequired,
        isLoading: false,
        isSyncing: false,
        error: 'Please verify OTP to sync your data',
        lastSynced: state.lastSynced,
        syncEpoch: requestEpoch,
      );
      return false;
    }
    return true;
  }

  Future<void> _warmUpSecondaryFeatures(
    AuthState auth,
    String semId,
    DateTime now,
  ) async {
    final username = auth.username;
    final password = auth.password;
    if (username == null || password == null) return;

    try {
      // Batch 1: Core student info (Mentor, Payments, Outings)
      await Future.wait([
        apiService
            .fetchMentor(username: username, password: password)
            .then((m) => StorageService.setCache('mentor', m, username: username))
            .catchError((_) {}),
        apiService
            .fetchPendingPayments(username: username, password: password)
            .then((p) => StorageService.setCache('payments', p, username: username))
            .catchError((_) {}),
        apiService
            .fetchPaymentReceipts(username: username, password: password)
            .then((r) => StorageService.setCache('receipts', r, username: username))
            .catchError((_) {}),
      ]);

      // Batch 2: Biometric & Outings
      final dateStr =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      final dateKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await Future.wait([
        apiService
            .fetchBiometric(username: username, password: password, date: dateStr)
            .then((b) {
              StorageService.setCache('biometric', b, username: username);
              StorageService.setCache('biometric_$dateKey', b, username: username);
            })
            .catchError((_) {}),
        apiService
            .fetchGeneralOutings(username: username, password: password)
            .then((o) {
              StorageService.setCache('outings', o, username: username);
              StorageService.setCache('general_outings', o, username: username);
            })
            .catchError((_) {}),
        apiService
            .fetchWeekendOutings(username: username, password: password)
            .then((w) => StorageService.setCache('weekend_outings', w, username: username))
            .catchError((_) {}),
      ]);

      // Batch 3: Semester-scoped courses & digital assignments
      if (semId.isNotEmpty) {
        await Future.wait([
          apiService
              .fetchCoursePageCourses(username: username, password: password, semSubId: semId)
              .then((c) => StorageService.setCache('courses', c, username: username, semesterId: semId))
              .catchError((_) {}),
          apiService
              .fetchDigitalAssignments(username: username, password: password, semSubId: semId)
              .then((a) => StorageService.setCache('assignments', a, username: username, semesterId: semId))
              .catchError((_) {}),
        ]);

        // Only fetch Academic Calendar if not already permanently cached for this semester
        final existingCal = await StorageService.getCache(
          'academic_calendar_permanent',
          username: username,
          semesterId: semId,
        );
        if (existingCal == null || (existingCal is Map && existingCal.isEmpty)) {
          await apiService
              .fetchAcademicCalendar(username: username, password: password, semSubId: semId)
              .then((cal) {
                if (cal.isNotEmpty) {
                  StorageService.setCache('calendar', cal, username: username, semesterId: semId);
                  StorageService.setCache('academic_calendar', cal, username: username, semesterId: semId);
                  StorageService.setCache('academic_calendar_permanent', cal, username: username, semesterId: semId);
                }
              })
              .catchError((_) {});
        }
      }

      // Batch 4: Permanent Faculty Directory (only if not already permanently cached)
      final existingFaculty = await StorageService.getCache('faculty_permanent', username: username) ??
          await StorageService.getCache('faculty_permanent', username: 'GLOBAL');
      if (existingFaculty == null || (existingFaculty is List && existingFaculty.isEmpty)) {
        await apiService
            .fetchAllFaculty(username: username, password: password)
            .then((f) {
              if (f.isNotEmpty) {
                StorageService.setCache('faculty', f, username: username);
                StorageService.setCache('faculty_directory', f, username: username);
                StorageService.setCache('faculty_permanent', f, username: username);
                StorageService.setCache('faculty_permanent', f, username: 'GLOBAL');
              }
            })
            .catchError((_) {});
      }
    } catch (e) {
      debugPrint('DashboardViewModel: Secondary warm-up note: $e');
    }
  }

  Future<void> syncAll({bool isUserInitiated = false}) async {
    final auth = _ref.read(authProvider);
    if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
      if (!state.hasData) {
        state = const VtopDataState(
          isLoading: false,
          syncStatus: SyncStatus.authenticationRequired,
          error: 'Not authenticated',
        );
      }
      return;
    }

    if (isUserInitiated) {
      apiService.clearDataCache();
    }

    final requestEpoch = _currentEpoch;

    state = VtopDataState(
      data: state.data,
      syncStatus: state.hasData ? SyncStatus.refreshing : SyncStatus.loading,
      isLoading: !state.hasData,
      isSyncing: true,
      lastSynced: state.lastSynced,
      syncEpoch: requestEpoch,
    );

    try {
      final ok = await _establishVtopSession(auth, requestEpoch);
      if (!ok) {
        if (!isUserInitiated && state.hasData) {
          state = VtopDataState(
            data: state.data,
            syncStatus: SyncStatus.stale,
            isLoading: false,
            isSyncing: false,
            lastSynced: state.lastSynced,
            syncEpoch: requestEpoch,
          );
        }
        return;
      }

      final semId = await _resolveSemesterId(_ref, auth);
      final Map<String, dynamic> fresh = await apiService.fetchAllData(
        username: auth.username!,
        password: auth.password!,
        semSubId: semId,
      );

      // Race condition guard: ignore if epoch changed during sync
      if (requestEpoch != _currentEpoch) {
        debugPrint('DashboardViewModel: Discarded stale sync result for older epoch');
        return;
      }

      final now = DateTime.now();

      // Unpack into user + semester sub-caches
      await StorageService.unpackAllData(fresh, username: auth.username, semesterId: semId);

      final mergedData = StorageService.getMemoryCache(
        'all_data',
        username: auth.username,
        semesterId: semId,
      );
      final finalData = mergedData is Map
          ? Map<String, dynamic>.from(mergedData)
          : fresh;

      state = VtopDataState(
        data: finalData,
        syncStatus: SyncStatus.success,
        isLoading: false,
        isSyncing: false,
        lastSynced: now,
        syncEpoch: requestEpoch,
      );

      // Invalidate feature providers immediately so UI updates right away
      _ref.invalidate(allDataProvider);
      _ref.invalidate(attendanceProvider);
      _ref.invalidate(timetableProvider);
      _ref.invalidate(marksProvider);
      _ref.invalidate(profileProvider);
      _ref.invalidate(gradesProvider);
      _ref.invalidate(examScheduleProvider);

      debugPrint('DashboardViewModel: Full sync complete for ${auth.username} (sem: $semId)');

      // Pre-fetch and cache secondary features in controlled background batches
      unawaited(_warmUpSecondaryFeatures(auth, semId, now));
    } catch (e) {
      debugPrint('DashboardViewModel: Sync error (retaining local data): $e');
      final errLower = e.toString().toLowerCase();
      final isOffline = errLower.contains('socketexception') ||
          errLower.contains('handshakeexception') ||
          errLower.contains('connectiontimeout') ||
          errLower.contains('network unreachable') ||
          errLower.contains('too long to respond');

      state = VtopDataState(
        data: state.data,
        syncStatus: isOffline ? SyncStatus.offline : SyncStatus.error,
        isSyncing: false,
        isLoading: false,
        error: isUserInitiated
            ? ErrorFormatter.format(e, fallback: 'Could not sync data from VTOP.')
            : (state.hasData ? null : ErrorFormatter.format(e, fallback: 'Could not sync data from VTOP.')),
        lastSynced: state.lastSynced,
        syncEpoch: requestEpoch,
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
  final semId = auth.activeSemesterId;

  final mem = StorageService.getMemoryCache('all_data', username: user, semesterId: semId);
  if (mem is Map && mem.isNotEmpty) {
    return Map<String, dynamic>.from(mem);
  }

  final disk = await StorageService.getCache('all_data', username: user, semesterId: semId);
  if (disk is Map && disk.isNotEmpty) {
    return Map<String, dynamic>.from(disk);
  }

  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    throw Exception('Please log in to view your dashboard data.');
  }

  try {
    final resolvedSem = semId ?? await _resolveSemesterId(ref, auth);
    final fresh = await apiService.fetchAllData(
      username: auth.username!,
      password: auth.password!,
      semSubId: resolvedSem,
    );
    await StorageService.unpackAllData(fresh, username: auth.username, semesterId: resolvedSem);
    return fresh;
  } catch (e) {
    final fallback = await StorageService.getCache('all_data', username: auth.username, semesterId: semId) ??
        await StorageService.getCache('all_data', username: auth.username);
    if (fallback is Map && fallback.isNotEmpty) {
      return Map<String, dynamic>.from(fallback);
    }
    throw Exception(ErrorFormatter.format(e, fallback: 'Could not connect to VTOP.'));
  }
});

/// Attendance Provider — returns cached attendance instantly (0ms)
final attendanceProvider = FutureProvider<List<dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.username ?? StorageService.currentUsername;
  final semId = auth.activeSemesterId;

  // 1. Direct memory cache
  final mem = StorageService.getMemoryCache('attendance', username: user, semesterId: semId) ??
      StorageService.getMemoryCache('attendance', username: user);
  if (mem is List && mem.isNotEmpty) {
    return List<dynamic>.from(mem);
  }

  // 2. Direct disk cache
  final disk = await StorageService.getCache('attendance', username: user, semesterId: semId) ??
      await StorageService.getCache('attendance', username: user);
  if (disk is List && disk.isNotEmpty) {
    return List<dynamic>.from(disk);
  }

  // 3. Fallback to all_data cache
  final allData = await StorageService.getCache('all_data', username: user, semesterId: semId) ??
      await StorageService.getCache('all_data', username: user);
  if (allData is Map && allData['attendance'] is List && (allData['attendance'] as List).isNotEmpty) {
    final list = List<dynamic>.from(allData['attendance']);
    await StorageService.setCache('attendance', list, username: user, semesterId: semId);
    return list;
  }

  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    return [];
  }

  try {
    final resolvedSem = semId ?? await _resolveSemesterId(ref, auth);
    final fresh = await apiService.fetchAttendance(
      username: auth.username!,
      password: auth.password!,
      semSubId: resolvedSem,
    );
    await StorageService.setCache('attendance', fresh, username: auth.username, semesterId: resolvedSem);
    return fresh;
  } catch (e) {
    debugPrint('attendanceProvider network error (falling back to cache): $e');
    final fallback = await StorageService.getCache('attendance', username: auth.username, semesterId: semId) ??
        await StorageService.getCache('attendance', username: auth.username);
    if (fallback is List && fallback.isNotEmpty) {
      return List<dynamic>.from(fallback);
    }
    final allFallback = await StorageService.getCache('all_data', username: auth.username, semesterId: semId) ??
        await StorageService.getCache('all_data', username: auth.username);
    if (allFallback is Map && allFallback['attendance'] is List && (allFallback['attendance'] as List).isNotEmpty) {
      return List<dynamic>.from(allFallback['attendance']);
    }
    throw Exception(ErrorFormatter.format(e, fallback: 'Could not load attendance. Please check your connection.'));
  }
});

/// Timetable Provider — returns cached timetable instantly (0ms)
final timetableProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.username ?? StorageService.currentUsername;
  final semId = auth.activeSemesterId;

  final mem = StorageService.getMemoryCache('timetable', username: user, semesterId: semId) ??
      StorageService.getMemoryCache('timetable', username: user);
  if (mem is Map && mem.isNotEmpty) {
    return Map<String, dynamic>.from(mem);
  }

  final disk = await StorageService.getCache('timetable', username: user, semesterId: semId) ??
      await StorageService.getCache('timetable', username: user);
  if (disk is Map && disk.isNotEmpty) {
    return Map<String, dynamic>.from(disk);
  }

  final allData = await StorageService.getCache('all_data', username: user, semesterId: semId) ??
      await StorageService.getCache('all_data', username: user);
  if (allData is Map && allData['timetable'] is Map && (allData['timetable'] as Map).isNotEmpty) {
    final map = Map<String, dynamic>.from(allData['timetable']);
    await StorageService.setCache('timetable', map, username: user, semesterId: semId);
    return map;
  }

  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    return {};
  }

  try {
    final resolvedSem = semId ?? await _resolveSemesterId(ref, auth);
    final fresh = await apiService.fetchTimetable(
      username: auth.username!,
      password: auth.password!,
      semSubId: resolvedSem,
    );
    await StorageService.setCache('timetable', fresh, username: auth.username, semesterId: resolvedSem);
    return fresh;
  } catch (e) {
    debugPrint('timetableProvider network error (falling back to cache): $e');
    final fallback = await StorageService.getCache('timetable', username: auth.username, semesterId: semId) ??
        await StorageService.getCache('timetable', username: auth.username);
    if (fallback is Map && fallback.isNotEmpty) {
      return Map<String, dynamic>.from(fallback);
    }
    final allFallback = await StorageService.getCache('all_data', username: auth.username, semesterId: semId) ??
        await StorageService.getCache('all_data', username: auth.username);
    if (allFallback is Map && allFallback['timetable'] is Map && (allFallback['timetable'] as Map).isNotEmpty) {
      return Map<String, dynamic>.from(allFallback['timetable']);
    }
    throw Exception(ErrorFormatter.format(e, fallback: 'Could not load timetable. Please check your connection.'));
  }
});

/// Marks Provider — returns cached marks instantly (0ms)
final marksProvider = FutureProvider<List<dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.username ?? StorageService.currentUsername;
  final semId = auth.activeSemesterId;

  final mem = StorageService.getMemoryCache('marks', username: user, semesterId: semId) ??
      StorageService.getMemoryCache('marks', username: user);
  if (mem is List && mem.isNotEmpty) {
    return List<dynamic>.from(mem);
  }

  final disk = await StorageService.getCache('marks', username: user, semesterId: semId) ??
      await StorageService.getCache('marks', username: user);
  if (disk is List && disk.isNotEmpty) {
    return List<dynamic>.from(disk);
  }

  final allData = await StorageService.getCache('all_data', username: user, semesterId: semId) ??
      await StorageService.getCache('all_data', username: user);
  if (allData is Map && allData['marks'] != null) {
    final rawMarks = allData['marks'];
    if (rawMarks is List && rawMarks.isNotEmpty) {
      final list = List<dynamic>.from(rawMarks);
      await StorageService.setCache('marks', list, username: user, semesterId: semId);
      return list;
    } else if (rawMarks is Map && rawMarks['marks'] is List && (rawMarks['marks'] as List).isNotEmpty) {
      final list = List<dynamic>.from(rawMarks['marks']);
      await StorageService.setCache('marks', list, username: user, semesterId: semId);
      return list;
    }
  }

  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    return [];
  }

  try {
    final resolvedSem = semId ?? await _resolveSemesterId(ref, auth);
    final fresh = await apiService.fetchMarks(
      username: auth.username!,
      password: auth.password!,
      semSubId: resolvedSem,
    );
    await StorageService.setCache('marks', fresh, username: auth.username, semesterId: resolvedSem);
    return fresh;
  } catch (e) {
    debugPrint('marksProvider network error (falling back to cache): $e');
    final fallback = await StorageService.getCache('marks', username: auth.username, semesterId: semId) ??
        await StorageService.getCache('marks', username: auth.username);
    if (fallback is List && fallback.isNotEmpty) {
      return List<dynamic>.from(fallback);
    }
    final allFallback = await StorageService.getCache('all_data', username: auth.username, semesterId: semId) ??
        await StorageService.getCache('all_data', username: auth.username);
    if (allFallback is Map && allFallback['marks'] != null) {
      final raw = allFallback['marks'];
      if (raw is List && raw.isNotEmpty) return List<dynamic>.from(raw);
      if (raw is Map && raw['marks'] is List && (raw['marks'] as List).isNotEmpty) {
        return List<dynamic>.from(raw['marks']);
      }
    }
    throw Exception(ErrorFormatter.format(e, fallback: 'Could not load marks. Please check your connection.'));
  }
});

/// Profile Provider — returns cached profile instantly (0ms)
final profileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.username ?? StorageService.currentUsername;

  bool isCorrupted(dynamic data) {
    if (data is! Map) return false;
    final sPfp = data['base64_pfp']?.toString();
    final mPfp = (data['mentor_details'] is Map)
        ? data['mentor_details']['base64_pfp']?.toString()
        : null;
    return sPfp != null && mPfp != null && sPfp == mPfp;
  }

  final mem = StorageService.getMemoryCache('profile', username: user);
  if (mem is Map && mem.isNotEmpty && !isCorrupted(mem)) {
    return Map<String, dynamic>.from(mem);
  }

  final disk = await StorageService.getCache('profile', username: user);
  if (disk is Map && disk.isNotEmpty && !isCorrupted(disk)) {
    return Map<String, dynamic>.from(disk);
  }

  final allData = await StorageService.getCache('all_data', username: user);
  if (allData is Map && allData['profile'] is Map && (allData['profile'] as Map).isNotEmpty && !isCorrupted(allData['profile'])) {
    final map = Map<String, dynamic>.from(allData['profile']);
    await StorageService.setCache('profile', map, username: user);
    return map;
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
    final allFallback = await StorageService.getCache('all_data', username: auth.username);
    if (allFallback is Map && allFallback['profile'] is Map && (allFallback['profile'] as Map).isNotEmpty) {
      return Map<String, dynamic>.from(allFallback['profile']);
    }
    if (auth.username != null && auth.username!.isNotEmpty) {
      return {
        'student_name': auth.username,
        'application_number': auth.username,
        'email': '',
        'blood_group': '',
        'dob': '',
      };
    }
    throw Exception(ErrorFormatter.format(e, fallback: 'Could not load profile. Please check your connection.'));
  }
});

/// Grades Provider — returns cached grade history instantly (0ms)
final gradesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.username ?? StorageService.currentUsername;
  final semId = auth.activeSemesterId;

  final mem = StorageService.getMemoryCache('grades', username: user, semesterId: semId) ??
      StorageService.getMemoryCache('grades', username: user);
  if (mem is Map && mem.isNotEmpty) {
    return Map<String, dynamic>.from(mem);
  }

  final disk = await StorageService.getCache('grades', username: user, semesterId: semId) ??
      await StorageService.getCache('grades', username: user);
  if (disk is Map && disk.isNotEmpty) {
    return Map<String, dynamic>.from(disk);
  }

  final allData = await StorageService.getCache('all_data', username: user, semesterId: semId) ??
      await StorageService.getCache('all_data', username: user);
  if (allData is Map && allData['grade_history'] is Map && (allData['grade_history'] as Map).isNotEmpty) {
    final map = Map<String, dynamic>.from(allData['grade_history']);
    await StorageService.setCache('grades', map, username: user, semesterId: semId);
    return map;
  }

  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    return {};
  }

  try {
    final fresh = await apiService.fetchGradeHistory(
      username: auth.username!,
      password: auth.password!,
    );
    await StorageService.setCache('grades', fresh, username: auth.username, semesterId: semId);
    return fresh;
  } catch (e) {
    debugPrint('gradesProvider network error (falling back to cache): $e');
    final fallback = await StorageService.getCache('grades', username: auth.username, semesterId: semId) ??
        await StorageService.getCache('grades', username: auth.username);
    if (fallback is Map && fallback.isNotEmpty) {
      return Map<String, dynamic>.from(fallback);
    }
    final allFallback = await StorageService.getCache('all_data', username: auth.username, semesterId: semId) ??
        await StorageService.getCache('all_data', username: auth.username);
    if (allFallback is Map && allFallback['grade_history'] is Map && (allFallback['grade_history'] as Map).isNotEmpty) {
      return Map<String, dynamic>.from(allFallback['grade_history']);
    }
    throw Exception(ErrorFormatter.format(e, fallback: 'Could not load grades. Please check your connection.'));
  }
});

/// Exam Schedule Provider — returns cached exam schedule instantly (0ms)
final examScheduleProvider = FutureProvider<List<dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.username ?? StorageService.currentUsername;
  final semId = auth.activeSemesterId;

  final mem = StorageService.getMemoryCache('exam_schedule', username: user, semesterId: semId) ??
      StorageService.getMemoryCache('exam_schedule', username: user);
  if (mem is List && mem.isNotEmpty) {
    return List<dynamic>.from(mem);
  }

  final disk = await StorageService.getCache('exam_schedule', username: user, semesterId: semId) ??
      await StorageService.getCache('exam_schedule', username: user);
  if (disk is List && disk.isNotEmpty) {
    return List<dynamic>.from(disk);
  }

  final allData = await StorageService.getCache('all_data', username: user, semesterId: semId) ??
      await StorageService.getCache('all_data', username: user);
  if (allData is Map && allData['exam_schedule'] is List && (allData['exam_schedule'] as List).isNotEmpty) {
    final list = List<dynamic>.from(allData['exam_schedule']);
    await StorageService.setCache('exam_schedule', list, username: user, semesterId: semId);
    return list;
  }

  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    return [];
  }

  try {
    final resolvedSem = semId ?? await _resolveSemesterId(ref, auth);
    final fresh = await apiService.fetchExamSchedule(
      username: auth.username!,
      password: auth.password!,
      semSubId: resolvedSem,
    );
    final result = fresh is List ? fresh : <dynamic>[];
    await StorageService.setCache('exam_schedule', result, username: auth.username, semesterId: resolvedSem);
    return List<dynamic>.from(result);
  } catch (e) {
    debugPrint('examScheduleProvider network error (falling back to cache): $e');
    final fallback = await StorageService.getCache('exam_schedule', username: auth.username, semesterId: semId) ??
        await StorageService.getCache('exam_schedule', username: auth.username);
    if (fallback is List && fallback.isNotEmpty) {
      return List<dynamic>.from(fallback);
    }
    final allFallback = await StorageService.getCache('all_data', username: auth.username, semesterId: semId) ??
        await StorageService.getCache('all_data', username: auth.username);
    if (allFallback is Map && allFallback['exam_schedule'] is List && (allFallback['exam_schedule'] as List).isNotEmpty) {
      return List<dynamic>.from(allFallback['exam_schedule']);
    }
    throw Exception(ErrorFormatter.format(e, fallback: 'Could not load exam schedule. Please check your connection.'));
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
    throw Exception('Please log in to refresh attendance.');
  }
  final semId = await _resolveSemesterId(ref, auth);
  try {
    final fresh = await apiService.fetchAttendance(
      username: auth.username!,
      password: auth.password!,
      semSubId: semId,
    );
    await StorageService.setCache('attendance', fresh, username: auth.username, semesterId: semId);
    if (ref is WidgetRef) {
      ref.invalidate(attendanceProvider);
    } else if (ref is Ref) {
      ref.invalidate(attendanceProvider);
    }
    return fresh;
  } catch (e) {
    debugPrint('refreshAttendance network error: $e');
    throw Exception(ErrorFormatter.format(e, fallback: 'Unable to reach VTOP right now. Showing saved data.'));
  }
}

/// Forces a network fetch for ONLY marks data, updating cache & UI
Future<List<dynamic>> refreshMarks(dynamic ref) async {
  final AuthState auth = (ref is WidgetRef ? ref.read(authProvider) : (ref as Ref).read(authProvider));
  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    throw Exception('Please log in to refresh marks.');
  }
  final semId = await _resolveSemesterId(ref, auth);
  try {
    final fresh = await apiService.fetchMarks(
      username: auth.username!,
      password: auth.password!,
      semSubId: semId,
    );
    await StorageService.setCache('marks', fresh, username: auth.username, semesterId: semId);
    if (ref is WidgetRef) {
      ref.invalidate(marksProvider);
    } else if (ref is Ref) {
      ref.invalidate(marksProvider);
    }
    return fresh;
  } catch (e) {
    debugPrint('refreshMarks network error: $e');
    throw Exception(ErrorFormatter.format(e, fallback: 'Unable to reach VTOP right now. Showing saved data.'));
  }
}

/// Forces a network fetch for ONLY exam schedule data, updating cache & UI
Future<List<dynamic>> refreshExamSchedule(dynamic ref) async {
  final AuthState auth = (ref is WidgetRef ? ref.read(authProvider) : (ref as Ref).read(authProvider));
  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    throw Exception('Please log in to refresh exams.');
  }
  final semId = await _resolveSemesterId(ref, auth);
  try {
    final fresh = await apiService.fetchExamSchedule(
      username: auth.username!,
      password: auth.password!,
      semSubId: semId,
    );
    final result = fresh is List ? fresh : <dynamic>[];
    await StorageService.setCache('exam_schedule', result, username: auth.username, semesterId: semId);
    if (ref is WidgetRef) {
      ref.invalidate(examScheduleProvider);
    } else if (ref is Ref) {
      ref.invalidate(examScheduleProvider);
    }
    return result;
  } catch (e) {
    debugPrint('refreshExamSchedule network error: $e');
    throw Exception(ErrorFormatter.format(e, fallback: 'Unable to reach VTOP right now. Showing saved data.'));
  }
}

/// Forces a network fetch for ONLY timetable data, updating cache & UI
Future<Map<String, dynamic>> refreshTimetable(dynamic ref) async {
  final AuthState auth = (ref is WidgetRef ? ref.read(authProvider) : (ref as Ref).read(authProvider));
  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    throw Exception('Please log in to refresh timetable.');
  }
  final semId = await _resolveSemesterId(ref, auth);
  try {
    final fresh = await apiService.fetchTimetable(
      username: auth.username!,
      password: auth.password!,
      semSubId: semId,
    );
    await StorageService.setCache('timetable', fresh, username: auth.username, semesterId: semId);
    if (ref is WidgetRef) {
      ref.invalidate(timetableProvider);
    } else if (ref is Ref) {
      ref.invalidate(timetableProvider);
    }
    return fresh;
  } catch (e) {
    debugPrint('refreshTimetable network error: $e');
    throw Exception(ErrorFormatter.format(e, fallback: 'Unable to reach VTOP right now. Showing saved data.'));
  }
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
  await StorageService.setCache(cacheKey, fresh, username: auth.username, semesterId: semId);
  return fresh;
}
