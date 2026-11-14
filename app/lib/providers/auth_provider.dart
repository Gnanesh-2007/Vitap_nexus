import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../services/storage_service.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final bool isCheckingSavedAuth;
  final String? username;
  final String? password;
  final String? activeSemesterId;
  final String? activeSemesterName;
  final List<Map<String, dynamic>> availableSemesters;
  final String? errorMessage;

  // OTP state - when otpRequired is true the user must supply the OTP
  final bool otpRequired;
  final String? pendingSessionId;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.isCheckingSavedAuth = false,
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
    bool? isCheckingSavedAuth,
    String? username,
    String? password,
    String? activeSemesterId,
    String? activeSemesterName,
    List<Map<String, dynamic>>? availableSemesters,
    String? errorMessage,
    bool? otpRequired,
    String? pendingSessionId,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      isCheckingSavedAuth: isCheckingSavedAuth ?? this.isCheckingSavedAuth,
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
  AuthNotifier() : super(_buildInitialAuthState()) {
    if (!state.isAuthenticated) {
      checkSavedAuth();
    } else if (state.availableSemesters.isEmpty &&
        state.username != null &&
        state.password != null) {
      _refreshSemestersInBackground(
        state.username!,
        state.password!,
        state.activeSemesterId,
        state.activeSemesterName,
      );
    }
  }

  /// Synchronously builds the initial AuthState from pre-warmed memory cache
  /// so Frame 1 opens directly to MainNavScreen or LoginScreen with 0ms delay.
  static AuthState _buildInitialAuthState() {
    final creds = StorageService.getCredentialsSync();
    final username = creds['username'];
    final password = creds['password'];
    final semesterId = creds['semesterId'];
    final semesterName = creds['semesterName'];

    if (username != null &&
        password != null &&
        username.isNotEmpty &&
        password.isNotEmpty) {
      final savedSemesters = StorageService.getAvailableSemestersSync();
      final resolvedSemId =
          semesterId ??
          (savedSemesters.isNotEmpty
              ? savedSemesters.first['id']?.toString()
              : null);
      final resolvedSemName =
          semesterName ??
          (savedSemesters.isNotEmpty
              ? savedSemesters.first['name']?.toString()
              : null);

      return AuthState(
        isAuthenticated: true,
        isLoading: false,
        isCheckingSavedAuth: false,
        username: username,
        password: password,
        activeSemesterId: resolvedSemId,
        activeSemesterName: resolvedSemName,
        availableSemesters: savedSemesters,
      );
    }

    return const AuthState(
      isAuthenticated: false,
      isLoading: false,
      isCheckingSavedAuth: false,
    );
  }

  /// Instant boot: loads saved credentials & semester from storage immediately (<100ms)
  /// without forcing the user to wait on slow VTOP network calls during startup.
  Future<void> checkSavedAuth() async {
    try {
      final creds = await StorageService.getCredentials();
      final username = creds['username'];
      final password = creds['password'];
      final semesterId = creds['semesterId'];
      final semesterName = creds['semesterName'];

      if (username != null && password != null && username.isNotEmpty && password.isNotEmpty) {
        await apiService.restoreSessionFromStorage(username: username);
        final savedSemesters = await StorageService.getAvailableSemesters(username: username);
        final resolvedSemId = semesterId ?? (savedSemesters.isNotEmpty ? savedSemesters.first['id']?.toString() : null);
        final resolvedSemName = semesterName ?? (savedSemesters.isNotEmpty ? savedSemesters.first['name']?.toString() : null);

        // Fast-boot straight into authenticated state with cached semesters
        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          isCheckingSavedAuth: false,
          username: username,
          password: password,
          activeSemesterId: resolvedSemId,
          activeSemesterName: resolvedSemName,
          availableSemesters: savedSemesters,
        );

        // Only fetch semester list on cold boot if no cached semester list exists yet
        if (savedSemesters.isEmpty) {
          _refreshSemestersInBackground(username, password, resolvedSemId, resolvedSemName);
        }
        return;
      }
      state = state.copyWith(isAuthenticated: false, isLoading: false, isCheckingSavedAuth: false);
    } catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        isCheckingSavedAuth: false,
        errorMessage: e.toString(),
      );
    }
  }

  void requireInSessionOtp(String sessionId) {
    state = state.copyWith(
      otpRequired: true,
      pendingSessionId: sessionId,
      errorMessage: null,
    );
  }

  void clearOtpRequired() {
    state = state.copyWith(
      otpRequired: false,
      pendingSessionId: null,
      errorMessage: null,
    );
  }

  void cancelOtp() {
    final staleSession = state.pendingSessionId;
    apiService.clearVtopSessionId();
    if (staleSession != null && staleSession.isNotEmpty) {
      apiService.logout(staleSession).catchError((_) => <String, dynamic>{});
    }
    state = state.copyWith(
      otpRequired: false,
      pendingSessionId: null,
      errorMessage: null,
    );
  }

  Future<void> refreshSemesters() async {
    final username = state.username;
    final password = state.password;
    if (username == null || password == null || username.isEmpty || password.isEmpty) return;
    await _refreshSemestersInBackground(
      username,
      password,
      state.activeSemesterId,
      state.activeSemesterName,
    );
  }

  Future<void> _refreshSemestersInBackground(
    String username,
    String password,
    String? currentSemId,
    String? currentSemName,
  ) async {
    try {
      final semData = await apiService.fetchSemesters(username, password);
      final rawSemesters = semData['semesters'] as List<dynamic>? ?? [];
      final semesters = rawSemesters.map((s) => {
        'id': s['id'].toString(),
        'name': s['name'].toString(),
      }).toList();

      if (semesters.isNotEmpty) {
        await StorageService.saveAvailableSemesters(semesters, username: username);
      }

      final resolvedSemId = currentSemId ?? (semesters.isNotEmpty ? semesters.first['id'] : null);
      final resolvedSemName = currentSemName ?? (semesters.isNotEmpty ? semesters.first['name'] : null);

      if (resolvedSemId != null && resolvedSemName != null) {
        await StorageService.saveSemester(resolvedSemId, resolvedSemName, username: username);
      }

      state = state.copyWith(
        availableSemesters: semesters.isNotEmpty ? semesters : state.availableSemesters,
        activeSemesterId: resolvedSemId,
        activeSemesterName: resolvedSemName,
      );
    } catch (_) {
      // Background failure is non-fatal - user already has access via cached semester
    }
  }

  /// Step 1: Initiates login via the /auth/login endpoint.
  /// Returns true if login is complete without OTP,
  /// returns false if OTP is required or if credentials failed.
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
        // VTOP sent an OTP challenge - set state and return false so caller checks otpRequired
        state = state.copyWith(
          isLoading: false,
          otpRequired: true,
          pendingSessionId: sessionId,
          username: username,
          password: password,
          errorMessage: null,
        );
        return false;
      }

      // OTP not required - finish login
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

  /// Step 2 (called from login OTP screen): Verifies OTP to complete initial login.
  Future<bool> verifyOtp(String otp) async {
    final sessionId = state.pendingSessionId;
    if (sessionId == null) {
      state = state.copyWith(errorMessage: 'No pending OTP session. Please login again.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await apiService.verifyLoginOtp(sessionId: sessionId, otp: otp);
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

  /// In-session OTP verification: validates OTP with VTOP to enable live data fetch
  /// without logging out or disturbing existing offline authentication state if cancelled or failed.
  Future<bool> verifyInSessionOtp(String otp) async {
    final sessionId = state.pendingSessionId;
    if (sessionId == null) {
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await apiService.verifyLoginOtp(sessionId: sessionId, otp: otp);
      final verifiedSid = apiService.vtopSessionId ?? sessionId;
      if (verifiedSid.isNotEmpty) {
        await StorageService.saveVtopSessionId(verifiedSid, username: state.username);
      }
      state = state.copyWith(
        isLoading: false,
        otpRequired: false,
        pendingSessionId: null,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyError(e.toString()),
      );
      return false;
    }
  }

  /// Step 3: Called when user picks their semester from SemesterSelectionScreen
  Future<void> selectSemesterAndEnter({
    required String username,
    required String password,
    required String semesterId,
    required String semesterName,
  }) async {
    await StorageService.saveCredentials(
      username: username,
      password: password,
      semesterId: semesterId,
      semesterName: semesterName,
    );

    final currentSid = apiService.vtopSessionId;
    if (currentSid != null && currentSid.isNotEmpty) {
      await StorageService.saveVtopSessionId(currentSid, username: username);
    }

    state = state.copyWith(
      isAuthenticated: true,
      isLoading: false,
      otpRequired: false,
      pendingSessionId: null,
      username: username,
      password: password,
      activeSemesterId: semesterId,
      activeSemesterName: semesterName,
      errorMessage: null,
    );
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

  /// Fetches semesters and marks fully authenticated.
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

      if (semesters.isNotEmpty) {
        await StorageService.saveAvailableSemesters(semesters, username: username);
      }

      final firstSem = semesters.isNotEmpty ? semesters.first : null;
      final semId = firstSem?['id'];
      final semName = firstSem?['name'];

      await StorageService.saveCredentials(
        username: username,
        password: password,
        semesterId: semId,
        semesterName: semName,
      );

      final currentSid = apiService.vtopSessionId;
      if (currentSid != null && currentSid.isNotEmpty) {
        await StorageService.saveVtopSessionId(currentSid, username: username);
      }

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
        errorMessage: null,
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
      return 'Invalid username or password. Please check your credentials.';
    }
    if (raw.contains('Invalid Captcha') || raw.contains('captcha') || raw.contains('Captcha')) {
      return 'VTOP captcha verification failed. Please try logging in again.';
    }
    if (raw.contains('OTP') && raw.contains('Incorrect')) {
      return 'Incorrect OTP. Please check the code sent to your email/phone.';
    }
    if (raw.contains('OTP') && raw.contains('expired')) {
      return 'OTP has expired. Please try logging in again.';
    }
    if (raw.contains('504') || raw.contains('Gateway Timeout') || raw.contains('timeout')) {
      return 'VTOP server took too long to respond. The university server may be slow. Please try again.';
    }
    if (raw.contains('Connection') || raw.contains('connect') || raw.contains('SocketException')) {
      return 'Unable to reach backend server. Please check your internet connection.';
    }
    return raw.replaceAll('Exception:', '').trim();
  }

  Future<void> changeSemester(String semesterId, String semesterName) async {
    await StorageService.saveSemester(semesterId, semesterName);
    state = state.copyWith(
      activeSemesterId: semesterId,
      activeSemesterName: semesterName,
    );
  }

  /// Updates saved VTOP credentials (e.g., when student changes their VTOP password)
  /// without wiping cached offline data.
  Future<void> updateSavedCredentials({
    required String username,
    required String password,
    String? semesterId,
    String? semesterName,
  }) async {
    final cleanUser = username.trim().toUpperCase();
    final cleanPass = password.trim();
    final targetSemId = semesterId ?? state.activeSemesterId;
    final targetSemName = semesterName ?? state.activeSemesterName;

    apiService.invalidateUserSession(state.username);
    apiService.invalidateUserSession(cleanUser);

    await StorageService.saveCredentials(
      username: cleanUser,
      password: cleanPass,
      semesterId: targetSemId,
      semesterName: targetSemName,
    );

    state = state.copyWith(
      isAuthenticated: true,
      username: cleanUser,
      password: cleanPass,
      activeSemesterId: targetSemId,
      activeSemesterName: targetSemName,
      errorMessage: null,
    );
  }

  Future<void> logout() async {
    apiService.invalidateUserSession(state.username);
    await StorageService.clearAll();
    state = const AuthState(isAuthenticated: false, isLoading: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});