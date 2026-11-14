import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../src/rust/api/vtop/vtop_client.dart';
import '../src/rust/api/vtop/vtop_errors.dart';
import '../src/rust/api/vtop_get_client.dart' as rust_api;
import 'rust_vtop_engine.dart';
import 'storage_service.dart';

class _CachedResponse {
  final dynamic data;
  final DateTime createdAt;

  const _CachedResponse({
    required this.data,
    required this.createdAt,
  });
}

/// Runs at most one operation at a time for a given key, handing every caller
/// that arrives while it is running the *same* future instead of starting a
/// second one. Prevents duplicate VTOP login POSTs and duplicate OTP emails.
class _SingleFlight<K, T> {
  Future<T>? _pending;
  K? _pendingKey;

  Future<T>? pendingFor(K key) =>
      _pending != null && _pendingKey == key ? _pending : null;

  bool get isRunning => _pending != null;

  Future<T> run(K key, Future<T> Function() operation) {
    final Future<T> future = operation();
    _pending = future;
    _pendingKey = key;

    return future.whenComplete(() {
      if (identical(_pending, future)) {
        _pending = null;
        _pendingKey = null;
      }
    });
  }

  void clear() {
    _pending = null;
    _pendingKey = null;
  }
}

class ApiClient {
  late final Dio dio;

  // Kept for diagnostics/compatibility
  static String get defaultBaseUrl => 'https://vitap-nexus-api.onrender.com';

  // ============================================================
  // ON-DEVICE RUST VTOP CLIENT & SINGLE-FLIGHT SESSION ENGINE
  // ============================================================

  /// Global callback invoked whenever VTOP requires an OTP to complete authentication or session renewal.
  /// Returns true if the user verified the OTP, or false if cancelled.
  static FutureOr<bool> Function(String sessionId)? onOtpRequired;

  /// Global callback invoked whenever VTOP rejects saved credentials during an active session
  /// (e.g., when the student changes their VTOP password on the web portal).
  /// Returns true if the user updated their password in the popup.
  static FutureOr<bool> Function(String username, String reason)?
      onCredentialsRejected;

  VtopClient? _rustClient;
  bool _isRustAuthenticated = false;
  bool _otpPending = false;
  String? _currentUsername;
  String? _currentPassword;
  DateTime? _sessionCreatedAt;
  int _generation = 0;
  String? _cachedUserAgent;

  final _SingleFlight<String, VtopClient> _loginFlight =
      _SingleFlight<String, VtopClient>();

  // VTOP sessions expire after 15 minutes; proactively refresh at 14 minutes
  static const Duration _sessionRefreshThreshold = Duration(minutes: 14);
  static const Duration _sessionExpiryDuration = Duration(minutes: 15);

  String? _vtopSessionId;

  String? get vtopSessionId => _vtopSessionId;

  bool get isOtpPending => _otpPending;

  bool get hasActiveRustSession =>
      _isRustAuthenticated &&
      _rustClient != null &&
      !_isSessionNearExpiry();

  bool _isSessionNearExpiry() {
    if (_sessionCreatedAt == null) return true;
    return DateTime.now().difference(_sessionCreatedAt!) >=
        _sessionRefreshThreshold;
  }

  bool _isSessionExpired() {
    if (_sessionCreatedAt == null) return true;
    return DateTime.now().difference(_sessionCreatedAt!) >=
        _sessionExpiryDuration;
  }

  bool _needsNewClient(String username, String password) {
    final cleanUser = username.trim().toUpperCase();
    return _rustClient == null ||
        !_isRustAuthenticated ||
        _currentUsername != cleanUser ||
        _currentPassword != password ||
        _isSessionNearExpiry();
  }

  String _loginKey(String username, String password) =>
      '${username.trim().toUpperCase()}:$password';

  Future<String> _resolveDeviceUserAgent() async {
    if (_cachedUserAgent != null) return _cachedUserAgent!;
    try {
      if (!kIsWeb) {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          _cachedUserAgent =
              'Mozilla/5.0 (Linux; Android ${androidInfo.version.release}; '
              '${androidInfo.model}) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
          return _cachedUserAgent!;
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          _cachedUserAgent =
              'Mozilla/5.0 (${iosInfo.model}; CPU iPhone OS '
              '${iosInfo.systemVersion.replaceAll('.', '_')} like Mac OS X) '
              'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
              'Mobile/15E148 Safari/604.1';
          return _cachedUserAgent!;
        }
      }
    } catch (e) {
      debugPrint('ApiClient: Failed to resolve device user agent: $e');
    }
    _cachedUserAgent =
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
    return _cachedUserAgent!;
  }

  String _formatVtopError(Object error) {
    if (error is VtopError_InvalidCredentials) {
      return 'Invalid registration number or password.';
    }
    if (error is VtopError_AuthenticationFailed) {
      return error.field0.isNotEmpty
          ? error.field0
          : 'Authentication failed on VTOP.';
    }
    if (error is VtopError_RegistrationParsingError) {
      return 'Invalid registration number format.';
    }
    if (error is VtopError_LoginOtpRequired) {
      return 'OTP verification is required to continue.';
    }
    if (error is VtopError_LoginOtpIncorrect) {
      return 'Incorrect OTP code. Please check your email and try again.';
    }
    if (error is VtopError_LoginOtpExpired) {
      return 'This OTP has expired. Tap Resend OTP to get a fresh code.';
    }
    if (error is VtopError_SessionExpired) {
      return 'Your VTOP session expired. Reconnecting...';
    }
    if (error is VtopError_NetworkError || error is VtopError_DnsError) {
      return 'Network unreachable. Please check your internet connection.';
    }
    if (error is VtopError_TimeoutError) {
      return 'VTOP took too long to respond. Please try again.';
    }
    if (error is VtopError_ConnectionRefused ||
        error is VtopError_VtopServerError) {
      return 'VTOP server is temporarily unavailable. Please try again shortly.';
    }
    if (error is VtopError_MenuUnavailable) {
      return 'This menu is currently disabled on the VTOP portal.';
    }
    if (error is VtopError_OutingFormUnavailable) {
      return error.field0.isNotEmpty
          ? error.field0
          : 'Outing application form is currently closed on VTOP.';
    }
    if (error is VtopError_ParseError) {
      return error.field0.isNotEmpty
          ? error.field0
          : 'Unable to read response from VTOP.';
    }
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('StateError: ', '');
  }

  /// Gets or creates an authenticated on-device Rust VtopClient.
  /// Shares a single in-flight login across all concurrent callers.
  Future<VtopClient> getOrAuthenticateClient({
    required String username,
    required String password,
  }) {
    final cleanUser = username.trim().toUpperCase();
    if (!_needsNewClient(cleanUser, password)) {
      return Future<VtopClient>.value(_rustClient!);
    }

    final key = _loginKey(cleanUser, password);
    final joined = _loginFlight.pendingFor(key);
    if (joined != null) {
      return joined;
    }

    if (_loginFlight.isRunning && !_otpPending) {
      resetRustClient();
    }

    final int generation = ++_generation;
    return _loginFlight.run(
      key,
      () => _initializeRustClient(
        username: cleanUser,
        password: password,
        generation: generation,
      ),
    );
  }

  Future<VtopClient> _initializeRustClient({
    required String username,
    required String password,
    required int generation,
  }) async {
    await RustVtopEngine.init();
    final userAgent = await _resolveDeviceUserAgent();

    try {
      final client = rust_api.getVtopClient(
        username: username,
        password: password,
        userAgent: userAgent,
      );
      _rustClient = client;
      _currentUsername = username;
      _currentPassword = password;

      await rust_api.vtopClientLogin(client: client);

      if (_generation != generation) {
        throw Exception('Session was superseded during login.');
      }

      _otpPending = false;
      _isRustAuthenticated = true;
      _sessionCreatedAt = DateTime.now();
      final sid = 'rust_session_${_sessionCreatedAt!.millisecondsSinceEpoch}';
      setVtopSessionId(sid);
      await StorageService.saveVtopSessionId(sid, username: username);
      debugPrint('ApiClient (Rust): Authenticated directly on-device ($sid)');
      return client;
    } on VtopError_LoginOtpRequired {
      if (_generation != generation) {
        throw Exception('Session was superseded during login.');
      }

      _otpPending = true;
      _isRustAuthenticated = false;
      final sid = 'rust_otp_${DateTime.now().millisecondsSinceEpoch}';
      _vtopSessionId = sid;

      debugPrint(
        'ApiClient (Rust): VTOP requested email OTP ($sid). Invoking onOtpRequired...',
      );

      if (onOtpRequired != null) {
        final verified = await onOtpRequired!(sid);
        if (verified && _isRustAuthenticated && _rustClient != null) {
          final verifiedSid = _vtopSessionId ?? sid;
          await StorageService.saveVtopSessionId(
            verifiedSid,
            username: username,
          );
          return _rustClient!;
        }
      }

      _clearRustSessionIfCurrent(generation);
      throw Exception('OTP verification is required to sync with VTOP.');
    } catch (e) {
      final formatted = _formatVtopError(e);
      final lower = formatted.toLowerCase();
      final isCredsRejected = e is VtopError_InvalidCredentials ||
          (e is VtopError_AuthenticationFailed &&
              (lower.contains('invalid') ||
                  lower.contains('password') ||
                  lower.contains('credential') ||
                  lower.contains('authorized'))) ||
          lower.contains('invalid username or password') ||
          lower.contains('invalid credentials');

      if (isCredsRejected && onCredentialsRejected != null) {
        _clearRustSessionIfCurrent(generation);
        final updated = await onCredentialsRejected!(username, formatted);
        if (updated) {
          final latestCreds = await StorageService.getCredentials();
          final newUser =
              (latestCreds['username'] ?? username).trim().toUpperCase();
          final newPass = latestCreds['password'] ?? '';
          if (newPass.isNotEmpty && newPass != password) {
            final nextGen = ++_generation;
            return _initializeRustClient(
              username: newUser,
              password: newPass,
              generation: nextGen,
            );
          }
        }
      }

      _clearRustSessionIfCurrent(generation);
      throw Exception(formatted);
    }
  }

  bool _clearRustSessionIfCurrent(int generation) {
    if (_generation != generation) return false;
    _isRustAuthenticated = false;
    _otpPending = false;
    _rustClient = null;
    _sessionCreatedAt = null;
    return true;
  }

  void resetRustClient() {
    _generation++;
    _rustClient = null;
    _isRustAuthenticated = false;
    _otpPending = false;
    _sessionCreatedAt = null;
    _loginFlight.clear();
  }

  /// Executes a Rust VTOP operation with automatic retry on session expiry
  /// and in-memory response caching.
  Future<T> _executeRust<T>({
    required String username,
    required String password,
    required String cachePath,
    Map<String, dynamic>? cacheParams,
    required Future<T> Function(VtopClient client) operation,
    int maxRetries = 2,
  }) async {
    final cleanUser = username.trim().toUpperCase();
    final bool cacheable = _isCacheable(cachePath);
    final String cacheKey =
        '$cleanUser|$cachePath|${cacheParams != null ? jsonEncode(cacheParams) : ''}';

    if (cacheable) {
      final cached = _responseCache[cacheKey];
      if (cached != null) {
        if (DateTime.now().difference(cached.createdAt) <= _cacheTtl) {
          debugPrint('CACHE HIT (Rust) → $cachePath');
          return cached.data as T;
        }
        _responseCache.remove(cacheKey);
      }
    }

    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        attempts++;
        final savedPass = StorageService.getCredentialsSync()['password'];
        final activePass =
            (savedPass != null && savedPass.isNotEmpty) ? savedPass : password;
        final client = await getOrAuthenticateClient(
          username: cleanUser,
          password: activePass,
        );
        final result = await operation(client);

        if (cacheable && result != null) {
          _responseCache[cacheKey] = _CachedResponse(
            data: result,
            createdAt: DateTime.now(),
          );
        }
        return result;
      } catch (e) {
        final isSessionExpired = e is VtopError_SessionExpired ||
            e.toString().toLowerCase().contains('session expired');
        if (attempts < maxRetries && isSessionExpired && !_otpPending) {
          debugPrint(
            'ApiClient (Rust): Session expired on $cachePath, renewing & retrying...',
          );
          resetRustClient();
          await Future<void>.delayed(const Duration(milliseconds: 300));
          continue;
        }
        throw Exception(_formatVtopError(e));
      }
    }
    throw Exception('Unable to complete VTOP request after retries.');
  }

  /// Single-flight session renewal / establishment shared across providers.
  Future<bool> ensureSession(String username, String password) async {
    try {
      await getOrAuthenticateClient(username: username, password: password);
      return _isRustAuthenticated && _rustClient != null;
    } catch (e) {
      debugPrint('ApiClient.ensureSession note: $e');
      return false;
    }
  }

  /// Returns cookies, CSRF token, authorizedId, and User-Agent directly from the
  /// authenticated on-device Rust VTOP session so the in-app WebView can open
  /// `https://vtop.vitap.ac.in/vtop/content` directly with zero proxy!
  Future<Map<String, String>> getWebViewSessionData({
    required String username,
    required String password,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      resetRustClient();
    }
    final client = await getOrAuthenticateClient(
      username: username,
      password: password,
    );
    final isAuth = await rust_api.fetchIsAuth(client: client);
    if (!isAuth) {
      resetRustClient();
      final freshClient = await getOrAuthenticateClient(
        username: username,
        password: password,
      );
      return _extractWebViewSessionData(freshClient);
    }
    return _extractWebViewSessionData(client);
  }

  Future<Map<String, String>> _extractWebViewSessionData(
    VtopClient client,
  ) async {
    final cookieBytes = await rust_api.fetchCookies(client: client);
    final cookieString = String.fromCharCodes(cookieBytes);
    final csrfToken = await rust_api.fetchCsrfToken(client: client) ?? '';
    final authorizedId = await rust_api.fetchUsername(client: client);
    final userAgent = await rust_api.fetchUserAgent(client: client);

    return {
      'cookies': cookieString,
      'csrf_token': csrfToken,
      'authorized_id': authorizedId,
      'user_agent': userAgent,
    };
  }

  // ============================================================
  // IN-MEMORY RESPONSE CACHE
  // ============================================================

  static const Duration _cacheTtl = Duration(minutes: 5);

  final Map<String, _CachedResponse> _responseCache = {};

  String? _lastWarmUpKey;

  static const Set<String> _cacheablePaths = {
    '/student/semesters',
    '/student/all_data',
    '/student/profile',
    '/student/attendance',
    '/student/attendance_detail',
    '/student/timetable',
    '/student/exam_schedule',
    '/student/marks',
    '/student/grade_history',
    '/student/mentor',
    '/student/biometric',
    '/student/pending_payments',
    '/student/payment_receipts',
    '/student/course_page_courses',
    '/student/course_page_slots',
    '/student/course_detail',
    '/student/digital_assignments',
    '/student/course_assignments',
  };

  bool _isCacheable(String path) => _cacheablePaths.contains(path);

  void clearDataCache() {
    _responseCache.clear();
    debugPrint('VTOP data cache cleared');
  }

  void warmUpCommonScreens({
    required String username,
    required String password,
    required String semSubId,
  }) {
    final sessionId = _vtopSessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    final warmUpKey = '$username|$sessionId|$semSubId';
    if (_lastWarmUpKey == warmUpKey) return;
    _lastWarmUpKey = warmUpKey;

    unawaited(
      _warmUpCommonScreens(
        username: username,
        password: password,
        semSubId: semSubId,
      ),
    );
  }

  Future<void> _warmUpCommonScreens({
    required String username,
    required String password,
    required String semSubId,
  }) async {
    debugPrint('VTOP warm-up started (on-device Rust)');
    await Future.wait<void>([
      fetchPendingPayments(
        username: username,
        password: password,
      ).then((_) {}, onError: (_) {}),
      fetchPaymentReceipts(
        username: username,
        password: password,
      ).then((_) {}, onError: (_) {}),
      fetchCoursePageCourses(
        username: username,
        password: password,
        semSubId: semSubId,
      ).then((_) {}, onError: (_) {}),
      fetchDigitalAssignments(
        username: username,
        password: password,
        semSubId: semSubId,
      ).then((_) {}, onError: (_) {}),
    ]);
    debugPrint('VTOP warm-up finished');
  }

  void setVtopSessionId(String sessionId) {
    if (_vtopSessionId != sessionId) {
      clearDataCache();
      _lastWarmUpKey = null;
    }
    _vtopSessionId = sessionId;
  }

  Future<void> restoreSessionFromStorage({String? username}) async {
    // Only mark session ID if our in-memory Rust client is actually alive
    if (_isRustAuthenticated && _rustClient != null && !_isSessionExpired()) {
      return;
    }
    try {
      final saved =
          await StorageService.getVtopSessionId(username: username) ??
          await StorageService.getVtopSessionId();
      if (saved != null &&
          saved.isNotEmpty &&
          _isRustAuthenticated &&
          _rustClient != null) {
        setVtopSessionId(saved);
      }
    } catch (_) {}
  }

  void clearVtopSessionId() {
    _vtopSessionId = null;
    _lastWarmUpKey = null;
    resetRustClient();
    clearDataCache();
    debugPrint('VTOP session cleared locally');
  }

  Future<void> logout(String? sessionId) async {
    clearVtopSessionId();
  }

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  ApiClient({String? baseUrl}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? defaultBaseUrl,
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 25),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  // ============================================================
  // AUTH / OTP (ON-DEVICE RUST)
  // ============================================================

  /// Step 1: Initiates VTOP login directly on-device via Rust lib_vtop.
  Future<Map<String, dynamic>> initiateLogin({
    required String username,
    required String password,
  }) async {
    await RustVtopEngine.init();
    final cleanUser = username.trim().toUpperCase();
    final userAgent = await _resolveDeviceUserAgent();
    final int generation = ++_generation;

    try {
      final client = rust_api.getVtopClient(
        username: cleanUser,
        password: password,
        userAgent: userAgent,
      );
      _rustClient = client;
      _currentUsername = cleanUser;
      _currentPassword = password;

      await rust_api.vtopClientLogin(client: client);

      _otpPending = false;
      _isRustAuthenticated = true;
      _sessionCreatedAt = DateTime.now();
      final sid = 'rust_session_${_sessionCreatedAt!.millisecondsSinceEpoch}';
      setVtopSessionId(sid);

      return {
        'session_id': sid,
        'otp_required': false,
        'message': 'Authenticated directly with VTOP.',
      };
    } on VtopError_LoginOtpRequired {
      _otpPending = true;
      _isRustAuthenticated = false;
      final sid = 'rust_otp_${DateTime.now().millisecondsSinceEpoch}';
      _vtopSessionId = sid;

      return {
        'session_id': sid,
        'otp_required': true,
        'message': 'An OTP has been sent to your registered email.',
      };
    } catch (e) {
      _clearRustSessionIfCurrent(generation);
      throw Exception(_formatVtopError(e));
    }
  }

  /// Step 2: Verify OTP on the SAME on-device Rust VtopClient session.
  Future<Map<String, dynamic>> verifyLoginOtp({
    required String sessionId,
    required String otp,
  }) async {
    final client = _rustClient;
    if (client == null) {
      throw Exception('No active OTP session found. Please try again.');
    }

    try {
      await rust_api.handleLoginOtp(client: client, otpCode: otp.trim());
      _otpPending = false;
      _isRustAuthenticated = true;
      _sessionCreatedAt = DateTime.now();
      final verifiedSid =
          'rust_verified_${_sessionCreatedAt!.millisecondsSinceEpoch}';
      setVtopSessionId(verifiedSid);

      return {
        'session_id': verifiedSid,
        'verified': true,
        'message': 'OTP verified successfully.',
      };
    } catch (e) {
      throw Exception(_formatVtopError(e));
    }
  }

  /// Resend OTP on the current on-device Rust VtopClient session.
  Future<void> resendLoginOtp(String sessionId) async {
    final client = _rustClient;
    if (client == null) {
      throw Exception('No active OTP session found. Please login again.');
    }
    try {
      await rust_api.handleLoginOtpResend(client: client);
    } catch (e) {
      throw Exception(_formatVtopError(e));
    }
  }

  // ============================================================
  // SEMESTERS
  // ============================================================

  Future<Map<String, dynamic>> fetchSemesters(
    String username,
    String password,
  ) async {
    return _executeRust<Map<String, dynamic>>(
      username: username,
      password: password,
      cachePath: '/student/semesters',
      operation: (client) async {
        final semData = await rust_api.fetchSemesters(client: client);
        return {
          'semesters': semData.semesters
              .map((s) => {'id': s.id, 'name': s.name})
              .toList(),
          'update_time': semData.updateTime.toInt(),
        };
      },
    );
  }

  // ============================================================
  // ACADEMIC CALENDAR
  // ============================================================

  Future<Map<String, dynamic>> fetchAcademicCalendar({
    required String username,
    required String password,
    String? semSubId,
    String? classGroupId,
  }) async {
    return _executeRust<Map<String, dynamic>>(
      username: username,
      password: password,
      cachePath: '/student/academic_calendar',
      cacheParams: {'sem_sub_id': semSubId, 'class_group_id': classGroupId},
      operation: (client) async {
        String resolvedSemId = semSubId ?? '';
        if (resolvedSemId.isEmpty) {
          final sems = await rust_api.fetchSemesters(client: client);
          if (sems.semesters.isNotEmpty) {
            resolvedSemId = sems.semesters.first.id;
          }
        }
        String resolvedGroup =
            (classGroupId != null && classGroupId.isNotEmpty)
            ? classGroupId
            : 'COMB';
        try {
          final groupsJson = await rust_api.fetchCalendarClassGroups(
            client: client,
            semesterId: resolvedSemId,
          );
          final groups = jsonDecode(groupsJson);
          if (groups is List && groups.isNotEmpty && classGroupId == null) {
            final firstGroup = groups.first;
            if (firstGroup is Map && firstGroup['id'] != null) {
              resolvedGroup = firstGroup['id'].toString();
            }
          }
        } catch (_) {}

        final rawJson = await rust_api.fetchAcademicCalendar(
          client: client,
          semesterId: resolvedSemId,
          classGroupId: resolvedGroup,
        );
        final decoded = jsonDecode(rawJson);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
        return {};
      },
    );
  }

  // ============================================================
  // ALL DATA (COMPREHENSIVE BUNDLE)
  // ============================================================

  Future<Map<String, dynamic>> fetchAllData({
    required String username,
    required String password,
    required String semSubId,
  }) async {
    return _executeRust<Map<String, dynamic>>(
      username: username,
      password: password,
      cachePath: '/student/all_data',
      cacheParams: {'sem_sub_id': semSubId},
      operation: (client) async {
        try {
          final rawJson = await rust_api.fetchAllData(
            client: client,
            semesterId: semSubId,
          );
          final decoded = jsonDecode(rawJson);
          if (decoded is Map) {
            final map = Map<String, dynamic>.from(decoded);
            final profile = map['profile'];
            if (profile is Map) {
              map['grade_history'] ??= profile['grade_history'];
              map['mentor_details'] ??= profile['mentor_details'];
            }
            if (map['timetable'] is Map) {
              map['timetable'] = _normalizeTimetableMap(
                Map<String, dynamic>.from(map['timetable'] as Map),
              );
            }
            if (map['marks'] is List) {
              map['marks'] = await _mergeGradeViewIntoMarks(
                client: client,
                semSubId: semSubId,
                marksList: List<dynamic>.from(map['marks'] as List),
              );
            }
            return map;
          }
        } on VtopError_SessionExpired {
          rethrow;
        } catch (e) {
          debugPrint(
            'ApiClient (Rust): fetchAllData bundle partial error ($e), fetching sections individually...',
          );
        }

        // Resilient individual section assembly if one sub-endpoint (e.g. exam schedule) had an error
        Map<String, dynamic>? profileMap;
        List<dynamic>? attendanceList;
        Map<String, dynamic>? timetableMap;
        List<dynamic>? marksList;
        List<dynamic>? examScheduleList;
        Map<String, dynamic>? gradeHistoryMap;

        try {
          final pJson = await rust_api.fetchStudentProfile(client: client);
          final pDec = jsonDecode(pJson);
          if (pDec is Map) {
            profileMap = Map<String, dynamic>.from(pDec);
            if (profileMap['grade_history'] is Map) {
              gradeHistoryMap = Map<String, dynamic>.from(
                profileMap['grade_history'] as Map,
              );
            }
          }
        } on VtopError_SessionExpired {
          rethrow;
        } catch (_) {}

        try {
          final aJson = await rust_api.fetchAttendanceWithCapstone(
            client: client,
            semesterId: semSubId,
          );
          final aDec = jsonDecode(aJson);
          if (aDec is Map) {
            if (aDec['records'] is List) {
              attendanceList = List<dynamic>.from(aDec['records'] as List);
            }
            if (aDec['capstone'] is Map) {
              await StorageService.setCache(
                'capstone_attendance',
                Map<String, dynamic>.from(aDec['capstone'] as Map),
                username: username,
                semesterId: semSubId,
              );
              await StorageService.setCache(
                'capstone_attendance',
                Map<String, dynamic>.from(aDec['capstone'] as Map),
                username: username,
              );
            }
          } else if (aDec is List) {
            attendanceList = aDec;
          }
        } on VtopError_SessionExpired {
          rethrow;
        } catch (_) {}

        try {
          final tJson = await rust_api.fetchTimetable(
            client: client,
            semesterId: semSubId,
          );
          final tDec = jsonDecode(tJson);
          if (tDec is Map) {
            timetableMap = _normalizeTimetableMap(
              Map<String, dynamic>.from(tDec),
            );
          }
        } on VtopError_SessionExpired {
          rethrow;
        } catch (_) {}

        try {
          final mJson = await rust_api.fetchMarks(
            client: client,
            semesterId: semSubId,
          );
          final mDec = jsonDecode(mJson);
          if (mDec is List) {
            marksList = await _mergeGradeViewIntoMarks(
              client: client,
              semSubId: semSubId,
              marksList: mDec,
            );
          }
        } on VtopError_SessionExpired {
          rethrow;
        } catch (_) {}

        try {
          final eJson = await rust_api.fetchExamShedule(
            client: client,
            semesterId: semSubId,
          );
          final eDec = jsonDecode(eJson);
          if (eDec is List) examScheduleList = eDec;
        } on VtopError_SessionExpired {
          rethrow;
        } catch (_) {}

        return {
          'profile': profileMap,
          'attendance': attendanceList,
          'timetable': timetableMap,
          'marks': marksList,
          'exam_schedule': examScheduleList,
          'grade_history': gradeHistoryMap,
          'mentor_details': profileMap?['mentor_details'],
        };
      },
    );
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Future<Map<String, dynamic>> fetchProfile(
    String username,
    String password,
  ) async {
    return _executeRust<Map<String, dynamic>>(
      username: username,
      password: password,
      cachePath: '/student/profile',
      operation: (client) async {
        final rawJson = await rust_api.fetchStudentProfile(client: client);
        final decoded = jsonDecode(rawJson);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
        return {};
      },
    );
  }

  // ============================================================
  // ATTENDANCE
  // ============================================================

  Future<List<dynamic>> fetchAttendance({
    required String username,
    required String password,
    required String semSubId,
  }) async {
    return _executeRust<List<dynamic>>(
      username: username,
      password: password,
      cachePath: '/student/attendance',
      cacheParams: {'sem_sub_id': semSubId},
      operation: (client) async {
        try {
          final rawJson = await rust_api.fetchAttendanceWithCapstone(
            client: client,
            semesterId: semSubId,
          );
          final decoded = jsonDecode(rawJson);
          if (decoded is Map) {
            final capstone = decoded['capstone'];
            if (capstone is Map) {
              final capMap = Map<String, dynamic>.from(capstone);
              await StorageService.setCache(
                'capstone_attendance',
                capMap,
                username: username,
                semesterId: semSubId,
              );
              await StorageService.setCache(
                'capstone_attendance',
                capMap,
                username: username,
              );
            }
            if (decoded['records'] is List) {
              return List<dynamic>.from(decoded['records'] as List);
            }
          }
          if (decoded is List) return decoded;
        } on VtopError_SessionExpired {
          rethrow;
        } catch (_) {}

        final rawJson = await rust_api.fetchAttendance(
          client: client,
          semesterId: semSubId,
        );
        final decoded = jsonDecode(rawJson);
        if (decoded is List) return decoded;
        return [];
      },
    );
  }

  // ============================================================
  // ATTENDANCE DETAIL (PER COURSE / DAY-WISE)
  // ============================================================

  Future<List<dynamic>> fetchAttendanceDetail({
    required String username,
    required String password,
    required String semSubId,
    required String courseId,
    required String courseType,
  }) async {
    return _executeRust<List<dynamic>>(
      username: username,
      password: password,
      cachePath: '/student/attendance_detail',
      cacheParams: {
        'sem_sub_id': semSubId,
        'course_id': courseId,
        'course_type': courseType,
      },
      operation: (client) async {
        final rawJson = await rust_api.fetchAttendanceDetail(
          client: client,
          semesterId: semSubId,
          courseId: courseId,
          courseType: courseType,
        );
        final decoded = jsonDecode(rawJson);
        if (decoded is List) return decoded;
        return [];
      },
    );
  }

  // ============================================================
  // TIMETABLE
  // ============================================================

  Map<String, dynamic> _normalizeTimetableMap(Map<String, dynamic> raw) {
    final normalized = <String, dynamic>{};
    for (final entry in raw.entries) {
      final val = entry.value;
      if (val is List) {
        normalized[entry.key] = val.map((item) {
          if (item is! Map) return item;
          final map = Map<String, dynamic>.from(item);
          final rawSlot = (map['slot'] ?? '').toString().trim();
          var cleanSlot = rawSlot;
          while (cleanSlot.endsWith('-')) {
            cleanSlot = cleanSlot.substring(0, cleanSlot.length - 1).trim();
          }
          map['slot'] = cleanSlot;
          final startTime = (map['start_time'] ?? '').toString().trim();
          final endTime = (map['end_time'] ?? '').toString().trim();
          if ((map['time'] == null || map['time'].toString().trim().isEmpty) &&
              startTime.isNotEmpty &&
              startTime != '-') {
            map['time'] = endTime.isNotEmpty && endTime != '-'
                ? '$startTime - $endTime'
                : startTime;
          }
          return map;
        }).toList();
      } else {
        normalized[entry.key] = val;
      }
    }
    return normalized;
  }

  Future<Map<String, dynamic>> fetchTimetable({
    required String username,
    required String password,
    required String semSubId,
  }) async {
    return _executeRust<Map<String, dynamic>>(
      username: username,
      password: password,
      cachePath: '/student/timetable',
      cacheParams: {'sem_sub_id': semSubId},
      operation: (client) async {
        final rawJson = await rust_api.fetchTimetable(
          client: client,
          semesterId: semSubId,
        );
        final decoded = jsonDecode(rawJson);
        if (decoded is Map) {
          return _normalizeTimetableMap(Map<String, dynamic>.from(decoded));
        }
        return {};
      },
    );
  }

  // ============================================================
  // EXAM SCHEDULE
  // ============================================================

  Future<dynamic> fetchExamSchedule({
    required String username,
    required String password,
    required String semSubId,
  }) async {
    return _executeRust<dynamic>(
      username: username,
      password: password,
      cachePath: '/student/exam_schedule',
      cacheParams: {'sem_sub_id': semSubId},
      operation: (client) async {
        final rawJson = await rust_api.fetchExamShedule(
          client: client,
          semesterId: semSubId,
        );
        return jsonDecode(rawJson);
      },
    );
  }

  // ============================================================
  // MARKS & GRADE VIEW
  // ============================================================

  Future<List<dynamic>> _mergeGradeViewIntoMarks({
    required VtopClient client,
    required String semSubId,
    required List<dynamic> marksList,
  }) async {
    if (marksList.isEmpty || semSubId.isEmpty) return marksList;
    try {
      final gradeViewJson = await rust_api.fetchGradeView(
        client: client,
        semesterId: semSubId,
      );
      final gradeCourses = jsonDecode(gradeViewJson);
      if (gradeCourses is List && gradeCourses.isNotEmpty) {
        final byCode = <String, Map<String, dynamic>>{};
        for (final c in gradeCourses) {
          if (c is Map) {
            final map = Map<String, dynamic>.from(c);
            final code = (map['course_code'] ?? '').toString().trim();
            if (code.isNotEmpty) {
              byCode[code] = map;
            }
          }
        }
        return marksList.map((m) {
          if (m is! Map) return m;
          final markMap = Map<String, dynamic>.from(m);
          final code = (markMap['course_code'] ?? '').toString().trim();
          final match = byCode[code];
          if (match != null) {
            final g = (match['grade'] ?? '').toString().trim();
            final gt = (match['grand_total'] ?? '').toString().trim();
            final cid = (match['course_id'] ?? '').toString().trim();
            if (g.isNotEmpty && g != '-') markMap['grade'] = g;
            if (gt.isNotEmpty && gt != '-') markMap['grand_total'] = gt;
            if (cid.isNotEmpty) markMap['grade_course_id'] = cid;
          }
          return markMap;
        }).toList();
      }
    } catch (_) {
      // Grade view fetch is non-fatal (e.g. mid-semester when grades aren't published)
    }
    return marksList;
  }

  Future<List<dynamic>> fetchMarks({
    required String username,
    required String password,
    required String semSubId,
  }) async {
    return _executeRust<List<dynamic>>(
      username: username,
      password: password,
      cachePath: '/student/marks',
      cacheParams: {'sem_sub_id': semSubId},
      operation: (client) async {
        final rawJson = await rust_api.fetchMarks(
          client: client,
          semesterId: semSubId,
        );
        final decoded = jsonDecode(rawJson);
        List<dynamic> list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map && decoded['marks'] is List) {
          list = decoded['marks'] as List<dynamic>;
        }
        return _mergeGradeViewIntoMarks(
          client: client,
          semSubId: semSubId,
          marksList: list,
        );
      },
    );
  }

  Future<Map<String, dynamic>> fetchGradeViewDetail({
    required String username,
    required String password,
    required String semSubId,
    required String courseId,
  }) async {
    return _executeRust<Map<String, dynamic>>(
      username: username,
      password: password,
      cachePath: '/student/grade_view_detail',
      cacheParams: {'sem_sub_id': semSubId, 'course_id': courseId},
      operation: (client) async {
        final rawJson = await rust_api.fetchGradeViewDetail(
          client: client,
          semesterId: semSubId,
          courseId: courseId,
        );
        final decoded = jsonDecode(rawJson);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
        return {};
      },
    );
  }

  // ============================================================
  // GRADE HISTORY
  // ============================================================

  Future<Map<String, dynamic>> fetchGradeHistory({
    required String username,
    required String password,
  }) async {
    return _executeRust<Map<String, dynamic>>(
      username: username,
      password: password,
      cachePath: '/student/grade_history',
      operation: (client) async {
        final gh = await rust_api.fetchGradeHistory(client: client);
        return {
          'credits_registered': gh.creditsRegistered,
          'credits_earned': gh.creditsEarned,
          'cgpa': gh.cgpa,
          'courses': gh.courses
              .map(
                (c) => {
                  'course_code': c.courseCode,
                  'course_title': c.courseTitle,
                  'course_type': c.courseType,
                  'credits': c.credits,
                  'grade': c.grade,
                  'exam_month': c.examMonth,
                  'course_distribution': c.courseDistribution,
                },
              )
              .toList(),
        };
      },
    );
  }

  // ============================================================
  // MENTOR
  // ============================================================

  Future<Map<String, dynamic>> fetchMentor({
    required String username,
    required String password,
  }) async {
    return _executeRust<Map<String, dynamic>>(
      username: username,
      password: password,
      cachePath: '/student/mentor',
      operation: (client) async {
        final rawJson = await rust_api.fetchStudentProfile(client: client);
        final decoded = jsonDecode(rawJson);
        if (decoded is Map && decoded['mentor_details'] is Map) {
          return Map<String, dynamic>.from(decoded['mentor_details'] as Map);
        }
        return {};
      },
    );
  }

  // ============================================================
  // BIOMETRIC
  // ============================================================

  Future<List<dynamic>> fetchBiometric({
    required String username,
    required String password,
    required String date,
  }) async {
    return _executeRust<List<dynamic>>(
      username: username,
      password: password,
      cachePath: '/student/biometric',
      cacheParams: {'date': date},
      operation: (client) async {
        final rawJson = await rust_api.fetchBiometricData(
          client: client,
          date: date,
        );
        final decoded = jsonDecode(rawJson);
        if (decoded is List) return decoded;
        return [];
      },
    );
  }

  // ============================================================
  // OUTINGS
  // ============================================================

  Future<dynamic> fetchGeneralOutings({
    required String username,
    required String password,
  }) async {
    return _executeRust<dynamic>(
      username: username,
      password: password,
      cachePath: '/student/general_outing_requests',
      operation: (client) async {
        final rawJson = await rust_api.fetchGeneralOutingReports(
          client: client,
        );
        return jsonDecode(rawJson);
      },
    );
  }

  Future<dynamic> fetchWeekendOutings({
    required String username,
    required String password,
  }) async {
    return _executeRust<dynamic>(
      username: username,
      password: password,
      cachePath: '/student/weekend_outing_requests',
      operation: (client) async {
        final rawJson = await rust_api.fetchWeekendOutingReports(
          client: client,
        );
        return jsonDecode(rawJson);
      },
    );
  }

  Future<String> submitGeneralOuting({
    required String username,
    required String password,
    required String outPlace,
    required String purposeOfVisit,
    required String outingDate,
    required String outTime,
    required String inDate,
    required String inTime,
  }) async {
    final msg = await _executeRust<String>(
      username: username,
      password: password,
      cachePath: '/student/submit_general_outing',
      operation: (client) => rust_api.submitGeneralOutingForm(
        client: client,
        outPlace: outPlace,
        purposeOfVisit: purposeOfVisit,
        outingDate: outingDate,
        outTime: outTime,
        inDate: inDate,
        inTime: inTime,
      ),
    );
    clearDataCache();
    return msg.isNotEmpty ? msg : 'General outing applied successfully.';
  }

  Future<String> submitWeekendOuting({
    required String username,
    required String password,
    required String outPlace,
    required String purposeOfVisit,
    required String outingDate,
    required String outTime,
    required String contactNumber,
  }) async {
    final msg = await _executeRust<String>(
      username: username,
      password: password,
      cachePath: '/student/submit_weekend_outing',
      operation: (client) => rust_api.submitWeekendOutingForm(
        client: client,
        outPlace: outPlace,
        purposeOfVisit: purposeOfVisit,
        outingDate: outingDate,
        outTime: outTime,
        contactNumber: contactNumber,
      ),
    );
    clearDataCache();
    return msg.isNotEmpty ? msg : 'Weekend outing applied successfully.';
  }

  Future<String> deleteGeneralOuting({
    required String username,
    required String password,
    required String leaveId,
  }) async {
    final msg = await _executeRust<String>(
      username: username,
      password: password,
      cachePath: '/student/delete_general_outing',
      operation: (client) =>
          rust_api.deleteGeneralOuting(client: client, leaveId: leaveId),
    );
    clearDataCache();
    return msg.isNotEmpty ? msg : 'Outing deleted.';
  }

  Future<String> deleteWeekendOuting({
    required String username,
    required String password,
    required String bookingId,
  }) async {
    final msg = await _executeRust<String>(
      username: username,
      password: password,
      cachePath: '/student/delete_weekend_outing',
      operation: (client) =>
          rust_api.deleteWeekendOuting(client: client, bookingId: bookingId),
    );
    clearDataCache();
    return msg.isNotEmpty ? msg : 'Weekend outing deleted.';
  }

  // ============================================================
  // PAYMENTS
  // ============================================================

  Future<List<dynamic>> fetchPendingPayments({
    required String username,
    required String password,
  }) async {
    return _executeRust<List<dynamic>>(
      username: username,
      password: password,
      cachePath: '/student/pending_payments',
      operation: (client) async {
        final rawJson = await rust_api.fetchPendingPayments(client: client);
        final decoded = jsonDecode(rawJson);
        if (decoded is List) return decoded;
        return [];
      },
    );
  }

  Future<List<dynamic>> fetchPaymentReceipts({
    required String username,
    required String password,
  }) async {
    return _executeRust<List<dynamic>>(
      username: username,
      password: password,
      cachePath: '/student/payment_receipts',
      operation: (client) async {
        final rawJson = await rust_api.fetchPaymentReceipts(client: client);
        final decoded = jsonDecode(rawJson);
        if (decoded is List) return decoded;
        return [];
      },
    );
  }

  Future<String> downloadPaymentReceipt({
    required String username,
    required String password,
    required String receiptNo,
    required String applicationNumber,
  }) async {
    return _executeRust<String>(
      username: username,
      password: password,
      cachePath: '/student/download_payment_receipt',
      operation: (client) => rust_api.studentPaymentReceiptDownload(
        client: client,
        receiptNo: receiptNo,
        applno: applicationNumber,
      ),
    );
  }

  // ============================================================
  // COURSE PAGE
  // ============================================================

  Future<Map<String, dynamic>> fetchCoursePageCourses({
    required String username,
    required String password,
    required String semSubId,
  }) async {
    return _executeRust<Map<String, dynamic>>(
      username: username,
      password: password,
      cachePath: '/student/course_page_courses',
      cacheParams: {'sem_sub_id': semSubId},
      operation: (client) async {
        final rawJson = await rust_api.fetchCoursesForCoursePage(
          client: client,
          semesterId: semSubId,
        );
        final decoded = jsonDecode(rawJson);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return {};
      },
    );
  }

  Future<Map<String, dynamic>> fetchCoursePageSlots({
    required String username,
    required String password,
    required String semSubId,
    required String classId,
  }) async {
    return _executeRust<Map<String, dynamic>>(
      username: username,
      password: password,
      cachePath: '/student/course_page_slots',
      cacheParams: {'sem_sub_id': semSubId, 'class_id': classId},
      operation: (client) async {
        final rawJson = await rust_api.fetchSlotsForCoursePage(
          client: client,
          semesterId: semSubId,
          classId: classId,
        );
        final decoded = jsonDecode(rawJson);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return {};
      },
    );
  }

  Future<Map<String, dynamic>> fetchCourseDetail({
    required String username,
    required String password,
    required String semSubId,
    required String erpId,
    required String classId,
  }) async {
    return _executeRust<Map<String, dynamic>>(
      username: username,
      password: password,
      cachePath: '/student/course_detail',
      cacheParams: {
        'sem_sub_id': semSubId,
        'erp_id': erpId,
        'class_id': classId,
      },
      operation: (client) async {
        final rawJson = await rust_api.fetchCourseDetail(
          client: client,
          semesterId: semSubId,
          erpId: erpId,
          classId: classId,
        );
        final decoded = jsonDecode(rawJson);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return {};
      },
    );
  }

  Future<List<int>> downloadCourseMaterial({
    required String username,
    required String password,
    required String downloadPath,
  }) async {
    return _executeRust<List<int>>(
      username: username,
      password: password,
      cachePath: '/student/download_course_material',
      operation: (client) async {
        if (downloadPath.contains('allCourseMeterialDownload')) {
          final bytes = await rust_api.downloadAllCourseMaterials(
            client: client,
            downloadPath: downloadPath,
          );
          return bytes;
        }
        final bytes = await rust_api.downloadCourseMaterial(
          client: client,
          downloadPath: downloadPath,
        );
        return bytes;
      },
    );
  }

  Future<List<int>> downloadCourseSyllabus({
    required String username,
    required String password,
    required String courseId,
    required String courseType,
  }) async {
    return _executeRust<List<int>>(
      username: username,
      password: password,
      cachePath: '/student/download_course_syllabus',
      operation: (client) => rust_api.downloadCourseSyllabus(
        client: client,
        courseId: courseId,
        courseType: courseType,
      ),
    );
  }

  Future<List<int>> downloadCoursePlanExcel({
    required String username,
    required String password,
    required String semSubId,
    required String classId,
  }) async {
    return _executeRust<List<int>>(
      username: username,
      password: password,
      cachePath: '/student/download_course_plan',
      operation: (client) => rust_api.downloadCoursePlanExcel(
        client: client,
        semesterId: semSubId,
        classId: classId,
      ),
    );
  }

  // ============================================================
  // SESSION COOKIES & PROXY COMPATIBILITY
  // ============================================================

  Future<Map<String, dynamic>> fetchSessionCookies({
    required String username,
    required String password,
  }) async {
    return getWebViewSessionData(username: username, password: password);
  }

  Future<Map<String, dynamic>> startProxySession({
    required String username,
    required String password,
  }) async {
    final data = await getWebViewSessionData(
      username: username,
      password: password,
    );
    return {
      'session_id': _vtopSessionId ?? 'rust_session',
      ...data,
    };
  }

  // ============================================================
  // DIGITAL ASSIGNMENTS
  // ============================================================

  Future<List<dynamic>> fetchDigitalAssignments({
    required String username,
    required String password,
    required String semSubId,
  }) async {
    return _executeRust<List<dynamic>>(
      username: username,
      password: password,
      cachePath: '/student/digital_assignments',
      cacheParams: {'sem_sub_id': semSubId},
      operation: (client) async {
        final rawJson = await rust_api.fetchDigitalAssignments(
          client: client,
          semesterId: semSubId,
        );
        final decoded = jsonDecode(rawJson);
        if (decoded is List) return decoded;
        return [];
      },
    );
  }

  Future<List<dynamic>> fetchCourseAssignments({
    required String username,
    required String password,
    required String classId,
  }) async {
    // Digital assignments in lib_vtop already return all details per course
    return [];
  }

  Future<List<int>> downloadAssignmentFile({
    required String username,
    required String password,
    required String downloadUrl,
  }) async {
    return _executeRust<List<int>>(
      username: username,
      password: password,
      cachePath: '/student/download_assignment_file',
      operation: (client) => rust_api.downloadDigitalAssignment(
        client: client,
        downloadUrl: downloadUrl,
      ),
    );
  }

  Future<String> uploadDigitalAssignment({
    required String username,
    required String password,
    required String classId,
    required String mode,
    required String fileName,
    required List<int> fileBytes,
  }) async {
    try {
      return await _executeRust<String>(
        username: username,
        password: password,
        cachePath: '/student/upload_digital_assignment',
        operation: (client) => rust_api.uploadDigitalAssignment(
          client: client,
          classId: classId,
          mode: mode,
          fileName: fileName,
          fileBytes: fileBytes,
        ),
      );
    } on VtopError_DigitalAssignmentUploadOtpRequired {
      throw Exception('DA_OTP_REQUIRED');
    } catch (e) {
      if (e.toString().contains('DigitalAssignmentUploadOtpRequired')) {
        throw Exception('DA_OTP_REQUIRED');
      }
      rethrow;
    }
  }

  Future<String> uploadDigitalAssignmentWithOtp({
    required String username,
    required String password,
    required String otpEmail,
  }) async {
    try {
      return await _executeRust<String>(
        username: username,
        password: password,
        cachePath: '/student/upload_digital_assignment_otp',
        operation: (client) => rust_api.uploadDigitalAssignmentWithOtp(
          client: client,
          otpEmail: otpEmail,
        ),
      );
    } on VtopError_DigitalAssignmentUploadIncorrectOtp {
      throw Exception('Incorrect OTP. Please check your email and try again.');
    } catch (e) {
      if (e.toString().contains('DigitalAssignmentUploadIncorrectOtp')) {
        throw Exception('Incorrect OTP. Please check your email and try again.');
      }
      rethrow;
    }
  }

  void invalidateUserSession([String? username]) {
    _generation++;
    _rustClient = null;
    _isRustAuthenticated = false;
    _otpPending = false;
    _sessionCreatedAt = null;
    _loginFlight.clear();
  }

  // ============================================================
  // OUTING PDF DOWNLOADS (REAL ON-DEVICE RUST BYTES)
  // ============================================================

  Future<List<int>> downloadGeneralOutingPass({
    required String username,
    required String password,
    required String leaveId,
  }) async {
    return _executeRust<List<int>>(
      username: username,
      password: password,
      cachePath: '/student/download_general_outing_pass',
      operation: (client) =>
          rust_api.fetchGeneralOutingPdf(client: client, leaveId: leaveId),
    );
  }

  Future<List<int>> downloadWeekendOutingForm({
    required String username,
    required String password,
    required String bookingId,
  }) async {
    return _executeRust<List<int>>(
      username: username,
      password: password,
      cachePath: '/student/download_weekend_outing_form',
      operation: (client) =>
          rust_api.fetchWeekendOutingPdf(client: client, bookingId: bookingId),
    );
  }

  // ============================================================
  // FACULTY DIRECTORY & SEARCH
  // ============================================================

  Future<List<dynamic>> fetchAllFaculty({
    required String username,
    required String password,
  }) async {
    return _executeRust<List<dynamic>>(
      username: username,
      password: password,
      cachePath: '/student/faculty',
      operation: (client) async {
        final rawJson = await rust_api.fetchAllFaculty(client: client);
        final decoded = jsonDecode(rawJson);
        if (decoded is List) return decoded;
        return [];
      },
    );
  }

  Future<Map<String, dynamic>> searchFaculty({
    required String username,
    required String password,
    required String searchTerm,
  }) async {
    return _executeRust<Map<String, dynamic>>(
      username: username,
      password: password,
      cachePath: '/student/search_faculty',
      operation: (client) async {
        final f = await rust_api.fetchFacultySearch(
          client: client,
          searchTerm: searchTerm,
        );
        return {
          'faculty_name': f.facultyName,
          'designation': f.designation,
          'school_or_centre': f.schoolOrCentre,
          'emp_id': f.empId,
        };
      },
    );
  }

  Future<Map<String, dynamic>> fetchFacultyDetails({
    required String username,
    required String password,
    required String empId,
  }) async {
    return _executeRust<Map<String, dynamic>>(
      username: username,
      password: password,
      cachePath: '/student/faculty_details',
      cacheParams: {'emp_id': empId},
      operation: (client) async {
        final d = await rust_api.fetchFacultyData(
          client: client,
          empId: empId,
        );
        return {
          'name': d.name,
          'designation': d.designation,
          'department': d.department,
          'school_centre': d.schoolCentre,
          'email': d.email,
          'cabin_number': d.cabinNumber,
          'office_hours': d.officeHours
              .map((o) => {'day': o.day, 'timings': o.timings})
              .toList(),
        };
      },
    );
  }
}

// ============================================================
// GLOBAL API SERVICE
// ============================================================

final apiService = ApiClient();
