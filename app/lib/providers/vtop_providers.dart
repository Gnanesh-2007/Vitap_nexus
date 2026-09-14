import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';

// All Data Provider (Dashboard)
final allDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    throw Exception('Not authenticated');
  }

  final semId = auth.activeSemesterId ?? '';
  return await apiService.fetchAllData(
    username: auth.username!,
    password: auth.password!,
    semSubId: semId,
  );
});

// Attendance Provider
final attendanceProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    throw Exception('Not authenticated');
  }

  final semId = auth.activeSemesterId ?? '';
  return await apiService.fetchAttendance(
    username: auth.username!,
    password: auth.password!,
    semSubId: semId,
  );
});

// Timetable Provider
final timetableProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    throw Exception('Not authenticated');
  }

  final semId = auth.activeSemesterId ?? '';
  return await apiService.fetchTimetable(
    username: auth.username!,
    password: auth.password!,
    semSubId: semId,
  );
});

// Marks Provider
final marksProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    throw Exception('Not authenticated');
  }

  final semId = auth.activeSemesterId ?? '';
  return await apiService.fetchMarks(
    username: auth.username!,
    password: auth.password!,
    semSubId: semId,
  );
});

// Profile Provider
final profileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    throw Exception('Not authenticated');
  }

  return await apiService.fetchProfile(
    auth.username!,
    auth.password!,
  );
});

// Exam Schedule Provider
final examScheduleProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.username == null || auth.password == null) {
    throw Exception('Not authenticated');
  }

  final semId = auth.activeSemesterId ?? '';
  return await apiService.fetchTimetable(
    username: auth.username!,
    password: auth.password!,
    semSubId: semId,
  );
});
