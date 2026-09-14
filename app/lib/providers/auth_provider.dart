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

  // OTP state — when otpRequired is true the user must supply the OTP
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
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      username: username ?? this.username,
      password: password ?? this.password,
      activeSemesterId: activeSemesterId ?? this.activeSemesterId,
      activeSemesterName: activeSemesterName ?? this.activeSemesterName,
      availableSemesters: availableSemesters ?? this.availableSemesters,
      errorMessage: errorMessage,
      otpRequired: otpRequired ?? this.otpRequired,
      pendingSessionId: pendingSessionId ?? this.pendingSessionId,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(isLoading: true)) {
    checkSavedAuth();
  }

  Future<void> checkSavedAuth() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final creds = await StorageService.getCredentials();
      final username = creds['username'];
      final password = creds['password'];
      final semesterId = creds['semesterId'];
      final semesterName = creds['semesterName'];

      if (username != null && password != null && username.isNotEmpty && password.isNotEmpty) {
        try {
          final semData = await apiService.fetchSemesters(username, password);
          final rawSemesters = semData['semesters'] as List<dynamic>? ?? [];
          final semesters = rawSemesters.map((s) => {
            'id': s['id'].toString(),
            'name': s['name'].toString(),
          }).toList();

          final currentSemId = semesterId ?? (semesters.isNotEmpty ? semesters.first['id'] : null);
          final currentSemName = semesterName ?? (semesters.isNotEmpty ? semesters.first['name'] : null);

          if (currentSemId != null && currentSemName != null) {
            await StorageService.saveSemester(currentSemId, currentSemName);
          }

          state = state.copyWith(
            isAuthenticated: true,
            isLoading: false,
            username: username,
            password: password,
            activeSemesterId: currentSemId,
            activeSemesterName: currentSemName,
            availableSemesters: semesters,
          );
          return;
        } catch (_) {
          // Offline or session issue — still allow access with saved semester
          state = state.copyWith(
            isAuthenticated: true,
            isLoading: false,
            username: username,
            password: password,
            activeSemesterId: semesterId,
            activeSemesterName: semesterName,
          );
          return;
        }
      }
      state = state.copyWith(isAuthenticated: false, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Step 1: Initiates login via the new /auth/login endpoint.
  /// Returns true if login is complete, false if OTP is required
  /// (in which case state.otpRequired == true and pendingSessionId is set).
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, otpRequired: false);
    try {
      final result = await apiService.initiateLogin(
        username: username,
        password: password,
      );

      final sessionId = result['session_id'] as String;
      final otpRequired = result['otp_required'] as bool? ?? false;

      if (otpRequired) {
        // Pause here — store pending session and ask the user for OTP
        state = state.copyWith(
          isLoading: false,
          otpRequired: true,
          pendingSessionId: sessionId,
          username: username,
          password: password,
        );
        return false;
      }

      // OTP not required — proceed to fetch semesters and complete auth
      return await _finishLogin(username: username, password: password);
    } catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        errorMessage: _friendlyError(e.toString()),
      );
      return false;
    }
  }

  /// Step 2 (called from OTP screen): Verifies OTP to complete login.
  Future<bool> verifyOtp(String otp) async {
    final sessionId = state.pendingSessionId;
    if (sessionId == null) {
      state = state.copyWith(errorMessage: 'No pending OTP session. Please login again.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await apiService.verifyLoginOtp(sessionId: sessionId, otp: otp);
      // OTP verified — now fetch semesters and mark fully authenticated
      return await _finishLogin(
        username: state.username ?? '',
        password: state.password ?? '',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyError(e.toString()),
      );
      return false;
    }
  }

  /// Asks VTOP to resend the login OTP.
  Future<void> resendOtp() async {
    final sessionId = state.pendingSessionId;
    if (sessionId == null) return;
    try {
      await apiService.resendLoginOtp(sessionId);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to resend OTP: ${e.toString()}');
    }
  }

  /// Fetches semesters and sets the fully authenticated state.
  Future<bool> _finishLogin({
    required String username,
    required String password,
  }) async {
    try {
      final semData = await apiService.fetchSemesters(username, password);
      final rawSemesters = semData['semesters'] as List<dynamic>? ?? [];
      final semesters = rawSemesters.map((s) => {
        'id': s['id'].toString(),
        'name': s['name'].toString(),
      }).toList();

      final firstSem = semesters.isNotEmpty ? semesters.first : null;
      final semId = firstSem?['id'];
      final semName = firstSem?['name'];

      await StorageService.saveCredentials(
        username: username,
        password: password,
        semesterId: semId,
        semesterName: semName,
      );

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        otpRequired: false,
        pendingSessionId: null,
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
        errorMessage: _friendlyError(e.toString()),
      );
      return false;
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('Invalid Username') || raw.contains('Invalid Password')) {
      return 'Invalid username or password.';
    }
    if (raw.contains('Invalid Captcha') || raw.contains('captcha')) {
      return 'Captcha verification failed. Please try again.';
    }
    if (raw.contains('OTP') && raw.contains('Incorrect')) {
      return 'Incorrect OTP. Please try again.';
    }
    if (raw.contains('OTP') && raw.contains('expired')) {
      return 'OTP has expired. Please login again.';
    }
    if (raw.contains('Connection') || raw.contains('connect')) {
      return 'Cannot connect to backend server. Make sure FastAPI is running.';
    }
    return raw;
  }

  Future<void> changeSemester(String semesterId, String semesterName) async {
    await StorageService.saveSemester(semesterId, semesterName);
    state = state.copyWith(
      activeSemesterId: semesterId,
      activeSemesterName: semesterName,
    );
  }

  Future<void> logout() async {
    await StorageService.clearAll();
    state = const AuthState(isAuthenticated: false, isLoading: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
