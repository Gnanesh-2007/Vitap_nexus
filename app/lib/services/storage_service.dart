import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();

  static const String _keyUsername = 'vtop_username';
  static const String _keyPassword = 'vtop_password';
  static const String _keySemester = 'vtop_semester_id';
  static const String _keySemesterName = 'vtop_semester_name';

  static Future<void> saveCredentials({
    required String username,
    required String password,
    String? semesterId,
    String? semesterName,
  }) async {
    await _storage.write(key: _keyUsername, value: username);
    await _storage.write(key: _keyPassword, value: password);
    if (semesterId != null) {
      await _storage.write(key: _keySemester, value: semesterId);
    }
    if (semesterName != null) {
      await _storage.write(key: _keySemesterName, value: semesterName);
    }
  }

  static Future<void> saveSemester(String semesterId, String semesterName) async {
    await _storage.write(key: _keySemester, value: semesterId);
    await _storage.write(key: _keySemesterName, value: semesterName);
  }

  static Future<Map<String, String?>> getCredentials() async {
    final username = await _storage.read(key: _keyUsername);
    final password = await _storage.read(key: _keyPassword);
    final semesterId = await _storage.read(key: _keySemester);
    final semesterName = await _storage.read(key: _keySemesterName);

    return {
      'username': username,
      'password': password,
      'semesterId': semesterId,
      'semesterName': semesterName,
    };
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  static Future<bool> hasCredentials() async {
    final username = await _storage.read(key: _keyUsername);
    final password = await _storage.read(key: _keyPassword);
    return username != null && password != null && username.isNotEmpty && password.isNotEmpty;
  }
}
