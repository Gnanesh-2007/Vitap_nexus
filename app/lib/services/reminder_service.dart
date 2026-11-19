import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Class and exam reminders. They are local notifications and are off until the user
/// turns them on. The settings are stored here; the Android side reads them and sets
/// the alarms (see Reminders.kt).
class ReminderService {
  ReminderService._();

  static const _channel = MethodChannel('com.vitap.vitap_nexus_app/widgets');
  static const enabledKey = 'reminders_enabled';
  static const classMinutesKey = 'reminders_class_min';
  static const examKey = 'reminders_exam';

  /// Choices offered for "remind me N minutes before class".
  static const classMinuteChoices = [5, 10, 15, 30];

  static Future<bool> enabled() async => (await SharedPreferences.getInstance()).getBool(enabledKey) ?? false;

  static Future<int> classMinutes() async => (await SharedPreferences.getInstance()).getInt(classMinutesKey) ?? 15;

  static Future<bool> exams() async => (await SharedPreferences.getInstance()).getBool(examKey) ?? true;

  /// Turns reminders on or off. Turning on asks for the notification permission first and
  /// stays off if it is refused. Returns whether reminders are on afterwards.
  static Future<bool> setEnabled(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    if (on) {
      final allowed = await _invoke<bool>('requestNotificationPermission') ?? false;
      if (!allowed) {
        await prefs.setBool(enabledKey, false);
        return false;
      }
    }
    await prefs.setBool(enabledKey, on);
    await _invoke<void>('rescheduleReminders');
    return on;
  }

  static Future<void> setClassMinutes(int minutes) async {
    await (await SharedPreferences.getInstance()).setInt(classMinutesKey, minutes);
    await _invoke<void>('rescheduleReminders');
  }

  static Future<void> setExams(bool on) async {
    await (await SharedPreferences.getInstance()).setBool(examKey, on);
    await _invoke<void>('rescheduleReminders');
  }

  static Future<bool> notificationsAllowed() async => await _invoke<bool>('notificationsAllowed') ?? false;

  /// Shows a sample notification so the user can see what to expect.
  static Future<bool> sendTest() async => await _invoke<bool>('testReminder') ?? false;

  static Future<T?> _invoke<T>(String method) async {
    try {
      return await _channel.invokeMethod<T>(method);
    } on MissingPluginException {
      return null; // not running on Android
    } on PlatformException {
      return null;
    }
  }
}
