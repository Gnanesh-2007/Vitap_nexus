import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();

  static const String _keyUsername = 'vtop_username';
  static const String _keyPassword = 'vtop_password';
  static const String _keySemester = 'vtop_semester_id';
  static const String _keySemesterName = 'vtop_semester_name';
  static const String _keySessionId = 'vtop_session_id';

  // ============================================================
  // CREDENTIALS
  // ============================================================

  static Future<void> saveCredentials({
    required String username,
    required String password,
    String? semesterId,
    String? semesterName,
  }) async {
    await _storage.write(
      key: _keyUsername,
      value: username,
    );

    await _storage.write(
      key: _keyPassword,
      value: password,
    );

    if (semesterId != null && semesterId.isNotEmpty) {
      await _storage.write(
        key: _keySemester,
        value: semesterId,
      );
    }

    if (semesterName != null && semesterName.isNotEmpty) {
      await _storage.write(
        key: _keySemesterName,
        value: semesterName,
      );
    }
  }

  // ============================================================
  // SESSION
  // ============================================================

  /// Saves the backend VTOP session ID.
  ///
  /// This is the session created by /auth/login.
  /// OTP verification continues using this exact session.
  static Future<void> saveSessionId(String sessionId) async {
    if (sessionId.isEmpty) return;

    await _storage.write(
      key: _keySessionId,
      value: sessionId,
    );
  }

  /// Returns the previously saved backend VTOP session ID.
  static Future<String?> getSessionId() async {
    return _storage.read(key: _keySessionId);
  }

  /// Removes only the saved VTOP session.
  ///
  /// Credentials remain stored so a new login can be performed
  /// if the backend session has expired.
  static Future<void> clearSessionId() async {
    await _storage.delete(key: _keySessionId);
  }

  // ============================================================
  // SEMESTER
  // ============================================================

  static Future<void> saveSemester(
    String semesterId,
    String semesterName,
  ) async {
    await _storage.write(
      key: _keySemester,
      value: semesterId,
    );

    await _storage.write(
      key: _keySemesterName,
      value: semesterName,
    );
  }

  // ============================================================
  // READ EVERYTHING
  // ============================================================

  static Future<Map<String, String?>> getCredentials() async {
    final username = await _storage.read(key: _keyUsername);
    final password = await _storage.read(key: _keyPassword);
    final semesterId = await _storage.read(key: _keySemester);
    final semesterName = await _storage.read(key: _keySemesterName);
    final sessionId = await _storage.read(key: _keySessionId);

    return {
      'username': username,
      'password': password,
      'semesterId': semesterId,
      'semesterName': semesterName,
      'sessionId': sessionId,
    };
  }

  // ============================================================
  // CLEAR EVERYTHING
  // ============================================================

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // ============================================================
  // CHECK CREDENTIALS
  // ============================================================

  static Future<bool> hasCredentials() async {
    final username = await _storage.read(key: _keyUsername);
    final password = await _storage.read(key: _keyPassword);

    return username != null &&
        password != null &&
        username.isNotEmpty &&
        password.isNotEmpty;
  }

  // ============================================================
  // CHECK SESSION
  // ============================================================

  static Future<bool> hasSession() async {
    final sessionId = await _storage.read(key: _keySessionId);

    return sessionId != null && sessionId.isNotEmpty;
  }
}