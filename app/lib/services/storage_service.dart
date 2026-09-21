import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Permanent, reliable local storage engine.
/// Uses SharedPreferences for unlimited offline data persistence across app restarts,
/// and FlutterSecureStorage for encrypted student credentials.
class StorageService {
  static const _secureStorage = FlutterSecureStorage();
  static SharedPreferences? _prefs;

  static const String _keyUsername = 'vtop_username';
  static const String _keyPassword = 'vtop_password';
  static const String _keySemester = 'vtop_semester_id';
  static const String _keySemesterName = 'vtop_semester_name';
  static const String _keyAvailableSemesters = 'vtop_available_semesters';

  // In-memory hot cache for instant 0ms access across screens
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

  /// Pre-warms the in-memory cache on app startup.
  static Future<void> initCache() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      for (final key in _knownCacheKeys) {
        final raw = _prefs!.getString('cache_$key');
        if (raw != null && raw.isNotEmpty) {
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
          } catch (decodeErr) {
            debugPrint('StorageService decode error for $key: $decodeErr');
          }
        }
      }

      // Pre-warm the semester list too.
      final rawSemesters =
          _prefs!.getString(_keyAvailableSemesters);

      if (rawSemesters != null && rawSemesters.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawSemesters);

          if (decoded is List) {
            _memoryCache[_keyAvailableSemesters] = List<dynamic>.from(decoded);
          }
        } catch (e) {
          debugPrint(
            'StorageService semester list decode error: $e',
          );
        }
      }

      debugPrint(
        'StorageService: Successfully pre-warmed '
        '${_memoryCache.length} features into memory',
      );
    } catch (e) {
      debugPrint('StorageService: initCache error: $e');
    }
  }

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ============================================================
  // CREDENTIAL STORAGE
  // ============================================================

  static Future<void> saveCredentials({
    required String username,
    required String password,
    String? semesterId,
    String? semesterName,
  }) async {
    final prefs = await _getPrefs();

    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyPassword, password);

    if (semesterId != null) {
      await prefs.setString(_keySemester, semesterId);
    }

    if (semesterName != null) {
      await prefs.setString(_keySemesterName, semesterName);
    }

    try {
      await _secureStorage.write(
        key: _keyUsername,
        value: username,
      );
      await _secureStorage.write(
        key: _keyPassword,
        value: password,
      );
    } catch (_) {}
  }

  static Future<void> saveSemester(
    String semesterId,
    String semesterName,
  ) async {
    final prefs = await _getPrefs();

    await prefs.setString(
      _keySemester,
      semesterId,
    );

    await prefs.setString(
      _keySemesterName,
      semesterName,
    );
  }

  /// Saves the COMPLETE semester list permanently.
  /// This is separate from saveSemester(), which stores only the
  /// currently selected semester.
  static Future<void> saveAvailableSemesters(
    List<Map<String, dynamic>> semesters,
  ) async {
    if (semesters.isEmpty) return;

    final normalized = semesters
        .map(
          (semester) => {
            'id': semester['id']?.toString() ?? '',
            'name': semester['name']?.toString() ??
                semester['id']?.toString() ??
                '',
          },
        )
        .where((semester) => semester['id']!.toString().isNotEmpty)
        .toList();

    if (normalized.isEmpty) return;

    _memoryCache[_keyAvailableSemesters] = normalized;

    try {
      final prefs = await _getPrefs();

      await prefs.setString(
        _keyAvailableSemesters,
        jsonEncode(normalized),
      );

      debugPrint(
        'StorageService: Saved ${normalized.length} semesters locally',
      );
    } catch (e) {
      debugPrint(
        'StorageService saveAvailableSemesters error: $e',
      );
    }
  }

  /// Returns the COMPLETE locally stored semester list.
  /// Memory first = effectively 0ms after initCache().
  static List<Map<String, dynamic>> getAvailableSemestersSync() {
    final data = _memoryCache[_keyAvailableSemesters];

    if (data is! List) return [];

    return data
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  /// Async fallback for cases where initCache() has not been called yet.
  static Future<List<Map<String, dynamic>>> getAvailableSemesters() async {
    final memory = getAvailableSemestersSync();

    if (memory.isNotEmpty) {
      return memory;
    }

    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_keyAvailableSemesters);

      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);

      if (decoded is! List) return [];

      final result = decoded
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();

      _memoryCache[_keyAvailableSemesters] = result;
      return result;
    } catch (e) {
      debugPrint(
        'StorageService getAvailableSemesters error: $e',
      );
      return [];
    }
  }

  static Future<Map<String, String?>> getCredentials() async {
    final prefs = await _getPrefs();

    var username = prefs.getString(_keyUsername);
    var password = prefs.getString(_keyPassword);
    var semesterId = prefs.getString(_keySemester);
    var semesterName = prefs.getString(_keySemesterName);

    if (username == null || password == null) {
      try {
        username ??= await _secureStorage.read(
          key: _keyUsername,
        );
        password ??= await _secureStorage.read(
          key: _keyPassword,
        );
      } catch (_) {}
    }

    return {
      'username': username,
      'password': password,
      'semesterId': semesterId,
      'semesterName': semesterName,
    };
  }

  static Future<bool> hasCredentials() async {
    final creds = await getCredentials();

    return creds['username'] != null &&
        creds['password'] != null &&
        creds['username']!.isNotEmpty &&
        creds['password']!.isNotEmpty;
  }

  static Future<void> clearAll() async {
    _memoryCache.clear();
    _memoryTimestamps.clear();

    final prefs = await _getPrefs();
    await prefs.clear();

    try {
      await _secureStorage.deleteAll();
    } catch (_) {}
  }

  // ============================================================
  // SYNCHRONOUS MEMORY ACCESS
  // ============================================================

  static dynamic getMemoryCache(String key) =>
      _memoryCache[key];

  static DateTime? getMemoryTimestamp(String key) =>
      _memoryTimestamps[key];

  // ============================================================
  // PERMANENT FEATURE CACHE
  // ============================================================

  static Future<void> setCache(
    String key,
    dynamic data,
  ) async {
    if (data == null) return;

    final now = DateTime.now();

    _memoryCache[key] = data;
    _memoryTimestamps[key] = now;

    try {
      final prefs = await _getPrefs();

      final payload = jsonEncode({
        'timestamp': now.toIso8601String(),
        'data': data,
      });

      await prefs.setString(
        'cache_$key',
        payload,
      );

      debugPrint(
        'StorageService: Permanently cached $key '
        '(${payload.length} bytes) at $now',
      );
    } catch (e) {
      debugPrint(
        'StorageService setCache error for $key: $e',
      );
    }
  }

  static Future<dynamic> getCache(String key) async {
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }

    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString('cache_$key');

      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);

      if (decoded is Map &&
          decoded.containsKey('data')) {
        final data = decoded['data'];

        if (decoded.containsKey('timestamp')) {
          final ts = DateTime.tryParse(
            decoded['timestamp'].toString(),
          );

          if (ts != null) {
            _memoryTimestamps[key] = ts;
          }
        }

        _memoryCache[key] = data;
        return data;
      }

      _memoryCache[key] = decoded;
      return decoded;
    } catch (e) {
      debugPrint(
        'StorageService getCache error for $key: $e',
      );
      return null;
    }
  }

  static Future<void> unpackAllData(
    Map<String, dynamic> allData,
  ) async {
    final now = DateTime.now();

    await setCache('all_data', allData);

    if (allData['attendance'] != null) {
      await setCache(
        'attendance',
        allData['attendance'],
      );
    }

    if (allData['timetable'] != null) {
      await setCache(
        'timetable',
        allData['timetable'],
      );
    }

    if (allData['marks'] != null) {
      final marks = allData['marks'];

      if (marks is Map &&
          marks.containsKey('marks') &&
          marks['marks'] is List) {
        await setCache(
          'marks',
          marks['marks'],
        );
      } else {
        await setCache(
          'marks',
          marks,
        );
      }
    }

    if (allData['profile'] != null) {
      await setCache(
        'profile',
        allData['profile'],
      );
    }

    if (allData['grade_history'] != null) {
      await setCache(
        'grades',
        allData['grade_history'],
      );
    }

    if (allData['exam_schedule'] != null) {
      await setCache(
        'exam_schedule',
        allData['exam_schedule'],
      );
    }

    debugPrint(
      'StorageService: Unpacked and permanently saved '
      'all features at $now',
    );
  }

  static Future<DateTime?> getLastSynced(
    String key,
  ) async {
    if (_memoryTimestamps.containsKey(key)) {
      return _memoryTimestamps[key];
    }

    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString('cache_$key');

      if (raw == null) return null;

      final decoded = jsonDecode(raw);

      if (decoded is Map &&
          decoded.containsKey('timestamp')) {
        final ts = DateTime.tryParse(
          decoded['timestamp'].toString(),
        );

        if (ts != null) {
          _memoryTimestamps[key] = ts;
          return ts;
        }
      }
    } catch (_) {}

    return null;
  }

  static String formatLastSynced(
    DateTime? dt,
  ) {
    if (dt == null) return 'Never synced';

    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 45) return 'Just now';

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }

    if (diff.inHours < 24 &&
        dt.day == now.day) {
      return 'Today, ${DateFormat('h:mm a').format(dt)}';
    }

    if (diff.inDays < 2) {
      return 'Yesterday, ${DateFormat('h:mm a').format(dt)}';
    }

    return DateFormat(
      'MMM d, h:mm a',
    ).format(dt);
  }
}
