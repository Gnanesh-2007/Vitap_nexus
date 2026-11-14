import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitap_nexus_app/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.initCache();
    await StorageService.clearAll();
  });

  group('StorageService Unit Tests', () {
    test('Scopes keys correctly by user and semester', () {
      final keyWithoutSem = StorageService.scopedKey('attendance', user: '22BCE1001');
      expect(keyWithoutSem, 'cache_22BCE1001_attendance');

      final keyWithSem = StorageService.scopedKey('attendance', user: '22BCE1001', semesterId: 'AP2024252');
      expect(keyWithSem, 'cache_22BCE1001_AP2024252_attendance');
    });

    test('Isolates cache between different student users', () async {
      StorageService.setCurrentUser('USER_A');
      await StorageService.setCache('marks', [{'course': 'CSE1001', 'mark': 95}], username: 'USER_A');

      StorageService.setCurrentUser('USER_B');
      final userBCache = await StorageService.getCache('marks', username: 'USER_B');
      expect(userBCache, isNull);

      final userACache = await StorageService.getCache('marks', username: 'USER_A');
      expect(userACache, isNotNull);
      expect((userACache as List).first['course'], 'CSE1001');
    });

    test('Validates payload before caching and rejects malformed data', () {
      expect(StorageService.validatePayload('attendance', {'courses': 'not_a_list'}), isFalse);
      expect(StorageService.validatePayload('attendance', [{'course': 'CSE1001'}]), isTrue);
      expect(StorageService.validatePayload('timetable', {'Monday': []}), isTrue);
      expect(StorageService.validatePayload('profile', 'invalid_string'), isFalse);
    });

    test('Handles JSON corruption gracefully without crashing', () async {
      await StorageService.initCache('TEST_USER');
      final prefs = await SharedPreferences.getInstance();
      final key = StorageService.scopedKey('attendance', user: 'TEST_USER');
      await prefs.setString(key, '{corrupted_invalid_json:');

      final decoded = StorageService.safeJsonDecode(prefs.getString(key), deleteKeyIfCorrupt: key);
      expect(decoded, isNull);
      expect(prefs.containsKey(key), isFalse); // Ensure corrupted key was evicted
    });

    test('Calculates feature TTL staleness accurately', () async {
      StorageService.setCurrentUser('TEST_USER');
      await StorageService.setCache('attendance', [{'course': 'MAT1001'}], username: 'TEST_USER');

      final isStaleFresh = StorageService.isFeatureStale('attendance', user: 'TEST_USER');
      expect(isStaleFresh, isFalse);

      final isStaleCustom = StorageService.isFeatureStale(
        'attendance',
        user: 'TEST_USER',
        customTtl: const Duration(milliseconds: -1), // Expired immediately
      );
      expect(isStaleCustom, isTrue);
    });

    test('Prunes old semester caches when quota exceeded', () async {
      await StorageService.initCache('STUDENT_X');
      final prefs = await SharedPreferences.getInstance();
      const user = 'STUDENT_X';

      await prefs.setString('cache_${user}_SEM1_attendance', '{"data": []}');
      await prefs.setString('cache_${user}_SEM2_attendance', '{"data": []}');
      await prefs.setString('cache_${user}_SEM3_attendance', '{"data": []}');
      await prefs.setString('cache_${user}_SEM4_attendance', '{"data": []}');

      await StorageService.pruneOldSemesterCaches(username: user, maxSemestersToKeep: 2);

      // SEM1 and SEM2 should be pruned, SEM3 and SEM4 kept
      expect(prefs.containsKey('cache_${user}_SEM1_attendance'), isFalse);
      expect(prefs.containsKey('cache_${user}_SEM2_attendance'), isFalse);
      expect(prefs.containsKey('cache_${user}_SEM3_attendance'), isTrue);
      expect(prefs.containsKey('cache_${user}_SEM4_attendance'), isTrue);
    });

    test('Stores and retrieves theme mode correctly', () async {
      await StorageService.setThemeMode(ThemeMode.dark);
      expect(StorageService.getThemeMode(), ThemeMode.dark);

      await StorageService.setThemeMode(ThemeMode.light);
      expect(StorageService.getThemeMode(), ThemeMode.light);
    });
  });
}
