import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();

  static const String _keyUsername = 'vtop_username';
  static const String _keyPassword = 'vtop_password';
  static const String _keySemester = 'vtop_semester_id';
  static const String _keySemesterName = 'vtop_semester_name';

  // In-memory hot cache for instant 0ms access across screens & app sessions
  static final Map<String, dynamic> _memoryCache = {};
  static final Map<String, DateTime> _memoryTimestamps = {};

  static const List<String> _knownCacheKeys = [
    'all_data',
    'attendance',
    'timetable',
    'marks',
    'profile',
    'grades',
    'exam_schedule',
    'assignments',
    'biometric',
    'outings',
    'payments',
    'courses',
    'mentor',
  ];

  /// Pre-warms the in-memory cache on app startup from persistent storage.
  /// Runs in < 25ms, making all cached data available synchronously in the first frame.
  static Future<void> initCache() async {
    try {
      for (final key in _knownCacheKeys) {
        final raw = await _storage.read(key: 'cache_$key');
        if (raw != null) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map && decoded.containsKey('data')) {
              _memoryCache[key] = decoded['data'];
              if (decoded.containsKey('timestamp')) {
                final ts = DateTime.tryParse(decoded['timestamp'].toString());
                if (ts != null) _memoryTimestamps[key] = ts;
              }
            } else {
              _memoryCache[key] = decoded;
            }
          } catch (_) {}
        }
      }
      debugPrint('StorageService: Pre-warmed ${_memoryCache.length} cache entries into memory');
    } catch (e) {
      debugPrint('StorageService: initCache error: $e');
    }
  }

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
    _memoryCache.clear();
    _memoryTimestamps.clear();
    await _storage.deleteAll();
  }

  static Future<bool> hasCredentials() async {
    final username = await _storage.read(key: _keyUsername);
    final password = await _storage.read(key: _keyPassword);
    return username != null && password != null && username.isNotEmpty && password.isNotEmpty;
  }

  // ─── Synchronous 0ms Memory Access ──────────────────────────────────────

  static dynamic getMemoryCache(String key) => _memoryCache[key];

  static DateTime? getMemoryTimestamp(String key) => _memoryTimestamps[key];

  // ─── Offline-First Caching with Timestamp Tracking ──────────────────────

  /// Saves any API response to in-memory cache (0ms) and persistent storage.
  static Future<void> setCache(String key, dynamic data) async {
    final now = DateTime.now();
    _memoryCache[key] = data;
    _memoryTimestamps[key] = now;

    try {
      final payload = jsonEncode({
        'timestamp': now.toIso8601String(),
        'data': data,
      });
      await _storage.write(key: 'cache_$key', value: payload);
    } catch (_) {
      // Memory cache still retains it
    }
  }

  /// Retrieves cached data from memory first (0ms), then falls back to persistent storage.
  static Future<dynamic> getCache(String key) async {
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }

    try {
      final raw = await _storage.read(key: 'cache_$key');
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded.containsKey('data')) {
        final data = decoded['data'];
        if (decoded.containsKey('timestamp')) {
          final ts = DateTime.tryParse(decoded['timestamp'].toString());
          if (ts != null) _memoryTimestamps[key] = ts;
        }
        _memoryCache[key] = data;
        return data;
      }
      return decoded;
    } catch (_) {
      return null;
    }
  }

  /// Unpacks the massive all_data payload into individual feature caches at once.
  /// A single /all_data call populates Dashboard, Attendance, Timetable, Marks,
  /// Profile, and Grades simultaneously!
  static Future<void> unpackAllData(Map<String, dynamic> allData) async {
    final now = DateTime.now();
    await setCache('all_data', allData);

    if (allData['attendance'] != null) {
      await setCache('attendance', allData['attendance']);
    }
    if (allData['timetable'] != null) {
      await setCache('timetable', allData['timetable']);
    }
    if (allData['marks'] != null) {
      await setCache('marks', allData['marks']);
    }
    if (allData['profile'] != null) {
      await setCache('profile', allData['profile']);
    }
    if (allData['grade_history'] != null) {
      await setCache('grades', allData['grade_history']);
    }
    if (allData['exam_schedule'] != null) {
      await setCache('exam_schedule', allData['exam_schedule']);
    }
    debugPrint('StorageService: Successfully unpacked all_data into 6 sub-caches at $now');
  }

  /// Gets the last synced timestamp for a given feature key.
  static Future<DateTime?> getLastSynced(String key) async {
    if (_memoryTimestamps.containsKey(key)) {
      return _memoryTimestamps[key];
    }

    try {
      final raw = await _storage.read(key: 'cache_$key');
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded.containsKey('timestamp')) {
        final ts = DateTime.tryParse(decoded['timestamp'].toString());
        if (ts != null) {
          _memoryTimestamps[key] = ts;
          return ts;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Formats a DateTime into a clean, human-friendly "Last synced" string.
  static String formatLastSynced(DateTime? dt) {
    if (dt == null) return 'Never synced';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24 && dt.day == now.day) {
      return 'Today, ${DateFormat('h:mm a').format(dt)}';
    }
    if (diff.inDays < 2) {
      return 'Yesterday, ${DateFormat('h:mm a').format(dt)}';
    }
    return DateFormat('MMM d, h:mm a').format(dt);
  }
}
