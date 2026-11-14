// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitap_nexus_app/services/storage_service.dart';

double _percentile(List<double> sorted, double p) {
  if (sorted.isEmpty) return 0.0;
  final index = ((sorted.length - 1) * p).round();
  return sorted[index];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Empirical Performance & Metrics Benchmark Suite', () {
    test('1. Memory & Disk Cache Latencies (P50, P95, P99)', () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.initCache('22BCE10001');

      final sampleData = List.generate(20, (i) => {
        'course_code': 'CSE100$i',
        'course_title': 'Engineering Subject $i',
        'attended': 25,
        'total': 30,
        'percentage': 83.3,
      });

      await StorageService.setCache('attendance', sampleData, username: '22BCE10001', semesterId: 'AP2024252');

      // 1. Memory Cache (5,000 iterations)
      final List<double> memLatenciesUs = [];
      for (int i = 0; i < 5000; i++) {
        final sw = Stopwatch()..start();
        final _ = StorageService.getMemoryCache('attendance', username: '22BCE10001', semesterId: 'AP2024252');
        sw.stop();
        memLatenciesUs.add(sw.elapsedMicroseconds.toDouble());
      }
      memLatenciesUs.sort();

      // 2. Disk Cache (1,000 iterations)
      final List<double> diskLatenciesUs = [];
      for (int i = 0; i < 1000; i++) {
        final sw = Stopwatch()..start();
        final _ = await StorageService.getCache('attendance', username: '22BCE10001', semesterId: 'AP2024252');
        sw.stop();
        diskLatenciesUs.add(sw.elapsedMicroseconds.toDouble());
      }
      diskLatenciesUs.sort();

      final memP50 = _percentile(memLatenciesUs, 0.50);
      final memP95 = _percentile(memLatenciesUs, 0.95);
      final memP99 = _percentile(memLatenciesUs, 0.99);

      final diskP50 = _percentile(diskLatenciesUs, 0.50);
      final diskP95 = _percentile(diskLatenciesUs, 0.95);
      final diskP99 = _percentile(diskLatenciesUs, 0.99);

      print('\n=============================================');
      print('MEMORY CACHE LATENCY:');
      print('P50: ${(memP50 / 1000.0).toStringAsFixed(3)} ms ($memP50 µs)');
      print('P95: ${(memP95 / 1000.0).toStringAsFixed(3)} ms ($memP95 µs)');
      print('P99: ${(memP99 / 1000.0).toStringAsFixed(3)} ms ($memP99 µs)');

      print('\nDISK CACHE LATENCY:');
      print('P50: ${(diskP50 / 1000.0).toStringAsFixed(3)} ms ($diskP50 µs)');
      print('P95: ${(diskP95 / 1000.0).toStringAsFixed(3)} ms ($diskP95 µs)');
      print('P99: ${(diskP99 / 1000.0).toStringAsFixed(3)} ms ($diskP99 µs)');
      print('=============================================\n');
    });

    test('2. Cold Start Latency Distribution (P50, P95, P99)', () async {
      final List<double> coldStartMs = [];

      for (int i = 0; i < 100; i++) {
        SharedPreferences.setMockInitialValues({
          'vtop_username': '22BCE10001',
          'vtop_password': 'secure_password_test',
          'cache_22BCE10001_attendance': '{"schemaVersion":2,"user":"22BCE10001","data":[{"course_code":"CSE1001"}]}',
          'cache_22BCE10001_timetable': '{"schemaVersion":2,"user":"22BCE10001","data":{"Monday":[]}}',
          'cache_22BCE10001_marks': '{"schemaVersion":2,"user":"22BCE10001","data":[]}',
        });

        final sw = Stopwatch()..start();
        await StorageService.initCache();
        final _ = StorageService.getMemoryCache('attendance', username: '22BCE10001');
        sw.stop();

        coldStartMs.add(sw.elapsedMicroseconds / 1000.0);
      }
      coldStartMs.sort();

      print('\n=============================================');
      print('COLD START:');
      print('P50: ${_percentile(coldStartMs, 0.50).toStringAsFixed(2)} ms');
      print('P95: ${_percentile(coldStartMs, 0.95).toStringAsFixed(2)} ms');
      print('P99: ${_percentile(coldStartMs, 0.99).toStringAsFixed(2)} ms');
      print('=============================================\n');
    });

    testWidgets('3. Frame Rendering Times & Memory Allocations', (tester) async {
      final initialRss = ProcessInfo.currentRss;
      final List<double> frameTimesMs = [];
      int jankyFrames = 0;

      // Render 50 view rebuild cycles
      for (int i = 0; i < 50; i++) {
        final sw = Stopwatch()..start();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ListView.builder(
                  itemCount: 30,
                  itemBuilder: (ctx, idx) => Card(
                    child: ListTile(
                      title: Text('Course CSE100$idx'),
                      subtitle: Text('Attended: ${20 + idx}/30 (85%)'),
                      trailing: const Icon(Icons.check_circle),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        sw.stop();

        final frameMs = sw.elapsedMicroseconds / 1000.0;
        frameTimesMs.add(frameMs);
        if (frameMs > 16.67) jankyFrames++;
      }
      final rss50 = ProcessInfo.currentRss;

      // Render 50 more (Total 100)
      for (int i = 50; i < 100; i++) {
        final sw = Stopwatch()..start();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ListView.builder(
                  itemCount: 30,
                  itemBuilder: (ctx, idx) => Card(
                    child: ListTile(
                      title: Text('Course CSE100$idx'),
                      subtitle: Text('Marks: 92/100 (Grade S)'),
                      trailing: const Icon(Icons.star),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        sw.stop();

        final frameMs = sw.elapsedMicroseconds / 1000.0;
        frameTimesMs.add(frameMs);
        if (frameMs > 16.67) jankyFrames++;
      }
      final rss100 = ProcessInfo.currentRss;

      frameTimesMs.sort();
      final avgFrameTime = frameTimesMs.reduce((a, b) => a + b) / frameTimesMs.length;
      final worstFrameTime = frameTimesMs.last;

      print('\n=============================================');
      print('FRAME RENDERING:');
      print('Janky frames: $jankyFrames');
      print('Average frame time: ${avgFrameTime.toStringAsFixed(2)} ms');
      print('Worst frame: ${worstFrameTime.toStringAsFixed(2)} ms');

      print('\nMEMORY CONSUMPTION:');
      print('Initial RAM: ${(initialRss / (1024 * 1024)).toStringAsFixed(1)} MB');
      print('After 50 navigations: ${(rss50 / (1024 * 1024)).toStringAsFixed(1)} MB');
      print('After 100 navigations: ${(rss100 / (1024 * 1024)).toStringAsFixed(1)} MB');
      print('=============================================\n');
    });
  });
}
