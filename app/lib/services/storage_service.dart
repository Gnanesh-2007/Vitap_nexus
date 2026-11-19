import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Permanent, reliable local storage engine with strict user & semester isolation,
/// schema versioning, corruption resilience, and feature-level TTL policies.
/// Uses SharedPreferences for offline data persistence across app restarts,
/// and FlutterSecureStorage for encrypted student credentials.
class StorageService {
  static const _secureStorage = FlutterSecureStorage();
  static SharedPreferences? _prefs;

  // Schema version for migrations
  static const int currentSchemaVersion = 2;

  static const String _keyUsername = 'vtop_username';
  static const String _keyPassword = 'vtop_password';
  static const String _keySemester = 'vtop_semester_id';
  static const String _keySemesterName = 'vtop_semester_name';
  static const String _keyAvailableSemesters = 'vtop_available_semesters';
  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyAppThemeName = 'app_seed_theme_name';
  static const String _keyAmoledMode = 'app_amoled_mode_enabled';
  static const String _keyVtopSessionId = 'vtop_session_id';
  static const String _keyOnboardingCompleted = 'app_onboarding_completed';
  static const String _keyCustomAvatarPath = 'app_custom_avatar_path';
  static const String _keyPrivacyMode = 'app_privacy_mode_enabled';
  static const String _keyBiometricEnabled = 'app_biometric_lock_enabled';
  static const String _keyAppLockPin = 'app_security_pin';

  // Active user identifier to guarantee 100% cache isolation
  static String? _currentUsername;

  // In-memory hot cache for instant 0ms access across screens
  static final Map<String, dynamic> _memoryCache = {};
  static final Map<String, DateTime> _memoryTimestamps = {};
  static Map<String, String?> _cachedCredentials = {};

  // Feature-level TTLs
  static const Map<String, Duration> featureTtls = {
    'attendance': Duration(minutes: 15),
    'timetable': Duration(hours: 8),
    'marks': Duration(minutes: 45),
    'grades': Duration(hours: 12),
    'grade_history': Duration(hours: 12),
    'profile': Duration(hours: 24),
    'assignments': Duration(minutes: 20),
    'digital_assignments': Duration(minutes: 20),
    'exam_schedule': Duration(hours: 3),
    'biometric': Duration(minutes: 30),
    'outings': Duration(minutes: 30),
    'general_outings': Duration(minutes: 30),
    'weekend_outings': Duration(minutes: 30),
    'payments': Duration(hours: 1),
    'receipts': Duration(hours: 1),
    'courses': Duration(hours: 6),
    'mentor': Duration(hours: 24),
    'faculty': Duration(days: 3650),
    'faculty_directory': Duration(days: 3650),
    'faculty_permanent': Duration(days: 3650),
    'calendar': Duration(days: 3650),
    'academic_calendar': Duration(days: 3650),
    'academic_calendar_permanent': Duration(days: 3650),
    'all_data': Duration(minutes: 15),
  };

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
    'faculty',
    'calendar',
    'mentor',
    'courses',
    'payments',
    'receipts',
    'outings',
    'general_outings',
    'weekend_outings',
    'faculty_directory',
    'faculty_permanent',
    'academic_calendar',
    'academic_calendar_permanent',
  ];

  /// Standardized user + semester scoped cache key
  /// Format: `cache_<USER>_<SEMESTER>_<FEATURE>` or `cache_<USER>_<FEATURE>`
  static String scopedKey(String key, {String? user, String? semesterId}) {
    final u = (user ?? _currentUsername ?? 'GLOBAL').toUpperCase().trim();
    if (semesterId != null && semesterId.isNotEmpty) {
      final cleanSem = semesterId.toUpperCase().trim();
      return 'cache_${u}_${cleanSem}_$key';
    }
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
        final targetSem = creds['semesterId'];
        for (final key in _knownCacheKeys) {
          final semDiskKey = targetSem != null && targetSem.isNotEmpty
              ? scopedKey(key, user: _currentUsername, semesterId: targetSem)
              : null;
          final userDiskKey = scopedKey(key, user: _currentUsername);
          final raw = (semDiskKey != null ? _prefs!.getString(semDiskKey) : null) ?? _prefs!.getString(userDiskKey);

          if (raw != null && raw.isNotEmpty) {
            final corruptKey = (semDiskKey != null && _prefs!.containsKey(semDiskKey)) ? semDiskKey : userDiskKey;
            final decoded = safeJsonDecode(raw, deleteKeyIfCorrupt: corruptKey);
            dynamic dataToCache;
            DateTime? ts;

            if (decoded is Map && decoded.containsKey('data')) {
              dataToCache = decoded['data'];
              if (decoded.containsKey('cachedAt') || decoded.containsKey('timestamp')) {
                final tsStr = (decoded['cachedAt'] ?? decoded['timestamp']).toString();
                ts = DateTime.tryParse(tsStr);
              }
            } else if (decoded != null) {
              dataToCache = decoded;
            }

            if (dataToCache != null) {
              _memoryCache['${_currentUsername}_$key'] = dataToCache;
              if (ts != null) _memoryTimestamps['${_currentUsername}_$key'] = ts;

              if (targetSem != null && targetSem.isNotEmpty) {
                _memoryCache['${_currentUsername}_${targetSem.toUpperCase().trim()}_$key'] = dataToCache;
                if (ts != null) _memoryTimestamps['${_currentUsername}_${targetSem.toUpperCase().trim()}_$key'] = ts;
              }
            }
          }
        }
      }

      // Pre-warm the semester list too.
      final semKey = scopedKey(_keyAvailableSemesters, user: _currentUsername);
      final rawSemesters = _prefs!.getString(semKey) ?? _prefs!.getString(_keyAvailableSemesters);

      if (rawSemesters != null && rawSemesters.isNotEmpty) {
        final decoded = safeJsonDecode(rawSemesters);
        if (decoded is List) {
          _memoryCache[_keyAvailableSemesters] = List<dynamic>.from(decoded);
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

  /// Safe JSON decoding with automatic corruption isolation
  static dynamic safeJsonDecode(String? raw, {String? deleteKeyIfCorrupt}) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (e) {
      debugPrint('StorageService: Corrupted JSON detected ($e)');
      if (deleteKeyIfCorrupt != null) {
        if (_prefs != null) {
          _prefs!.remove(deleteKeyIfCorrupt);
        } else {
          SharedPreferences.getInstance().then((p) => p.remove(deleteKeyIfCorrupt));
        }
        debugPrint('StorageService: Evicted corrupted key $deleteKeyIfCorrupt');
      }
      return null;
    }
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
    // The password never goes into plain SharedPreferences. Drop any old copy.
    await prefs.remove(_keyPassword);

    if (semesterId != null) {
      await prefs.setString('${cleanUser}_$_keySemester', semesterId);
      await prefs.setString(_keySemester, semesterId);
    }

    if (semesterName != null) {
      await prefs.setString('${cleanUser}_$_keySemesterName', semesterName);
      await prefs.setString(_keySemesterName, semesterName);
    }

    _cachedCredentials = {
      'username': cleanUser,
      'password': password,
      'semesterId': semesterId ?? _cachedCredentials['semesterId'],
      'semesterName': semesterName ?? _cachedCredentials['semesterName'],
    };

    // Only the Android Keystore holds the password. If it is slow or fails, the password
    // stays in memory for this session and the user signs in again next time. It is never
    // written to a plain file as a fallback.
    try {
      await _secureStorage
          .write(key: _keyUsername, value: cleanUser)
          .timeout(_keystoreTimeout);
      await _secureStorage
          .write(key: _keyPassword, value: password)
          .timeout(_keystoreTimeout);
    } catch (e) {
      debugPrint('StorageService: could not save the password securely ($e). Kept in memory only.');
    }
  }

  static const Duration _keystoreTimeout = Duration(seconds: 4);
  static const Duration _keystoreReadTimeout = Duration(seconds: 2);

  /// Reads the saved password from the Keystore. Older versions also kept a plain copy in
  /// SharedPreferences: if that is all there is, it is moved into the Keystore and deleted.
  static Future<String?> _readPassword(SharedPreferences prefs) async {
    String? secure;
    try {
      secure = await _secureStorage.read(key: _keyPassword).timeout(_keystoreReadTimeout);
    } catch (_) {}
    final legacy = prefs.getString(_keyPassword);
    if (secure != null && secure.isNotEmpty) {
      if (legacy != null) await prefs.remove(_keyPassword);
      return secure;
    }
    if (legacy != null && legacy.isNotEmpty) {
      try {
        await _secureStorage.write(key: _keyPassword, value: legacy).timeout(_keystoreTimeout);
        final check = await _secureStorage.read(key: _keyPassword).timeout(_keystoreTimeout);
        if (check == legacy) await prefs.remove(_keyPassword);
      } catch (_) {
        // Keep the old copy for now rather than log the user out; try again next launch.
      }
      return legacy;
    }
    return null;
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

  static Future<String?> getSavedSemesterId({String? username}) async {
    final prefs = await _getPrefs();
    final cleanUser = (username ?? _currentUsername)?.toUpperCase().trim();
    if (cleanUser != null) {
      final userSem = prefs.getString('${cleanUser}_$_keySemester');
      if (userSem != null && userSem.isNotEmpty) return userSem;
    }
    return prefs.getString(_keySemester);
  }

  static Future<void> saveVtopSessionId(String? sessionId, {String? username}) async {
    final prefs = await _getPrefs();
    final cleanUser = (username ?? _currentUsername)?.toUpperCase().trim();
    if (sessionId == null || sessionId.isEmpty) {
      if (cleanUser != null) await prefs.remove('${cleanUser}_$_keyVtopSessionId');
      await prefs.remove(_keyVtopSessionId);
    } else {
      if (cleanUser != null) await prefs.setString('${cleanUser}_$_keyVtopSessionId', sessionId);
      await prefs.setString(_keyVtopSessionId, sessionId);
    }
  }

  static Future<String?> getVtopSessionId({String? username}) async {
    final prefs = await _getPrefs();
    final cleanUser = (username ?? _currentUsername)?.toUpperCase().trim();
    if (cleanUser != null) {
      final userSid = prefs.getString('${cleanUser}_$_keyVtopSessionId');
      if (userSid != null && userSid.isNotEmpty) return userSid;
    }
    return prefs.getString(_keyVtopSessionId);
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
      final semKey = scopedKey(_keyAvailableSemesters, user: username);

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
      final semKey = scopedKey(_keyAvailableSemesters, user: username);
      final raw = prefs.getString(semKey) ?? prefs.getString(_keyAvailableSemesters);

      if (raw == null || raw.isEmpty) return [];
      final decoded = safeJsonDecode(raw);
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
    if (_cachedCredentials.isNotEmpty &&
        _cachedCredentials['username'] != null &&
        _cachedCredentials['username']!.isNotEmpty &&
        _cachedCredentials['password'] != null &&
        _cachedCredentials['password']!.isNotEmpty) {
      return _cachedCredentials;
    }

    final prefs = await _getPrefs();

    var username = prefs.getString(_keyUsername);
    var semesterId = prefs.getString(_keySemester);
    var semesterName = prefs.getString(_keySemesterName);

    if (username == null || username.isEmpty) {
      try {
        final secUser = await _secureStorage.read(key: _keyUsername).timeout(_keystoreReadTimeout);
        if (secUser != null && secUser.isNotEmpty) username = secUser;
      } catch (_) {}
    }
    final password = (username == null || username.isEmpty) ? null : await _readPassword(prefs);

    if (username != null && username.isNotEmpty) {
      _currentUsername = username.toUpperCase().trim();
      semesterId ??= prefs.getString('${_currentUsername}_$_keySemester');
      semesterName ??= prefs.getString('${_currentUsername}_$_keySemesterName');
    }

    final creds = {
      'username': username,
      'password': password,
      'semesterId': semesterId,
      'semesterName': semesterName,
    };
    _cachedCredentials = creds;
    return creds;
  }

  static Map<String, String?> getCredentialsSync() {
    if (_cachedCredentials.isNotEmpty && _cachedCredentials['username'] != null) {
      return _cachedCredentials;
    }
    // The password lives only in the Keystore, which can only be read asynchronously.
    // getCredentials() (run at startup) fills the cache; until then there is nothing to return.
    return {};
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
    _cachedCredentials = {};
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

  /// Clears cache for a specific feature key.
  static Future<void> removeCache(String key, {String? username, String? semesterId}) async {
    final u = (username ?? _currentUsername)?.toUpperCase().trim();
    if (u == null || u.isEmpty) return;

    final memKey = semesterId != null && semesterId.isNotEmpty
        ? '${u}_${semesterId.toUpperCase().trim()}_$key'
        : '${u}_$key';
    final diskKey = scopedKey(key, user: u, semesterId: semesterId);

    _memoryCache.remove(memKey);
    _memoryCache.remove('${u}_$key');
    _memoryTimestamps.remove(memKey);
    _memoryTimestamps.remove('${u}_$key');

    try {
      final prefs = await _getPrefs();
      await prefs.remove(diskKey);
      await prefs.remove(scopedKey(key, user: u));
    } catch (_) {}
  }

  // ============================================================
  // SYNCHRONOUS MEMORY ACCESS (USER-SCOPED)
  // ============================================================

  static dynamic getMemoryCache(String key, {String? username, String? semesterId}) {
    final u = (username ?? _currentUsername)?.toUpperCase().trim();
    if (u == null || u.isEmpty) return null;
    if (semesterId != null && semesterId.isNotEmpty) {
      final semKey = '${u}_${semesterId.toUpperCase().trim()}_$key';
      if (_memoryCache.containsKey(semKey)) return _memoryCache[semKey];
    }
    return _memoryCache['${u}_$key'];
  }

  static DateTime? getMemoryTimestamp(String key, {String? username, String? semesterId}) {
    final u = (username ?? _currentUsername)?.toUpperCase().trim();
    if (u == null || u.isEmpty) return null;
    if (semesterId != null && semesterId.isNotEmpty) {
      final semKey = '${u}_${semesterId.toUpperCase().trim()}_$key';
      if (_memoryTimestamps.containsKey(semKey)) return _memoryTimestamps[semKey];
    }
    return _memoryTimestamps['${u}_$key'];
  }

  // ============================================================
  // PERMANENT FEATURE CACHE (USER & SEMESTER SCOPED)
  // ============================================================

  /// Validates data integrity before writing to cache
  static bool validatePayload(String feature, dynamic data) {
    if (data == null) return false;
    switch (feature) {
      case 'attendance':
        if (data is Map) {
          // If courses list is present, ensure valid structure
          if (data.containsKey('courses') && data['courses'] is! List) return false;
          return true;
        }
        return data is List;
      case 'timetable':
      case 'marks':
      case 'grades':
      case 'grade_history':
      case 'exam_schedule':
      case 'assignments':
      case 'digital_assignments':
      case 'faculty':
      case 'faculty_directory':
      case 'calendar':
      case 'academic_calendar':
      case 'outings':
      case 'general_outings':
      case 'weekend_outings':
      case 'payments':
      case 'receipts':
      case 'courses':
      case 'mentor':
      case 'biometric':
        return data is Map || data is List;
      case 'profile':
      case 'all_data':
        return data is Map;
      default:
        return true;
    }
  }

  static Future<void> setCache(
    String key,
    dynamic data, {
    String? username,
    String? semesterId,
  }) async {
    if (data == null) return;
    if (!validatePayload(key, data)) {
      debugPrint('StorageService: Validation rejected payload for $key');
      return;
    }

    final u = (username ?? _currentUsername)?.toUpperCase().trim();
    if (u == null || u.isEmpty) return;

    final now = DateTime.now();
    final memKey = semesterId != null && semesterId.isNotEmpty
        ? '${u}_${semesterId.toUpperCase().trim()}_$key'
        : '${u}_$key';
    final diskKey = scopedKey(key, user: u, semesterId: semesterId);

    _memoryCache[memKey] = data;
    _memoryTimestamps[memKey] = now;
    // Also mirror to base key for instant fallback
    _memoryCache['${u}_$key'] = data;
    _memoryTimestamps['${u}_$key'] = now;

    try {
      final prefs = await _getPrefs();
      final payload = jsonEncode({
        'schemaVersion': currentSchemaVersion,
        'user': u,
        'semesterId': semesterId,
        'feature': key,
        'cachedAt': now.toIso8601String(),
        'timestamp': now.toIso8601String(),
        'data': data,
      });

      await prefs.setString(diskKey, payload);
      if (semesterId != null && semesterId.isNotEmpty) {
        // Also save to generic key for fallback
        final baseDiskKey = scopedKey(key, user: u);
        await prefs.setString(baseDiskKey, payload);
      }
    } catch (e) {
      debugPrint('StorageService setCache error for $diskKey: $e');
    }
  }

  static Future<dynamic> getCache(
    String key, {
    String? username,
    String? semesterId,
  }) async {
    final u = (username ?? _currentUsername)?.toUpperCase().trim();
    if (u == null || u.isEmpty) return null;

    final memKey = semesterId != null && semesterId.isNotEmpty
        ? '${u}_${semesterId.toUpperCase().trim()}_$key'
        : '${u}_$key';

    if (_memoryCache.containsKey(memKey)) {
      return _memoryCache[memKey];
    }
    if (_memoryCache.containsKey('${u}_$key')) {
      return _memoryCache['${u}_$key'];
    }

    try {
      final prefs = await _getPrefs();
      final diskKey = scopedKey(key, user: u, semesterId: semesterId);
      var raw = prefs.getString(diskKey);
      if (raw == null && semesterId != null) {
        raw = prefs.getString(scopedKey(key, user: u));
      }

      if (raw == null || raw.isEmpty) return null;

      final decoded = safeJsonDecode(raw, deleteKeyIfCorrupt: diskKey);
      if (decoded == null) return null;

      if (decoded is Map && decoded.containsKey('data')) {
        // Enforce user ownership verification on payload
        if (decoded.containsKey('user') && decoded['user'] != u) {
          debugPrint('StorageService: Discarded mismatched cache for $diskKey');
          await prefs.remove(diskKey);
          return null;
        }

        final data = decoded['data'];
        _memoryCache[memKey] = data;
        _memoryCache['${u}_$key'] = data;

        final tsStr = (decoded['cachedAt'] ?? decoded['timestamp'])?.toString();
        if (tsStr != null) {
          final ts = DateTime.tryParse(tsStr);
          if (ts != null) {
            _memoryTimestamps[memKey] = ts;
            _memoryTimestamps['${u}_$key'] = ts;
          }
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

  static Future<bool> hasCache(String key, {String? username, String? semesterId}) async {
    final data = await getCache(key, username: username, semesterId: semesterId);
    return data != null;
  }

  /// Checks if cached feature data is older than its configured TTL
  static bool isFeatureStale(
    String key, {
    String? user,
    String? semesterId,
    Duration? customTtl,
  }) {
    final u = (user ?? _currentUsername)?.toUpperCase().trim();
    if (u == null || u.isEmpty) return true;

    final ts = getMemoryTimestamp(key, username: u, semesterId: semesterId);
    if (ts == null) return true;

    final ttl = customTtl ?? featureTtls[key] ?? const Duration(minutes: 15);
    return DateTime.now().difference(ts) > ttl;
  }

  static Future<void> unpackAllData(
    Map<String, dynamic> allData, {
    String? username,
    String? semesterId,
  }) async {
    final u = (username ?? _currentUsername)?.toUpperCase().trim();
    if (u == null || u.isEmpty) return;

    final hasValidField = allData['profile'] != null ||
        allData['attendance'] != null ||
        allData['timetable'] != null ||
        allData['marks'] != null ||
        allData['grade_history'] != null ||
        allData['exam_schedule'] != null;

    if (!hasValidField) {
      debugPrint('StorageService: Ignored unpackAllData because all core fields were null.');
      return;
    }

    // Merge non-null fields onto existing all_data so partial responses never wipe cached sub-fields
    final existing = await getCache('all_data', username: u, semesterId: semesterId);
    final mergedAllData = <String, dynamic>{
      if (existing is Map) ...Map<String, dynamic>.from(existing),
    };
    for (final entry in allData.entries) {
      if (entry.value != null) {
        mergedAllData[entry.key] = entry.value;
      }
    }

    await setCache('all_data', mergedAllData, username: u, semesterId: semesterId);
    if (semesterId != null && semesterId.isNotEmpty) {
      await setCache('all_data', mergedAllData, username: u);
    }

    if (allData['attendance'] != null) {
      await setCache('attendance', allData['attendance'], username: u, semesterId: semesterId);
      if (semesterId != null && semesterId.isNotEmpty) {
        await setCache('attendance', allData['attendance'], username: u);
      }
    }

    if (allData['timetable'] != null) {
      await setCache('timetable', allData['timetable'], username: u, semesterId: semesterId);
      if (semesterId != null && semesterId.isNotEmpty) {
        await setCache('timetable', allData['timetable'], username: u);
      }
    }

    if (allData['marks'] != null) {
      final marks = allData['marks'];
      if (marks is Map && marks.containsKey('marks') && marks['marks'] is List) {
        await setCache('marks', marks['marks'], username: u, semesterId: semesterId);
        if (semesterId != null && semesterId.isNotEmpty) {
          await setCache('marks', marks['marks'], username: u);
        }
      } else {
        await setCache('marks', marks, username: u, semesterId: semesterId);
        if (semesterId != null && semesterId.isNotEmpty) {
          await setCache('marks', marks, username: u);
        }
      }
    }

    if (allData['profile'] != null) {
      await setCache('profile', allData['profile'], username: u);
    }

    if (allData['grade_history'] != null) {
      await setCache('grades', allData['grade_history'], username: u, semesterId: semesterId);
      if (semesterId != null && semesterId.isNotEmpty) {
        await setCache('grades', allData['grade_history'], username: u);
      }
    }

    if (allData['exam_schedule'] != null) {
      await setCache('exam_schedule', allData['exam_schedule'], username: u, semesterId: semesterId);
      if (semesterId != null && semesterId.isNotEmpty) {
        await setCache('exam_schedule', allData['exam_schedule'], username: u);
      }
    }

    debugPrint('StorageService: Unpacked all features cleanly for user $u (sem: $semesterId)');
  }

  static Future<DateTime?> getLastSynced(
    String key, {
    String? username,
    String? semesterId,
  }) async {
    final u = (username ?? _currentUsername)?.toUpperCase().trim();
    if (u == null || u.isEmpty) return null;

    final memKey = semesterId != null && semesterId.isNotEmpty
        ? '${u}_${semesterId.toUpperCase().trim()}_$key'
        : '${u}_$key';

    if (_memoryTimestamps.containsKey(memKey)) {
      return _memoryTimestamps[memKey];
    }
    if (_memoryTimestamps.containsKey('${u}_$key')) {
      return _memoryTimestamps['${u}_$key'];
    }

    // Check alias keys for compatibility
    final aliases = _getKeyAliases(key);
    for (final alias in aliases) {
      final aliasMemKey = semesterId != null && semesterId.isNotEmpty
          ? '${u}_${semesterId.toUpperCase().trim()}_$alias'
          : '${u}_$alias';
      if (_memoryTimestamps.containsKey(aliasMemKey)) {
        return _memoryTimestamps[aliasMemKey];
      }
      if (_memoryTimestamps.containsKey('${u}_$alias')) {
        return _memoryTimestamps['${u}_$alias'];
      }
    }

    try {
      final prefs = await _getPrefs();
      final keysToCheck = [key, ...aliases];
      for (final k in keysToCheck) {
        final diskKey = scopedKey(k, user: u, semesterId: semesterId);
        var raw = prefs.getString(diskKey);
        if (raw == null && semesterId != null) {
          raw = prefs.getString(scopedKey(k, user: u));
        }

        if (raw != null) {
          final decoded = safeJsonDecode(raw, deleteKeyIfCorrupt: diskKey);
          if (decoded is Map) {
            final tsStr = (decoded['cachedAt'] ?? decoded['timestamp'])?.toString();
            if (tsStr != null) {
              final ts = DateTime.tryParse(tsStr);
              if (ts != null) {
                _memoryTimestamps[memKey] = ts;
                return ts;
              }
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }

  static List<String> _getKeyAliases(String key) {
    switch (key) {
      case 'faculty':
        return ['faculty_directory', 'faculty_permanent'];
      case 'faculty_directory':
        return ['faculty', 'faculty_permanent'];
      case 'calendar':
        return ['academic_calendar', 'academic_calendar_permanent'];
      case 'academic_calendar':
        return ['calendar', 'academic_calendar_permanent'];
      case 'outings':
        return ['general_outings', 'weekend_outings'];
      case 'grades':
        return ['grade_history'];
      case 'grade_history':
        return ['grades'];
      case 'assignments':
        return ['digital_assignments'];
      case 'digital_assignments':
        return ['assignments'];
      default:
        return [];
    }
  }

  /// Eviction policy: Clean up caches for older semesters keeping only the most recent ones
  static Future<int> pruneOldSemesterCaches({
    String? username,
    int maxSemestersToKeep = 1,
  }) async {
    int evictedCount = 0;
    try {
      final prefs = await _getPrefs();
      final u = (username ?? _currentUsername)?.toUpperCase().trim();
      if (u == null || u.isEmpty) return 0;

      final allKeys = prefs.getKeys().toList();
      final userPrefix = 'cache_${u}_';
      final semesterKeys = <String>{};

      for (final k in allKeys) {
        if (k.startsWith(userPrefix) && !k.endsWith('_permanent')) {
          final remainder = k.substring(userPrefix.length);
          final lastUnderscore = remainder.lastIndexOf('_');
          if (lastUnderscore > 0) {
            final sem = remainder.substring(0, lastUnderscore);
            semesterKeys.add(sem);
          }
        }
      }

      if (semesterKeys.length > maxSemestersToKeep) {
        final sorted = semesterKeys.toList()..sort();
        final toRemove = sorted.take(sorted.length - maxSemestersToKeep).toSet();
        for (final k in allKeys) {
          if (k.startsWith(userPrefix) && !k.endsWith('_permanent')) {
            final remainder = k.substring(userPrefix.length);
            final lastUnderscore = remainder.lastIndexOf('_');
            if (lastUnderscore > 0) {
              final sem = remainder.substring(0, lastUnderscore);
              if (toRemove.contains(sem)) {
                await prefs.remove(k);
                evictedCount++;
                debugPrint('StorageService: Evicted old semester cache key $k');
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('StorageService pruneOldSemesterCaches error: $e');
    }
    return evictedCount;
  }

  /// Clears only cached feature payloads for the user, retaining credentials, settings, and permanent caches.
  static Future<int> clearFeatureCaches({String? username}) async {
    final u = (username ?? _currentUsername)?.toUpperCase().trim();
    if (u == null || u.isEmpty) return 0;

    int count = 0;
    _memoryCache.removeWhere((key, _) => key.startsWith(u) && !key.endsWith('_permanent'));
    _memoryTimestamps.removeWhere((key, _) => key.startsWith(u) && !key.endsWith('_permanent'));

    final prefs = await _getPrefs();
    final allKeys = prefs.getKeys().toList();
    final userPrefix = 'cache_${u}_';
    for (final k in allKeys) {
      if (k.startsWith(userPrefix) && !k.endsWith('_permanent')) {
        await prefs.remove(k);
        count++;
      }
    }
    return count;
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

  static ThemeMode getThemeMode() {
    final val = _prefs?.getString(_keyThemeMode);
    if (val == 'light') return ThemeMode.light;
    return ThemeMode.dark;
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await _getPrefs();
    final str = mode == ThemeMode.light ? 'light' : 'dark';
    await prefs.setString(_keyThemeMode, str);
  }

  static String getAppThemeNameSync() {
    return _prefs?.getString(_keyAppThemeName) ?? 'blue';
  }

  static Future<void> setAppThemeName(String themeName) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyAppThemeName, themeName);
  }

  static bool isAmoledModeEnabledSync() {
    return _prefs?.getBool(_keyAmoledMode) ?? false;
  }

  static Future<void> setAmoledModeEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyAmoledMode, enabled);
  }

  static bool isOnboardingCompletedSync() {
    return _prefs?.getBool(_keyOnboardingCompleted) ?? false;
  }

  static Future<void> setOnboardingCompleted(bool completed) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyOnboardingCompleted, completed);
  }

  /// Bumped whenever the chosen avatar changes, so screens showing it can refresh.
  static final ValueNotifier<int> avatarChanged = ValueNotifier<int>(0);

  static String? getCustomAvatarPathSync() {
    return _prefs?.getString(_keyCustomAvatarPath);
  }

  static Future<void> setCustomAvatarPath(String? path) async {
    final prefs = await _getPrefs();
    if (path == null || path.isEmpty) {
      await prefs.remove(_keyCustomAvatarPath);
    } else {
      await prefs.setString(_keyCustomAvatarPath, path);
    }
    avatarChanged.value++;
  }

  static bool isPrivacyModeEnabledSync() {
    return _prefs?.getBool(_keyPrivacyMode) ?? false;
  }

  static Future<void> setPrivacyModeEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyPrivacyMode, enabled);
  }

  static bool isBiometricEnabledSync() {
    return _prefs?.getBool(_keyBiometricEnabled) ?? false;
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyBiometricEnabled, enabled);
  }

  static String? getAppLockPinSync() {
    final val = _prefs?.getString(_keyAppLockPin);
    if (val == null || val.trim().isEmpty) return null;
    return val.trim();
  }

  static Future<void> setAppLockPin(String? pin) async {
    final prefs = await _getPrefs();
    if (pin == null || pin.trim().isEmpty) {
      await prefs.remove(_keyAppLockPin);
    } else {
      await prefs.setString(_keyAppLockPin, pin.trim());
    }
  }
}
