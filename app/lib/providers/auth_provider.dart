import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../services/storage_service.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? username;
  final String? password;
  final String? activeSemesterId;
  final String? activeSemesterName;
  final List<Map<String, String>> availableSemesters;
  final String? errorMessage;

  // ============================================================
  // OTP STATE
  // ============================================================

  final bool otpRequired;
  final String? pendingSessionId;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.username,
    this.password,
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
    String? activeSemesterId,
    String? activeSemesterName,
    List<Map<String, String>>? availableSemesters,
    String? errorMessage,
    bool? otpRequired,
    String? pendingSessionId,

    // Explicitly clear nullable values.
    bool clearErrorMessage = false,
    bool clearPendingSessionId = false,
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

      activeSemesterId:
          activeSemesterId ?? this.activeSemesterId,

      activeSemesterName:
          activeSemesterName ?? this.activeSemesterName,

      availableSemesters:
          availableSemesters ?? this.availableSemesters,

      errorMessage:
          clearErrorMessage
              ? null
              : (errorMessage ?? this.errorMessage),

      otpRequired:
          otpRequired ?? this.otpRequired,

      pendingSessionId:
          clearPendingSessionId
              ? null
              : (pendingSessionId ?? this.pendingSessionId),
    );
  }
}

// ============================================================
// AUTH NOTIFIER
// ============================================================

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier()
      : super(const AuthState(isLoading: true)) {
    _initializationFuture = checkSavedAuth();
  }

  // Prevent multiple login requests from happening at the same time.
  Future<bool>? _activeLogin;

  // Prevent login() from racing against startup authentication.
  late final Future<void> _initializationFuture;

  // ============================================================
  // STARTUP AUTH
  // ============================================================

  Future<void> checkSavedAuth() async {
    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
    );

    try {
      final creds = await StorageService.getCredentials();

      final username = creds['username'];
      final password = creds['password'];
      final semesterId = creds['semesterId'];
      final semesterName = creds['semesterName'];
      final savedSessionId = creds['sessionId'];

      // --------------------------------------------------------
      // No saved credentials
      // --------------------------------------------------------

      if (username == null ||
          password == null ||
          username.isEmpty ||
          password.isEmpty) {
        state = state.copyWith(
          isAuthenticated: false,
          isLoading: false,
          clearErrorMessage: true,
          clearPendingSessionId: true,
          otpRequired: false,
        );
        return;
      }

      // --------------------------------------------------------
      // We need a real backend session.
      // --------------------------------------------------------

      if (savedSessionId == null ||
          savedSessionId.isEmpty) {
        state = state.copyWith(
          isAuthenticated: false,
          isLoading: false,
          username: username,
          password: password,
          activeSemesterId: semesterId,
          activeSemesterName: semesterName,
          clearPendingSessionId: true,
          otpRequired: false,
        );
        return;
      }

      // Restore the backend session into ApiClient.
      apiService.setVtopSessionId(savedSessionId);

      // --------------------------------------------------------
      // Validate the restored session.
      //
      // /student/semesters requires the X-VTOP-Session-ID header,
      // so a successful response proves the backend session works.
      // --------------------------------------------------------

      try {
        final semData = await apiService.fetchSemesters(
          username,
          password,
        );

        final semesters = _parseSemesters(semData);

        final currentSemId =
            semesterId ??
            (semesters.isNotEmpty
                ? semesters.first['id']
                : null);

        final currentSemName =
            semesterName ??
            (semesters.isNotEmpty
                ? semesters.first['name']
                : null);

        if (currentSemId != null &&
            currentSemName != null) {
          await StorageService.saveSemester(
            currentSemId,
            currentSemName,
          );
        }

        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          username: username,
          password: password,
          activeSemesterId: currentSemId,
          activeSemesterName: currentSemName,
          availableSemesters: semesters,
          otpRequired: false,
          clearPendingSessionId: true,
          clearErrorMessage: true,
        );
      } catch (_) {
        // The backend session no longer exists/works.
        //
        // Do NOT pretend the user is authenticated.
        await StorageService.clearSessionId();
        apiService.clearVtopSessionId();

        state = state.copyWith(
          isAuthenticated: false,
          isLoading: false,
          username: username,
          password: password,
          activeSemesterId: semesterId,
          activeSemesterName: semesterName,
          otpRequired: false,
          clearPendingSessionId: true,
        );
      }
    } catch (e) {
      apiService.clearVtopSessionId();

      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        errorMessage: _friendlyError(
          e.toString(),
        ),
        clearPendingSessionId: true,
        otpRequired: false,
      );
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

  /// Starts a new VTOP login.
  ///
  /// IMPORTANT:
  /// Multiple simultaneous calls return the SAME Future.
  /// Therefore only one /auth/login request can be active.
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    final existingLogin = _activeLogin;

    if (existingLogin != null) {
      return existingLogin;
    }

    final loginFuture = _performLogin(
      username: username,
      password: password,
    );

    _activeLogin = loginFuture;

    try {
      return await loginFuture;
    } finally {
      if (identical(_activeLogin, loginFuture)) {
        _activeLogin = null;
      }
    }
  }

  Future<bool> _performLogin({
    required String username,
    required String password,
  }) async {
    // Wait until startup authentication has completed.
    await _initializationFuture;

    state = state.copyWith(
      isLoading: true,
      isAuthenticated: false,
      username: username,
      password: password,
      otpRequired: false,
      clearPendingSessionId: true,
      clearErrorMessage: true,
    );

    try {
      final result = await apiService.initiateLogin(
        username: username,
        password: password,
      );

      final sessionId =
          result['session_id']?.toString();

      final otpRequired =
          result['otp_required'] as bool? ?? false;

      if (sessionId == null ||
          sessionId.isEmpty) {
        throw Exception(
          'Backend did not return a VTOP session.',
        );
      }

      // Save the session immediately.
      //
      // This is important even when OTP is required because
      // verifyOtp() must use the exact same backend session.
      await StorageService.saveSessionId(sessionId);

      // --------------------------------------------------------
      // OTP REQUIRED
      // --------------------------------------------------------

      if (otpRequired) {
        state = state.copyWith(
          isAuthenticated: false,
          isLoading: false,
          otpRequired: true,
          pendingSessionId: sessionId,
          username: username,
          password: password,
          clearErrorMessage: true,
        );

        return false;
      }

      // --------------------------------------------------------
      // LOGIN COMPLETE WITHOUT OTP
      // --------------------------------------------------------

      return await _finishLogin(
        username: username,
        password: password,
      );
    } catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        otpRequired: false,
        clearPendingSessionId: true,
        errorMessage: _friendlyError(
          e.toString(),
        ),
      );

      return false;
    }
  }

  // ============================================================
  // VERIFY OTP
  // ============================================================

  Future<bool> verifyOtp(String otp) async {
    final sessionId = state.pendingSessionId;

    if (sessionId == null || sessionId.isEmpty) {
      state = state.copyWith(
        errorMessage:
            'No pending OTP session. Please login again.',
      );

      return false;
    }

    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
    );

    try {
      await apiService.verifyLoginOtp(
        sessionId: sessionId,
        otp: otp,
      );

      // The same session has now become authenticated.
      await StorageService.saveSessionId(sessionId);

      return await _finishLogin(
        username: state.username ?? '',
        password: state.password ?? '',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyError(
          e.toString(),
        ),
      );

      return false;
    }
  }

  // ============================================================
  // RESEND OTP
  // ============================================================

  Future<void> resendOtp() async {
    final sessionId = state.pendingSessionId;

    if (sessionId == null || sessionId.isEmpty) {
      state = state.copyWith(
        errorMessage:
            'No pending OTP session. Please login again.',
      );
      return;
    }

    try {
      await apiService.resendLoginOtp(sessionId);

      state = state.copyWith(
        clearErrorMessage: true,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage:
            'Failed to resend OTP: ${e.toString()}',
      );
    }
  }

  // ============================================================
  // FINISH LOGIN
  // ============================================================

  Future<bool> _finishLogin({
    required String username,
    required String password,
  }) async {
    try {
      final semData = await apiService.fetchSemesters(
        username,
        password,
      );

      final semesters = _parseSemesters(semData);

      final firstSem =
          semesters.isNotEmpty
              ? semesters.first
              : null;

      final semId = firstSem?['id'];
      final semName = firstSem?['name'];

      await StorageService.saveCredentials(
        username: username,
        password: password,
        semesterId: semId,
        semesterName: semName,
      );

      // Session was already saved by login/OTP verification.
      final sessionId =
          apiService.vtopSessionId;

      if (sessionId != null &&
          sessionId.isNotEmpty) {
        await StorageService.saveSessionId(
          sessionId,
        );
      }

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        otpRequired: false,
        clearPendingSessionId: true,
        clearErrorMessage: true,
        username: username,
        password: password,
        activeSemesterId: semId,
        activeSemesterName: semName,
        availableSemesters: semesters,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        errorMessage: _friendlyError(
          e.toString(),
        ),
      );

      return false;
    }
  }

  // ============================================================
  // SEMESTER PARSING
  // ============================================================

  List<Map<String, String>> _parseSemesters(
    Map<String, dynamic> semData,
  ) {
    final rawSemesters =
        semData['semesters'] as List<dynamic>? ?? [];

    return rawSemesters
        .whereType<Map>()
        .map(
          (s) => {
            'id': s['id']?.toString() ?? '',
            'name': s['name']?.toString() ?? '',
          },
        )
        .where(
          (s) =>
              s['id']!.isNotEmpty &&
              s['name']!.isNotEmpty,
        )
        .toList();
  }

  // ============================================================
  // ERROR HANDLING
  // ============================================================

  String _friendlyError(String raw) {
    if (raw.contains('Invalid Username') ||
        raw.contains('Invalid Password')) {
      return 'Invalid username or password.';
    }

    if (raw.contains('Invalid Captcha') ||
        raw.contains('captcha')) {
      return 'Captcha verification failed. Please try again.';
    }

    if (raw.contains('OTP') &&
        raw.contains('Incorrect')) {
      return 'Incorrect OTP. Please try again.';
    }

    if (raw.contains('OTP') &&
        raw.contains('expired')) {
      return 'OTP has expired. Please login again.';
    }

    if (raw.contains('Connection') ||
        raw.contains('connect')) {
      return 'Cannot connect to backend server. Make sure FastAPI is running.';
    }

    if (raw.contains('VTOP session')) {
      return 'VTOP session expired. Please login again.';
    }

    return raw;
  }

  // ============================================================
  // CHANGE SEMESTER
  // ============================================================

  Future<void> changeSemester(
    String semesterId,
    String semesterName,
  ) async {
    await StorageService.saveSemester(
      semesterId,
      semesterName,
    );

    state = state.copyWith(
      activeSemesterId: semesterId,
      activeSemesterName: semesterName,
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    // Clear the in-memory backend session reference first.
    apiService.clearVtopSessionId();

    // Remove credentials + session from secure storage.
    await StorageService.clearAll();

    state = const AuthState(
      isAuthenticated: false,
      isLoading: false,
    );
  }
}

// ============================================================
// PROVIDER
// ============================================================

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);