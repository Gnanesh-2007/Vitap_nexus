import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Permanent, reliable local storage engine with strict user-level session isolation.
/// Uses SharedPreferences for offline data persistence across app restarts,
/// and FlutterSecureStorage for encrypted student credentials.
class StorageService {
  static const _secureStorage = FlutterSecureStorage();
  static SharedPreferences? _prefs;

  static const String _keyUsername = 'vtop_username';
  static const String _keyPassword = 'vtop_password';
  static const String _keySemester = 'vtop_semester_id';
  static const String _keySemesterName = 'vtop_semester_name';
  static const String _keyAvailableSemesters = 'vtop_available_semesters';

  // Active user identifier to guarantee 100% cache isolation
  static String? _currentUsername;

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
    'receipts',
    'courses',
    'mentor',
  ];

  static String _scopedKey(String key, [String? user]) {
    final u = (user ?? _currentUsername ?? 'GLOBAL').toUpperCase().trim();
    return 'cache_${u}_$key';
  }

  /// Sets the active authenticated user and warms the cache for that specific user.
  static void setCurrentUser(String? username) {
    final clean = username?.toUpperCase().trim();
    if (_currentUsername != clean) {
      _currentUsername = clean;
      _memoryCache.clear();
      _memoryTimestamps.clear();
      debugPrint('StorageService: Switched active user context to: $clean');
    }
  }

  static String? get currentUsername => _currentUsername;

  /// Pre-warms the in-memory cache on app startup for the saved user.
  static Future<void> initCache([String? username]) async {
    try {
      _prefs = await SharedPreferences.getInstance();

      final creds = await getCredentials();
      final targetUser = (username ?? creds['username'] ?? _currentUsername)?.toUpperCase().trim();

      if (targetUser != null && targetUser.isNotEmpty) {
        _currentUsername = targetUser;
      }

      _memoryCache.clear();
      _memoryTimestamps.clear();

      if (_currentUsername != null && _currentUsername!.isNotEmpty) {
        for (final key in _knownCacheKeys) {
          final scoped = _scopedKey(key, _currentUsername);
          final raw = _prefs!.getString(scoped);
          if (raw != null && raw.isNotEmpty) {
            try {
              final decoded = jsonDecode(raw);
              if (decoded is Map && decoded.containsKey('data')) {
                _memoryCache['${_currentUsername}_$key'] = decoded['data'];
                if (decoded.containsKey('timestamp')) {
                  final ts = DateTime.tryParse(decoded['timestamp'].toString());
                  if (ts != null) _memoryTimestamps['${_currentUsername}_$key'] = ts;
                }
              } else {
                _memoryCache['${_currentUsername}_$key'] = decoded;
              }
            } catch (decodeErr) {
              debugPrint('StorageService decode error for $scoped: $decodeErr');
            }
          }
        }
      }

      // Pre-warm the semester list too.
      final semKey = _scopedKey(_keyAvailableSemesters, _currentUsername);
      final rawSemesters = _prefs!.getString(semKey) ?? _prefs!.getString(_keyAvailableSemesters);

      if (rawSemesters != null && rawSemesters.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawSemesters);
          if (decoded is List) {
            _memoryCache[_keyAvailableSemesters] = List<dynamic>.from(decoded);
          }
        } catch (e) {
          debugPrint('StorageService semester list decode error: $e');
        }
      }

      debugPrint(
        'StorageService: Pre-warmed ${_memoryCache.length} features for user $_currentUsername',
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
    final cleanUser = username.toUpperCase().trim();
    setCurrentUser(cleanUser);

    final prefs = await _getPrefs();

    await prefs.setString(_keyUsername, cleanUser);
    await prefs.setString(_keyPassword, password);

    if (semesterId != null) {
      await prefs.setString('${cleanUser}_$_keySemester', semesterId);
      await prefs.setString(_keySemester, semesterId);
    }

    if (semesterName != null) {
      await prefs.setString('${cleanUser}_$_keySemesterName', semesterName);
      await prefs.setString(_keySemesterName, semesterName);
    }

    try {
      await _secureStorage.write(
        key: _keyUsername,
        value: cleanUser,
      );
      await _secureStorage.write(
        key: _keyPassword,
        value: password,
      );
    } catch (_) {}
  }

  static Future<void> saveSemester(
    String semesterId,
    String semesterName, {
    String? username,
  }) async {
    final prefs = await _getPrefs();
    final cleanUser = (username ?? _currentUsername)?.toUpperCase().trim();

    if (cleanUser != null) {
      await prefs.setString('${cleanUser}_$_keySemester', semesterId);
      await prefs.setString('${cleanUser}_$_keySemesterName', semesterName);
    }

    await prefs.setString(_keySemester, semesterId);
    await prefs.setString(_keySemesterName, semesterName);
  }

  static Future<void> saveAvailableSemesters(
    List<Map<String, dynamic>> semesters, {
    String? username,
  }) async {
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
      final encoded = jsonEncode(normalized);
      final semKey = _scopedKey(_keyAvailableSemesters, username);

      await prefs.setString(semKey, encoded);
      await prefs.setString(_keyAvailableSemesters, encoded);
    } catch (e) {
      debugPrint('StorageService saveAvailableSemesters error: $e');
    }
  }

  static List<Map<String, dynamic>> getAvailableSemestersSync() {
    final data = _memoryCache[_keyAvailableSemesters];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getAvailableSemesters({String? username}) async {
    final memory = getAvailableSemestersSync();
    if (memory.isNotEmpty) return memory;

    try {
      final prefs = await _getPrefs();
      final semKey = _scopedKey(_keyAvailableSemesters, username);
      final raw = prefs.getString(semKey) ?? prefs.getString(_keyAvailableSemesters);

      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final result = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      _memoryCache[_keyAvailableSemesters] = result;
      return result;
    } catch (e) {
      debugPrint('StorageService getAvailableSemesters error: $e');
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
        username ??= await _secureStorage.read(key: _keyUsername);
        password ??= await _secureStorage.read(key: _keyPassword);
      } catch (_) {}
    }

    if (username != null && username.isNotEmpty) {
      _currentUsername = username.toUpperCase().trim();
      semesterId ??= prefs.getString('${_currentUsername}_$_keySemester');
      semesterName ??= prefs.getString('${_currentUsername}_$_keySemesterName');
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

  /// Completely wipes all stored credentials, tokens, session keys, and in-memory caches.
  static Future<void> clearAll() async {
    _currentUsername = null;
    _memoryCache.clear();
    _memoryTimestamps.clear();

    final prefs = await _getPrefs();
    await prefs.clear();

    try {
      await _secureStorage.deleteAll();
    } catch (_) {}

    debugPrint('StorageService: Completely cleared all storage, memory, and credentials.');
  }

  /// Clears storage and caches for a specific user.
  static Future<void> clearUser(String username) async {
    final clean = username.toUpperCase().trim();
    _memoryCache.removeWhere((key, _) => key.startsWith(clean));
    _memoryTimestamps.removeWhere((key, _) => key.startsWith(clean));

    if (_currentUsername == clean) {
      _currentUsername = null;
    }

    final prefs = await _getPrefs();
    final allKeys = prefs.getKeys().toList();
    for (final k in allKeys) {
      if (k.contains(clean)) {
        await prefs.remove(k);
      }
    }
  }

  // ============================================================
  // SYNCHRONOUS MEMORY ACCESS (USER-SCOPED)
  // ============================================================

  static dynamic getMemoryCache(String key, {String? username}) {
    final u = (username ?? _currentUsername)?.toUpperCase().trim();
    if (u == null || u.isEmpty) return null;
    return _memoryCache['${u}_$key'];
  }

  static DateTime? getMemoryTimestamp(String key, {String? username}) {
    final u = (username ?? _currentUsername)?.toUpperCase().trim();
    if (u == null || u.isEmpty) return null;
    return _memoryTimestamps['${u}_$key'];
  }

  // ============================================================
  // PERMANENT FEATURE CACHE (USER-SCOPED)
  // ============================================================

  static Future<void> setCache(
    String key,
    dynamic data, {
    String? username,
  }) async {
    if (data == null) return;

    final u = (username ?? _currentUsername)?.toUpperCase().trim();
    if (u == null || u.isEmpty) return;

    final now = DateTime.now();
    final memKey = '${u}_$key';
    final diskKey = _scopedKey(key, u);

    _memoryCache[memKey] = data;
    _memoryTimestamps[memKey] = now;

    try {
      final prefs = await _getPrefs();
      final payload = jsonEncode({
        'user': u,
        'timestamp': now.toIso8601String(),
        'data': data,
      });

      await prefs.setString(diskKey, payload);
    } catch (e) {
      debugPrint('StorageService setCache error for $diskKey: $e');
    }
  }

  static Future<dynamic> getCache(String key, {String? username}) async {
    final u = (username ?? _currentUsername)?.toUpperCase().trim();
    if (u == null || u.isEmpty) return null;

    final memKey = '${u}_$key';
    if (_memoryCache.containsKey(memKey)) {
      return _memoryCache[memKey];
    }

    try {
      final prefs = await _getPrefs();
      final diskKey = _scopedKey(key, u);
      final raw = prefs.getString(diskKey);

      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);

      if (decoded is Map && decoded.containsKey('data')) {
        // Enforce user ownership verification on payload
        if (decoded.containsKey('user') && decoded['user'] != u) {
          debugPrint('StorageService: Discarded mismatched cache for $diskKey');
          await prefs.remove(diskKey);
          return null;
        }

        final data = decoded['data'];
        _memoryCache[memKey] = data;

        if (decoded.containsKey('timestamp')) {
          final ts = DateTime.tryParse(decoded['timestamp'].toString());
          if (ts != null) _memoryTimestamps[memKey] = ts;
        }

        return data;
      }

      _memoryCache[memKey] = decoded;
      return decoded;
    } catch (e) {
      debugPrint('StorageService getCache error for $key: $e');
      return null;
    }
  }

  static Future<bool> hasCache(String key, {String? username}) async {
    final data = await getCache(key, username: username);
    return data != null;
  }

  static Future<void> unpackAllData(
    Map<String, dynamic> allData, {
    String? username,
  }) async {
    final u = (username ?? _currentUsername)?.toUpperCase().trim();
    if (u == null || u.isEmpty) return;

    await setCache('all_data', allData, username: u);

    if (allData['attendance'] != null) {
      await setCache('attendance', allData['attendance'], username: u);
    }

    if (allData['timetable'] != null) {
      await setCache('timetable', allData['timetable'], username: u);
    }

    if (allData['marks'] != null) {
      final marks = allData['marks'];
      if (marks is Map && marks.containsKey('marks') && marks['marks'] is List) {
        await setCache('marks', marks['marks'], username: u);
      } else {
        await setCache('marks', marks, username: u);
      }
    }

    if (allData['profile'] != null) {
      await setCache('profile', allData['profile'], username: u);
    }

    if (allData['grade_history'] != null) {
      await setCache('grades', allData['grade_history'], username: u);
    }

    if (allData['exam_schedule'] != null) {
      await setCache('exam_schedule', allData['exam_schedule'], username: u);
    }

    debugPrint('StorageService: Unpacked all features cleanly for user $u');
  }

  static Future<DateTime?> getLastSynced(String key, {String? username}) async {
    final u = (username ?? _currentUsername)?.toUpperCase().trim();
    if (u == null || u.isEmpty) return null;

    final memKey = '${u}_$key';
    if (_memoryTimestamps.containsKey(memKey)) {
      return _memoryTimestamps[memKey];
    }

    try {
      final prefs = await _getPrefs();
      final diskKey = _scopedKey(key, u);
      final raw = prefs.getString(diskKey);

      if (raw == null) return null;
      final decoded = jsonDecode(raw);

      if (decoded is Map && decoded.containsKey('timestamp')) {
        final ts = DateTime.tryParse(decoded['timestamp'].toString());
        if (ts != null) {
          _memoryTimestamps[memKey] = ts;
          return ts;
        }
      }
    } catch (_) {}

    return null;
  }

  static String formatLastSynced(DateTime? dt) {
    if (dt == null) return 'Never synced';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24 && dt.day == now.day) {
      return 'Today, ${DateFormat('h:mm a').format(dt)}';
    }
    if (diff.inDays < 2) return 'Yesterday, ${DateFormat('h:mm a').format(dt)}';
    return DateFormat('MMM d, h:mm a').format(dt);
  }
}
