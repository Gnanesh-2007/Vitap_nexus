import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitap_nexus_app/services/widget_sync_service.dart';

/// The exam list VTOP gives the app is a list of GROUPS (CAT 1, CAT 2, FAT),
/// each holding its own `subjects`. The home-screen widget used to read it as a
/// flat list, found no dates, and always said there were no exams.
String _date(int daysFromToday) =>
    DateFormat('dd-MMM-yyyy', 'en_US').format(DateTime.now().add(Duration(days: daysFromToday)));

Map<String, dynamic> _subject(String code, String name, String date, {String time = '09:30 - 11:00', String session = 'FN'}) => {
      'serial_number': '1',
      'slot': 'A1',
      'course_name': name,
      'course_code': code,
      'course_type': 'ETH',
      'course_id': 'x',
      'exam_date': date,
      'exam_session': session,
      'reporting_time': '09:00',
      'exam_time': time,
      'venue': 'AB1-301',
      'seat_location': '',
      'seat_number': '12',
    };

Future<List<Map<String, dynamic>>> _syncedExams(List<dynamic> exams) async {
  SharedPreferences.setMockInitialValues({});
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('com.vitap.vitap_nexus_app/widgets'),
    (call) async => null,
  );
  await WidgetSyncService.clear();
  await WidgetSyncService.update(exams: exams);
  final prefs = await SharedPreferences.getInstance();
  final json = jsonDecode(prefs.getString('nexus_widget_snapshot')!) as Map;
  return [for (final e in json['exams'] as List) Map<String, dynamic>.from(e as Map)];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exams inside VTOP groups reach the widget snapshot', () async {
    final out = await _syncedExams([
      {
        'exam_type': 'CAT2',
        'subjects': [_subject('CSE2001', 'Data Structures and Algorithms', _date(9))],
      },
      {
        'exam_type': 'FAT',
        'subjects': [
          _subject('CSE2005', 'Operating Systems', _date(20), session: 'AN', time: '14:00 - 17:00'),
          _subject('MAT2001', 'Statistics', _date(25)),
        ],
      },
    ]);
    expect(out.map((e) => e['c']), ['CSE2001', 'CSE2005', 'MAT2001'], reason: 'flattened and sorted by date');
    expect(out.first['n'], 'Data Structures and Algorithms');
    expect(out.first['x'], 'CAT2', reason: 'keeps which exam it belongs to');
    expect(out[1]['s'], 'AN');
    expect(out[1]['t'], '14:00 - 17:00');
  });

  test('a plain flat list (older cached data) still works', () async {
    final out = await _syncedExams([_subject('CSE2001', 'DSA', _date(3))]);
    expect(out, hasLength(1));
    expect(out.single['c'], 'CSE2001');
  });

  test('past exams are dropped, today is kept', () async {
    final out = await _syncedExams([
      {
        'exam_type': 'CAT1',
        'subjects': [
          _subject('OLD1001', 'Already done', _date(-3)),
          _subject('NOW1001', 'Today', _date(0)),
          _subject('NEW1001', 'Later', _date(4)),
        ],
      },
    ]);
    expect(out.map((e) => e['c']), ['NOW1001', 'NEW1001']);
  });

  test('upper-case months and other date shapes are understood', () async {
    final d = DateTime.now().add(const Duration(days: 6));
    final out = await _syncedExams([
      {
        'exam_type': 'FAT',
        'subjects': [
          _subject('A1', 'Upper', DateFormat('dd-MMM-yyyy', 'en_US').format(d).toUpperCase()),
          _subject('B1', 'Slashes', DateFormat('dd/MM/yyyy').format(d)),
          _subject('C1', 'Iso', DateFormat('yyyy-MM-dd').format(d)),
        ],
      },
    ]);
    expect(out.map((e) => e['c']).toSet(), {'A1', 'B1', 'C1'});
  });

  test('junk entries are ignored instead of crashing', () async {
    final out = await _syncedExams([
      'nonsense',
      null,
      {'exam_type': 'FAT', 'subjects': 'not a list'},
      {'exam_type': 'FAT', 'subjects': [_subject('GOOD1', 'Good', _date(2)), 7, _subject('BAD1', 'No date', '')]},
    ]);
    expect(out.map((e) => e['c']), ['GOOD1']);
  });

  test('the same exam listed twice shows once', () async {
    final s = _subject('CSE2001', 'DSA', _date(5));
    final out = await _syncedExams([
      {'exam_type': 'FAT', 'subjects': [s, s]},
    ]);
    expect(out, hasLength(1));
  });
}
