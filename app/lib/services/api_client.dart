import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class _CachedResponse {
  final dynamic data;
  final int? statusCode;
  final Headers? headers;
  final DateTime createdAt;

  const _CachedResponse({
    required this.data,
    required this.statusCode,
    required this.headers,
    required this.createdAt,
  });
}

class ApiClient {
  late final Dio dio;

  // Live Render backend
  static String get defaultBaseUrl =>
      'https://vitap-nexus-api.onrender.com';

  // ============================================================
  // VTOP SESSION
  // ============================================================

  String? _vtopSessionId;

  String? get vtopSessionId => _vtopSessionId;

  // ============================================================
  // IN-MEMORY RESPONSE CACHE
  // ============================================================
  //
  // VTOP is slow compared with a normal API. Keep read-only
  // responses in memory so revisiting a screen does not hit VTOP
  // again. Cache is session-scoped and automatically cleared on
  // login/logout/session changes.
  //
  static const Duration _cacheTtl = Duration(minutes: 5);

  final Map<String, _CachedResponse> _responseCache = {};

  // Prevent the same background warm-up from being launched more than once
  // for the same VTOP session + semester.
  String? _lastWarmUpKey;

  static const Set<String> _cacheablePaths = {
    '/student/semesters',
    '/student/all_data',
    '/student/profile',
    '/student/attendance',
    '/student/timetable',
    '/student/exam_schedule',
    '/student/marks',
    '/student/grade_history',
    '/student/mentor',
    '/student/biometric',
    '/student/general_outing_requests',
    '/student/weekend_outing_requests',
    '/student/pending_payments',
    '/student/payment_receipts',
    '/student/course_page_courses',
    '/student/course_page_slots',
    '/student/course_detail',
    '/student/digital_assignments',
    '/student/course_assignments',
  };

  bool _isCacheable(String path) => _cacheablePaths.contains(path);

  String _cacheKey(RequestOptions options) {
    String body = '';
    final data = options.data;
    if (data != null) {
      try {
        body = jsonEncode(data);
      } catch (_) {
        body = data.toString();
      }
    }

    return '${_vtopSessionId ?? 'no-session'}|${options.path}|$body';
  }

  void clearDataCache() {
    _responseCache.clear();
    debugPrint('VTOP data cache cleared');
  }

  // Warm the most commonly opened screens in the background.
  // This is deliberately fire-and-forget so dashboard navigation
  // is never blocked by prefetching.
  void warmUpCommonScreens({
    required String username,
    required String password,
    required String semSubId,
  }) {
    final sessionId = _vtopSessionId;

    if (sessionId == null || sessionId.isEmpty) return;

    final warmUpKey = '$sessionId|$semSubId';

    // all_data can be refreshed/rebuilt by Riverpod. Do not launch the
    // five background prefetch requests again for the same session +
    // semester.
    if (_lastWarmUpKey == warmUpKey) {
      debugPrint('VTOP warm-up skipped → already started for this session');
      return;
    }

    // Set this BEFORE starting the async work so two nearly simultaneous
    // calls cannot both pass the guard.
    _lastWarmUpKey = warmUpKey;

    unawaited(_warmUpCommonScreens(
      username: username,
      password: password,
      semSubId: semSubId,
    ));
  }

  Future<void> _warmUpCommonScreens({
    required String username,
    required String password,
    required String semSubId,
  }) async {
    debugPrint('VTOP warm-up started');

    // These are read-only requests. Failures are intentionally
    // ignored because warm-up must never break the app.
    await Future.wait<void>([
      fetchMentor(
        username: username,
        password: password,
      ).then((_) {}, onError: (_) {}),
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

  /// Called after /auth/login returns a session_id.
  void setVtopSessionId(String sessionId) {
    if (_vtopSessionId != sessionId) {
      clearDataCache();
      _lastWarmUpKey = null;
    }
    _vtopSessionId = sessionId;

    debugPrint(
      'VTOP session set: ${sessionId.substring(0, 8)}...',
    );
  }

  /// Clears the current VTOP session.
  void clearVtopSessionId() {
    _vtopSessionId = null;
    _lastWarmUpKey = null;
    clearDataCache();
    debugPrint('VTOP session cleared');
  }

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  ApiClient({String? baseUrl}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? defaultBaseUrl,
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 45),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // ----------------------------------------------------
          // API KEY
          // ----------------------------------------------------

          options.headers['X-API-Key'] = const String.fromEnvironment(
            'API_KEY',
            defaultValue: 'GnaneshReddy77806',
          );

          // ----------------------------------------------------
          // VTOP SESSION ID
          // ----------------------------------------------------

          final isStudentRequest =
              options.path.startsWith('/student/');
          final isProxyStartRequest =
              options.path == '/vtop_proxy/start_session';

          if (isStudentRequest || isProxyStartRequest) {
            if (_vtopSessionId != null &&
                _vtopSessionId!.isNotEmpty) {
              options.headers['X-VTOP-Session-ID'] =
                  _vtopSessionId;
            } else {
              debugPrint(
                'WARNING: No VTOP session for ${options.path}',
              );
            }
          }

          // ----------------------------------------------------
          // INSTANT CACHE HIT
          // ----------------------------------------------------

          if (options.method.toUpperCase() == 'POST' &&
              _isCacheable(options.path)) {
            final key = _cacheKey(options);
            final cached = _responseCache[key];

            if (cached != null) {
              if (DateTime.now().difference(cached.createdAt) <= _cacheTtl) {
                debugPrint('CACHE HIT → ${options.path}');
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: cached.data,
                    statusCode: cached.statusCode,
                    headers: cached.headers,
                  ),
                );
              }

              _responseCache.remove(key);
            }
          }

          return handler.next(options);
        },

        onResponse: (response, handler) {
          final options = response.requestOptions;

          if (options.method.toUpperCase() == 'POST' &&
              _isCacheable(options.path) &&
              response.statusCode != null &&
              response.statusCode! >= 200 &&
              response.statusCode! < 300) {
            final key = _cacheKey(options);

            _responseCache[key] = _CachedResponse(
              data: response.data,
              statusCode: response.statusCode,
              headers: response.headers,
              createdAt: DateTime.now(),
            );

            debugPrint('CACHE STORE → ${options.path}');
          }

          return handler.next(response);
        },

        onError: (DioException e, handler) {
          debugPrint(
            'API Error [${e.response?.statusCode}]: '
            '${e.response?.data}',
          );

          return handler.next(e);
        },
      ),
    );
  }

  // ============================================================
  // AUTH / OTP
  // ============================================================

  /// Step 1:
  /// Initiates VTOP login.
  ///
  /// Returns:
  /// {
  ///   session_id: "...",
  ///   otp_required: true/false,
  ///   message: "..."
  /// }
  Future<Map<String, dynamic>> initiateLogin({
    required String username,
    required String password,
  }) async {
    try {
      final response = await dio.post(
        '/auth/login',
        data: {
          'registration_number': username,
          'password': password,
        },
      );

      final data = response.data as Map<String, dynamic>;

      // Store session immediately.
      final sessionId = data['session_id']?.toString();

      if (sessionId != null && sessionId.isNotEmpty) {
        setVtopSessionId(sessionId);
      }

      return data;
    } on DioException catch (e) {
      final detail =
          e.response?.data?['detail'] ??
          e.message ??
          'Login failed.';

      throw Exception(detail);
    }
  }

  /// Step 2:
  /// Verify OTP using the SAME backend session.
  Future<Map<String, dynamic>> verifyLoginOtp({
    required String sessionId,
    required String otp,
  }) async {
    try {
      final response = await dio.post(
        '/auth/verify_otp',
        data: {
          'session_id': sessionId,
          'otp': otp,
        },
      );

      final data = response.data as Map<String, dynamic>;

      // Make sure the verified session is still stored.
      final returnedSessionId =
          data['session_id']?.toString();

      if (returnedSessionId != null &&
          returnedSessionId.isNotEmpty) {
        setVtopSessionId(returnedSessionId);
      } else {
        // Keep the session we already had.
        setVtopSessionId(sessionId);
      }

      return data;
    } on DioException catch (e) {
      final detail =
          e.response?.data?['detail'] ??
          e.message ??
          'OTP verification failed.';

      throw Exception(detail);
    }
  }

  /// Resend OTP for the current login session.
  Future<void> resendLoginOtp(String sessionId) async {
    try {
      await dio.post(
        '/auth/resend_otp',
        data: {
          'session_id': sessionId,
        },
      );
    } on DioException catch (e) {
      final detail =
          e.response?.data?['detail'] ??
          e.message ??
          'Failed to resend OTP.';

      throw Exception(detail);
    }
  }

  // ============================================================
  // SEMESTERS
  // ============================================================

  Future<Map<String, dynamic>> fetchSemesters(
    String username,
    String password,
  ) async {
    final response = await dio.post(
      '/student/semesters',
      data: {
        'registration_number': username,
        'password': password,
      },
    );

    return response.data as Map<String, dynamic>;
  }

  // ============================================================
  // ALL DATA
  // ============================================================

  Future<Map<String, dynamic>> fetchAllData({
    required String username,
    required String password,
    required String semSubId,
  }) async {
    final response = await dio.post(
      '/student/all_data',
      data: {
        'registration_number': username,
        'password': password,
        'sem_sub_id': semSubId,
      },
    );

    final data = response.data as Map<String, dynamic>;

    // Start feature prefetching only after dashboard data has
    // arrived. This keeps dashboard startup responsive while
    // making the next screens ready in the background.
    warmUpCommonScreens(
      username: username,
      password: password,
      semSubId: semSubId,
    );

    return data;
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Future<Map<String, dynamic>> fetchProfile(
    String username,
    String password,
  ) async {
    final response = await dio.post(
      '/student/profile',
      data: {
        'registration_number': username,
        'password': password,
      },
    );

    return response.data as Map<String, dynamic>;
  }

  // ============================================================
  // ATTENDANCE
  // ============================================================

  Future<List<dynamic>> fetchAttendance({
    required String username,
    required String password,
    required String semSubId,
  }) async {
    final response = await dio.post(
      '/student/attendance',
      data: {
        'registration_number': username,
        'password': password,
        'sem_sub_id': semSubId,
      },
    );

    return response.data as List<dynamic>;
  }

  // ============================================================
  // TIMETABLE
  // ============================================================

  Future<Map<String, dynamic>> fetchTimetable({
    required String username,
    required String password,
    required String semSubId,
  }) async {
    final response = await dio.post(
      '/student/timetable',
      data: {
        'registration_number': username,
        'password': password,
        'sem_sub_id': semSubId,
      },
    );

    return response.data as Map<String, dynamic>;
  }

  // ============================================================
  // EXAM SCHEDULE
  // ============================================================

  Future<Map<String, dynamic>> fetchExamSchedule({
    required String username,
    required String password,
    required String semSubId,
  }) async {
    final response = await dio.post(
      '/student/exam_schedule',
      data: {
        'registration_number': username,
        'password': password,
        'sem_sub_id': semSubId,
      },
    );

    return response.data as Map<String, dynamic>;
  }

  // ============================================================
  // MARKS
  // ============================================================

  Future<List<dynamic>> fetchMarks({
    required String username,
    required String password,
    required String semSubId,
  }) async {
    final response = await dio.post(
      '/student/marks',
      data: {
        'registration_number': username,
        'password': password,
        'sem_sub_id': semSubId,
      },
    );

    final data = response.data;

    if (data is List) {
      return data;
    }

    if (data is Map && data.containsKey('marks')) {
      return data['marks'] as List<dynamic>? ?? [];
    }

    return [];
  }

  // ============================================================
  // GRADE HISTORY
  // ============================================================

  Future<Map<String, dynamic>> fetchGradeHistory({
    required String username,
    required String password,
  }) async {
    final response = await dio.post(
      '/student/grade_history',
      data: {
        'registration_number': username,
        'password': password,
      },
    );

    return response.data as Map<String, dynamic>;
  }

  // ============================================================
  // MENTOR
  // ============================================================

  Future<Map<String, dynamic>> fetchMentor({
    required String username,
    required String password,
  }) async {
    final response = await dio.post(
      '/student/mentor',
      data: {
        'registration_number': username,
        'password': password,
      },
    );

    return response.data as Map<String, dynamic>;
  }

  // ============================================================
  // BIOMETRIC
  // ============================================================

  Future<List<dynamic>> fetchBiometric({
    required String username,
    required String password,
    required String date,
  }) async {
    final response = await dio.post(
      '/student/biometric',
      data: {
        'registration_number': username,
        'password': password,
        'date': date,
      },
    );

    return response.data as List<dynamic>;
  }

  // ============================================================
  // OUTINGS
  // ============================================================

  Future<Map<String, dynamic>> fetchGeneralOutings({
    required String username,
    required String password,
  }) async {
    final response = await dio.post(
      '/student/general_outing_requests',
      data: {
        'registration_number': username,
        'password': password,
      },
    );

    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchWeekendOutings({
    required String username,
    required String password,
  }) async {
    final response = await dio.post(
      '/student/weekend_outing_requests',
      data: {
        'registration_number': username,
        'password': password,
      },
    );

    return response.data as Map<String, dynamic>;
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
    final response = await dio.post(
      '/student/submit_general_outing',
      data: {
        'registration_number': username,
        'password': password,
        'out_place': outPlace,
        'purpose_of_visit': purposeOfVisit,
        'outing_date': outingDate,
        'out_time': outTime,
        'in_date': inDate,
        'in_time': inTime,
      },
    );

    final message = response.data['message']?.toString() ??
        'Outing applied successfully.';
    clearDataCache();
    return message;
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
    final response = await dio.post(
      '/student/submit_weekend_outing',
      data: {
        'registration_number': username,
        'password': password,
        'out_place': outPlace,
        'purpose_of_visit': purposeOfVisit,
        'outing_date': outingDate,
        'out_time': outTime,
        'contact_number': contactNumber,
      },
    );

    final message = response.data['message']?.toString() ??
        'Weekend outing applied successfully.';
    clearDataCache();
    return message;
  }

  Future<String> deleteGeneralOuting({
    required String username,
    required String password,
    required String leaveId,
  }) async {
    final response = await dio.post(
      '/student/delete_general_outing',
      data: {
        'registration_number': username,
        'password': password,
        'appl_id': leaveId,
      },
    );

    final message = response.data['message']?.toString() ??
        'Outing deleted.';
    clearDataCache();
    return message;
  }

  Future<String> deleteWeekendOuting({
    required String username,
    required String password,
    required String bookingId,
  }) async {
    final response = await dio.post(
      '/student/delete_weekend_outing',
      data: {
        'registration_number': username,
        'password': password,
        'appl_id': bookingId,
      },
    );

    final message = response.data['message']?.toString() ??
        'Outing deleted.';
    clearDataCache();
    return message;
  }

  // ============================================================
  // PAYMENTS
  // ============================================================

  Future<List<dynamic>> fetchPendingPayments({
    required String username,
    required String password,
  }) async {
    final response = await dio.post(
      '/student/pending_payments',
      data: {
        'registration_number': username,
        'password': password,
      },
    );

    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> fetchPaymentReceipts({
    required String username,
    required String password,
  }) async {
    final response = await dio.post(
      '/student/payment_receipts',
      data: {
        'registration_number': username,
        'password': password,
      },
    );

    return response.data as List<dynamic>;
  }

  // ============================================================
  // COURSE PAGE
  // ============================================================

  Future<Map<String, dynamic>> fetchCoursePageCourses({
    required String username,
    required String password,
    required String semSubId,
  }) async {
    final response = await dio.post(
      '/student/course_page_courses',
      data: {
        'registration_number': username,
        'password': password,
        'sem_sub_id': semSubId,
      },
    );

    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchCoursePageSlots({
    required String username,
    required String password,
    required String semSubId,
    required String classId,
  }) async {
    final response = await dio.post(
      '/student/course_page_slots',
      data: {
        'registration_number': username,
        'password': password,
        'sem_sub_id': semSubId,
        'class_id': classId,
      },
    );

    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchCourseDetail({
    required String username,
    required String password,
    required String semSubId,
    required String erpId,
    required String classId,
  }) async {
    final response = await dio.post(
      '/student/course_detail',
      data: {
        'registration_number': username,
        'password': password,
        'sem_sub_id': semSubId,
        'erp_id': erpId,
        'class_id': classId,
      },
    );

    return response.data as Map<String, dynamic>;
  }

  Future<List<int>> downloadCourseMaterial({
    required String username,
    required String password,
    required String downloadPath,
  }) async {
    final response = await dio.post(
      '/student/download_course_material',
      data: {
        'registration_number': username,
        'password': password,
        'download_path': downloadPath,
      },
      options: Options(
        responseType: ResponseType.bytes,
      ),
    );

    return response.data as List<int>;
  }

  Future<String> downloadPaymentReceipt({
    required String username,
    required String password,
    required String receiptNo,
    required String applicationNumber,
  }) async {
    final response = await dio.post(
      '/student/download_payment_receipt',
      data: {
        'registration_number': username,
        'password': password,
        'receipt_no': receiptNo,
        'application_number': applicationNumber,
      },
    );

    return response.data.toString();
  }

  // ============================================================
  // SESSION COOKIES
  // ============================================================

  Future<Map<String, dynamic>> fetchSessionCookies({
    required String username,
    required String password,
  }) async {
    final response = await dio.post(
      '/student/session_cookies',
      data: {
        'registration_number': username,
        'password': password,
      },
    );

    return response.data as Map<String, dynamic>;
  }

  // ============================================================
  // VTOP PROXY
  // ============================================================

  Future<Map<String, dynamic>> startProxySession({
    required String username,
    required String password,
  }) async {
    final response = await dio.post(
      '/vtop_proxy/start_session',
      data: {
        'registration_number': username,
        'password': password,
      },
    );

    return response.data as Map<String, dynamic>;
  }

  // ============================================================
  // DIGITAL ASSIGNMENTS
  // ============================================================

  Future<List<dynamic>> fetchDigitalAssignments({
    required String username,
    required String password,
    required String semSubId,
  }) async {
    final response = await dio.post(
      '/student/digital_assignments',
      data: {
        'registration_number': username,
        'password': password,
        'sem_sub_id': semSubId,
      },
    );

    return response.data as List<dynamic>;
  }

  // ============================================================
  // COURSE ASSIGNMENTS
  // ============================================================

  Future<List<dynamic>> fetchCourseAssignments({
    required String username,
    required String password,
    required String classId,
  }) async {
    final response = await dio.post(
      '/student/course_assignments',
      data: {
        'registration_number': username,
        'password': password,
        'class_id': classId,
      },
    );

    return response.data as List<dynamic>;
  }

  // ============================================================
  // DOWNLOAD ASSIGNMENT FILE
  // ============================================================

  Future<List<int>> downloadAssignmentFile({
    required String username,
    required String password,
    required String downloadUrl,
  }) async {
    final response = await dio.post<List<int>>(
      '/student/download_assignment_file',
      data: {
        'registration_number': username,
        'password': password,
        'download_url': downloadUrl,
      },
      options: Options(
        responseType: ResponseType.bytes,
      ),
    );

    return response.data ?? [];
  }
}


// ============================================================
// GLOBAL API SERVICE
// ============================================================

final apiService = ApiClient();