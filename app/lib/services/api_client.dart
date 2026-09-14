import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  late final Dio dio;

  // Live Render backend
  static String get defaultBaseUrl => 'https://vitap-nexus-api.onrender.com';

  ApiClient({String? baseUrl}) {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? defaultBaseUrl,
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 45),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // API key is configured via environment — see README for setup
          options.headers['X-API-Key'] = const String.fromEnvironment(
            'API_KEY',
            defaultValue: 'YOUR_API_KEY_HERE',
          );
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          debugPrint('API Error [${e.response?.statusCode}]: ${e.response?.data}');
          return handler.next(e);
        },
      ),
    );
  }

  // ─── Auth / OTP-aware Login ───────────────────────────────────────────────

  /// Step 1: Initiate login.
  /// Returns Map with:
  ///   - session_id (String)
  ///   - otp_required (bool) — true means VTOP sent an OTP email
  ///   - message (String)
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
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] ?? e.message ?? 'Login failed.';
      throw Exception(detail);
    }
  }

  /// Step 2 (only when otp_required): Submit OTP to complete login.
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
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] ?? e.message ?? 'OTP verification failed.';
      throw Exception(detail);
    }
  }

  /// Ask VTOP to resend the login OTP for an existing session.
  Future<void> resendLoginOtp(String sessionId) async {
    try {
      await dio.post('/auth/resend_otp', data: {'session_id': sessionId});
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] ?? e.message ?? 'Failed to resend OTP.';
      throw Exception(detail);
    }
  }

  // ─── Semesters ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchSemesters(String username, String password) async {
    final response = await dio.post(
      '/student/semesters',
      data: {
        'registration_number': username,
        'password': password,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ─── All Data ─────────────────────────────────────────────────────────────

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
    return response.data as Map<String, dynamic>;
  }

  // ─── Profile ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchProfile(String username, String password) async {
    final response = await dio.post(
      '/student/profile',
      data: {
        'registration_number': username,
        'password': password,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ─── Attendance ───────────────────────────────────────────────────────────

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

  // ─── Timetable ────────────────────────────────────────────────────────────

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

  // ─── Marks ────────────────────────────────────────────────────────────────

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
    // marks response is a dict with course lists — normalise to flat list
    final data = response.data;
    if (data is List) return data;
    if (data is Map && data.containsKey('marks')) {
      return data['marks'] as List<dynamic>? ?? [];
    }
    return [];
  }

  // ─── Grade History / CGPA ────────────────────────────────────────────────
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

  // ─── Mentor ───────────────────────────────────────────────────────────────
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

  // ─── Biometric ────────────────────────────────────────────────────────────
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

  // ─── Outings ──────────────────────────────────────────────────────────────
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
    return response.data['message']?.toString() ?? 'Outing applied successfully.';
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
    return response.data['message']?.toString() ?? 'Weekend outing applied successfully.';
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
    return response.data['message']?.toString() ?? 'Outing deleted.';
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
    return response.data['message']?.toString() ?? 'Outing deleted.';
  }

  // ─── Payments ─────────────────────────────────────────────────────────────
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

  // ─── Real Course Page & Materials ──────────────────────────────────────────
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
      options: Options(responseType: ResponseType.bytes),
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

  // ─── Session Cookies for In-App VTOP WebView ───────────────────────────────
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

  // ─── Direct VTOP Live Proxy Session ─────────────────────────────────────────
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

  // ─── Digital Assignments ─────────────────────────────────────────────────────
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
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }
}

final apiService = ApiClient();

