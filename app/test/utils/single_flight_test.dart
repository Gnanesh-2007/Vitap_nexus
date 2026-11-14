import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitap_nexus_app/utils/single_flight.dart';

void main() {
  group('SingleFlight Concurrency Guard Tests', () {
    test('deduplicates concurrent calls with identical key and returns same future', () async {
      final flight = SingleFlight<String, String>();
      int operationCount = 0;
      final completer = Completer<String>();

      Future<String> sampleOperation() {
        operationCount++;
        return completer.future;
      }

      // Start first operation
      final future1 = flight.run('user1:pass', sampleOperation);
      expect(flight.isRunning, isTrue);

      // Concurrent call with same key
      final future2 = flight.run('user1:pass', sampleOperation);

      // Only 1 underlying operation should have started
      expect(operationCount, equals(1));
      expect(future1, equals(future2));

      // Complete operation
      completer.complete('SUCCESS');

      final result1 = await future1;
      final result2 = await future2;

      expect(result1, equals('SUCCESS'));
      expect(result2, equals('SUCCESS'));
      expect(flight.isRunning, isFalse);
    });

    test('allows distinct operation for different key', () async {
      final flight = SingleFlight<String, String>();
      int operationCount = 0;

      Future<String> opA() async {
        operationCount++;
        return 'RESULT_A';
      }

      Future<String> opB() async {
        operationCount++;
        return 'RESULT_B';
      }

      final resA = await flight.run('userA', opA);
      final resB = await flight.run('userB', opB);

      expect(resA, equals('RESULT_A'));
      expect(resB, equals('RESULT_B'));
      expect(operationCount, equals(2));
    });
  });
}
