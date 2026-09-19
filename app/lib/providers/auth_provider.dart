import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../services/storage_service.dart';


// ============================================================
// AUTH STATE
// ============================================================

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;

  final String? username;
  final String? password;

  // Backend VTOP session ID.
  //
  // This is the session created by /auth/login and stored on
  // the backend. It is intentionally kept in memory only.
  final String? sessionId;

  final String? activeSemesterId;
  final String? activeSemesterName;

  final List<Map<String, dynamic>> availableSemesters;

  final String? errorMessage;

  // True when VTOP requires OTP verification.
  final bool otpRequired;

  // Session waiting for OTP verification.
  final String? pendingSessionId;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.username,
    this.password,
    this.sessionId,
    this.activeSemesterId,
    this.activeSemesterName,
    this.availableSemesters = const [],
    this.errorMessage,
    this.otpRequired = false,
    this.pendingSessionId,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? username,
    String? password,
    String? sessionId,
    String? activeSemesterId,
    String? activeSemesterName,
    List<Map<String, dynamic>>? availableSemesters,
    String? errorMessage,
    bool? otpRequired,
    String? pendingSessionId,

    bool clearSessionId = false,
    bool clearPendingSession = false,
    bool clearError = false,
  }) {
    return AuthState(
      isAuthenticated:
          isAuthenticated ?? this.isAuthenticated,

      isLoading:
          isLoading ?? this.isLoading,

      username:
          username ?? this.username,

      password:
          password ?? this.password,

      sessionId: clearSessionId
          ? null
          : sessionId ?? this.sessionId,

      activeSemesterId:
          activeSemesterId ?? this.activeSemesterId,

      activeSemesterName:
          activeSemesterName ?? this.activeSemesterName,

      availableSemesters:
          availableSemesters ?? this.availableSemesters,

      errorMessage: clearError
          ? null
          : errorMessage ?? this.errorMessage,

      otpRequired:
          otpRequired ?? this.otpRequired,

      pendingSessionId: clearPendingSession
          ? null
          : pendingSessionId ?? this.pendingSessionId,
    );
  }
}


// ============================================================
// AUTH NOTIFIER
// ============================================================

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier()
      : super(
          const AuthState(
            isLoading: true,
          ),
        ) {
    checkSavedAuth();
  }

  // ============================================================
  // LOGIN CONCURRENCY GUARD
  // ============================================================
  //
  // If multiple widgets/providers attempt login at the same
  // time, they all wait for the SAME login Future.
  //
  // This prevents:
  //
  //     /auth/login
  //     /auth/login
  //     /auth/login
  //
  // happening simultaneously.
  //

  Future<bool>? _activeLogin;

  // ============================================================
  // CHECK SAVED AUTH
  // ============================================================

  Future<void> checkSavedAuth() async {
    try {
      final credentials =
          await StorageService.getCredentials();

      final username =
          credentials['username'];

      final password =
          credentials['password'];

      final semesterId =
          credentials['semesterId'];

      final semesterName =
          credentials['semesterName'];

      // --------------------------------------------------------
      // No saved credentials
      // --------------------------------------------------------

      if (username == null ||
          username.isEmpty ||
          password == null ||
          password.isEmpty) {
        state = const AuthState(
          isAuthenticated: false,
          isLoading: false,
        );

        return;
      }

      // --------------------------------------------------------
      // FAST-BOOT: Mark authenticated IMMEDIATELY!
      // Do NOT block the user on a slow VTOP network call.
      // --------------------------------------------------------

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        username: username,
        password: password,
        activeSemesterId: semesterId,
        activeSemesterName: semesterName,
        clearError: true,
      );

      // Silently renew VTOP session in the background
      _renewSessionSilently(username, password, semesterId, semesterName);
    } catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        errorMessage: _cleanError(e),
      );
    }
  }

  void _renewSessionSilently(
    String username,
    String password,
    String? semesterId,
    String? semesterName,
  ) {
    unawaited(() async {
      try {
        final result = await apiService.initiateLogin(
          username: username,
          password: password,
        );
        final sessionId = result['session_id']?.toString();
        final otpRequired = result['otp_required'] == true;
        if (sessionId != null && sessionId.isNotEmpty) {
          apiService.setVtopSessionId(sessionId);
          if (otpRequired) {
            state = state.copyWith(
              otpRequired: true,
              sessionId: sessionId,
              pendingSessionId: sessionId,
            );
          } else {
            state = state.copyWith(
              sessionId: sessionId,
              otpRequired: false,
            );
            // Refresh semester list silently
            _refreshSemesters(
              username: username,
              password: password,
              preferredSemesterId: semesterId,
              preferredSemesterName: semesterName,
            );
          }
        }
      } catch (e) {
        debugPrint('Silent session renewal background error: $e');
      }
    }());
  }


  // ============================================================
  // LOGIN
  // ============================================================

  Future<bool> login({
    required String username,
    required String password,
    String? savedSemesterId,
    String? savedSemesterName,
  }) {
    // ----------------------------------------------------------
    // Already logging in?
    //
    // Return the same Future.
    // ----------------------------------------------------------

    final existingLogin = _activeLogin;

    if (existingLogin != null) {
      return existingLogin;
    }

    final future = _performLogin(
      username: username,
      password: password,
      savedSemesterId: savedSemesterId,
      savedSemesterName: savedSemesterName,
    );

    _activeLogin = future;

    future.whenComplete(() {
      if (identical(_activeLogin, future)) {
        _activeLogin = null;
      }
    });

    return future;
  }


  Future<bool> _performLogin({
    required String username,
    required String password,
    String? savedSemesterId,
    String? savedSemesterName,
  }) async {
    state = state.copyWith(
      isLoading: true,
      username: username,
      password: password,
      clearError: true,
    );

    try {
      // ========================================================
      // ONE BACKEND LOGIN
      // ========================================================

      final result =
          await apiService.initiateLogin(
        username: username,
        password: password,
      );

      // ========================================================
      // GET SESSION ID
      // ========================================================

      final sessionId =
          result['session_id']?.toString();

      final otpRequired =
          result['otp_required'] == true;

      if (sessionId == null ||
          sessionId.isEmpty) {
        state = state.copyWith(
          isAuthenticated: false,
          isLoading: false,
          errorMessage:
              'Server did not return a VTOP session.',
        );

        return false;
      }

      // ApiClient already receives and stores the session ID,
      // but explicitly set it here too for clarity.
      apiService.setVtopSessionId(
        sessionId,
      );

      // ========================================================
      // OTP REQUIRED
      // ========================================================

      if (otpRequired) {
        state = state.copyWith(
          isAuthenticated: false,
          isLoading: false,

          username: username,
          password: password,

          sessionId: sessionId,
          pendingSessionId: sessionId,

          otpRequired: true,

          activeSemesterId:
              savedSemesterId,

          activeSemesterName:
              savedSemesterName,

          clearError: true,
        );

        return false;
      }

      // ========================================================
      // LOGIN SUCCESSFUL WITHOUT OTP
      // ========================================================

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,

        username: username,
        password: password,

        sessionId: sessionId,

        otpRequired: false,
        clearPendingSession: true,

        activeSemesterId:
            savedSemesterId,

        activeSemesterName:
            savedSemesterName,

        clearError: true,
      );

      // Save credentials.
      await StorageService.saveCredentials(
        username: username,
        password: password,
        semesterId: savedSemesterId,
        semesterName: savedSemesterName,
      );

      // Fetch semesters asynchronously in background so login returns immediately
      unawaited(_refreshSemesters(
        username: username,
        password: password,
        preferredSemesterId:
            savedSemesterId,
        preferredSemesterName:
            savedSemesterName,
      ));

      return true;
    } catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        errorMessage: _cleanError(e),
      );

      return false;
    }
  }


  // ============================================================
  // VERIFY OTP
  // ============================================================

  Future<bool> verifyOtp(String otp) async {
    final sessionId =
        state.pendingSessionId;

    // ----------------------------------------------------------
    // No pending session
    // ----------------------------------------------------------

    if (sessionId == null ||
        sessionId.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        otpRequired: false,
        errorMessage:
            'Login session expired. Please login again.',
      );

      return false;
    }

    final cleanedOtp =
        otp.trim();

    if (cleanedOtp.isEmpty) {
      state = state.copyWith(
        errorMessage:
            'Please enter the OTP.',
      );

      return false;
    }

    try {
      state = state.copyWith(
        isLoading: true,
        clearError: true,
      );

      // ========================================================
      // VERIFY OTP USING SAME SESSION
      // ========================================================

      final result =
          await apiService.verifyLoginOtp(
        sessionId: sessionId,
        otp: cleanedOtp,
      );

      // Backend normally returns the same session ID.
      final verifiedSessionId =
          result['session_id']?.toString() ??
              sessionId;

      // Make absolutely sure ApiClient uses the verified
      // session for every /student/* request.
      apiService.setVtopSessionId(
        verifiedSessionId,
      );

      // ========================================================
      // AUTHENTICATED
      // ========================================================

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,

        sessionId:
            verifiedSessionId,

        otpRequired: false,

        clearPendingSession: true,
        clearError: true,
      );

      // ========================================================
      // SAVE CREDENTIALS
      // ========================================================

      final username =
          state.username;

      final password =
          state.password;

      if (username != null &&
          username.isNotEmpty &&
          password != null &&
          password.isNotEmpty) {
        await StorageService.saveCredentials(
          username: username,
          password: password,
          semesterId:
              state.activeSemesterId,
          semesterName:
              state.activeSemesterName,
        );
      }

      // ========================================================
      // FETCH SEMESTERS
      // ========================================================
      //
      // This request uses the SAME VTOP session.
      //

      if (username != null &&
          password != null) {
        await _refreshSemesters(
          username: username,
          password: password,
          preferredSemesterId:
              state.activeSemesterId,
          preferredSemesterName:
              state.activeSemesterName,
        );
      }

      return true;
    } catch (e) {
      // Keep OTP popup open so the user can correct the OTP.
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        otpRequired: true,
        errorMessage: _cleanError(e),
      );

      return false;
    }
  }


  // ============================================================
  // RESEND OTP
  // ============================================================

  Future<bool> resendOtp() async {
    final sessionId =
        state.pendingSessionId;

    if (sessionId == null ||
        sessionId.isEmpty) {
      state = state.copyWith(
        otpRequired: false,
        errorMessage:
            'Login session expired. Please login again.',
      );

      return false;
    }

    try {
      state = state.copyWith(
        clearError: true,
      );

      await apiService.resendLoginOtp(
        sessionId,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        otpRequired: true,
        errorMessage: _cleanError(e),
      );

      return false;
    }
  }


  // ============================================================
  // REFRESH SEMESTERS
  // ============================================================

  Future<void> _refreshSemesters({
    required String username,
    required String password,
    String? preferredSemesterId,
    String? preferredSemesterName,
  }) async {
    try {
      // --------------------------------------------------------
      // ApiClient automatically attaches:
      //
      // X-VTOP-Session-ID
      //
      // to /student/semesters.
      // --------------------------------------------------------

      final data =
          await apiService.fetchSemesters(
        username,
        password,
      );

      final semesters =
          _parseSemesters(data);

      if (semesters.isEmpty) {
        return;
      }

      // ========================================================
      // SELECT SEMESTER
      // ========================================================

      String? selectedId;
      String? selectedName;

      // --------------------------------------------------------
      // 1. Previously selected semester
      // --------------------------------------------------------

      if (preferredSemesterId != null &&
          semesters.any(
            (semester) =>
                semester['id'] ==
                preferredSemesterId,
          )) {
        selectedId =
            preferredSemesterId;

        final selected =
            semesters.firstWhere(
          (semester) =>
              semester['id'] ==
              preferredSemesterId,
        );

        selectedName =
            selected['name']?.toString() ??
                preferredSemesterName ??
                preferredSemesterId;
      }

      // --------------------------------------------------------
      // 2. Current state semester
      // --------------------------------------------------------

      if (selectedId == null &&
          state.activeSemesterId != null &&
          semesters.any(
            (semester) =>
                semester['id'] ==
                state.activeSemesterId,
          )) {
        selectedId =
            state.activeSemesterId;

        final selected =
            semesters.firstWhere(
          (semester) =>
              semester['id'] ==
              selectedId,
        );

        selectedName =
            selected['name']?.toString() ??
                state.activeSemesterName ??
                selectedId;
      }

      // --------------------------------------------------------
      // 3. First semester
      // --------------------------------------------------------

      if (selectedId == null) {
        selectedId =
            semesters.first['id']
                ?.toString();

        selectedName =
            semesters.first['name']
                    ?.toString() ??
                selectedId;
      }

      // ========================================================
      // UPDATE STATE
      // ========================================================

      state = state.copyWith(
        availableSemesters:
            semesters,
        activeSemesterId:
            selectedId,
        activeSemesterName:
            selectedName,
      );

      // ========================================================
      // SAVE SEMESTER
      // ========================================================

      if (selectedId != null &&
          selectedId.isNotEmpty) {
        await StorageService.saveSemester(
          selectedId,
          selectedName ?? selectedId,
        );
      }
    } catch (e) {
      // Don't destroy a valid authenticated state just because
      // semester fetching failed.
      state = state.copyWith(
        errorMessage: _cleanError(e),
      );
    }
  }


  // ============================================================
  // CHANGE SEMESTER
  // ============================================================

  Future<void> changeSemester(
    String semesterId,
    String semesterName,
  ) async {
    if (semesterId.isEmpty) {
      return;
    }

    state = state.copyWith(
      activeSemesterId:
          semesterId,
      activeSemesterName:
          semesterName,
      clearError: true,
    );

    await StorageService.saveSemester(
      semesterId,
      semesterName,
    );
  }


  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    // ----------------------------------------------------------
    // Clear backend session ID from ApiClient.
    // ----------------------------------------------------------

    apiService.clearVtopSessionId();

    // ----------------------------------------------------------
    // Clear saved credentials.
    // ----------------------------------------------------------

    try {
      await StorageService.clearAll();
    } catch (_) {
      // Ignore storage errors during logout.
    }

    // ----------------------------------------------------------
    // Reset state.
    // ----------------------------------------------------------

    state = const AuthState(
      isAuthenticated: false,
      isLoading: false,
    );
  }


  // ============================================================
  // PARSE SEMESTERS
  // ============================================================

  List<Map<String, dynamic>> _parseSemesters(
    dynamic data,
  ) {
    dynamic rawList;

    // ----------------------------------------------------------
    // Response itself is a list.
    // ----------------------------------------------------------

    if (data is List) {
      rawList = data;
    }

    // ----------------------------------------------------------
    // Response is a map.
    // ----------------------------------------------------------

    else if (data is Map) {
      if (data['semesters'] is List) {
        rawList =
            data['semesters'];
      } else if (data['data'] is List) {
        rawList =
            data['data'];
      } else if (data['semester_list'] is List) {
        rawList =
            data['semester_list'];
      }
    }

    if (rawList is! List) {
      return [];
    }

    final result =
        <Map<String, dynamic>>[];

    for (final item in rawList) {
      if (item is! Map) {
        continue;
      }

      final map =
          Map<String, dynamic>.from(item);

      // ========================================================
      // FIND SEMESTER ID
      // ========================================================

      String? id;

      for (final key in [
        'id',
        'sem_sub_id',
        'semester_id',
        'value',
      ]) {
        final value =
            map[key]?.toString();

        if (value != null &&
            value.isNotEmpty) {
          id = value;
          break;
        }
      }

      // ========================================================
      // FIND SEMESTER NAME
      // ========================================================

      String? name;

      for (final key in [
        'name',
        'semester_name',
        'sem_name',
        'label',
        'text',
      ]) {
        final value =
            map[key]?.toString();

        if (value != null &&
            value.isNotEmpty) {
          name = value;
          break;
        }
      }

      if (id != null &&
          id.isNotEmpty) {
        result.add({
          'id': id,
          'name': name ?? id,
        });
      }
    }

    return result;
  }


  // ============================================================
  // ERROR CLEANUP
  // ============================================================

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        )
        .trim();
  }
}


// ============================================================
// RIVERPOD PROVIDER
// ============================================================

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);