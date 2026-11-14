import 'package:flutter_test/flutter_test.dart';
import 'package:vitap_nexus_app/providers/vtop_providers.dart';

void main() {
  group('VtopDataState Unit Tests', () {
    test('Initializes with default idle state', () {
      const state = VtopDataState<Map<String, dynamic>>();
      expect(state.hasData, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.isSyncing, isFalse);
      expect(state.error, isNull);
    });

    test('Pattern matches correctly using when and maybeWhen', () {
      const stateWithData = VtopDataState<String>(
        data: 'Course Data',
      );

      final resultWhen = stateWithData.when(
        data: (d) => 'DATA: $d',
        error: (e, s) => 'ERROR',
        loading: () => 'LOADING',
      );
      expect(resultWhen, 'DATA: Course Data');

      const stateWithError = VtopDataState<String>(
        error: 'Network timeout',
      );

      final resultError = stateWithError.when(
        data: (d) => 'DATA: $d',
        error: (e, s) => 'ERROR: $e',
        loading: () => 'LOADING',
      );
      expect(resultError, 'ERROR: Network timeout');

      final resultMaybeWhen = stateWithData.maybeWhen(
        data: (d) => 'MAYBE_DATA: $d',
        orElse: () => 'OR_ELSE',
      );
      expect(resultMaybeWhen, 'MAYBE_DATA: Course Data');
    });

    test('State reflects loading and syncing states correctly', () {
      const loadingState = VtopDataState<String>(
        isLoading: true,
      );
      expect(loadingState.isLoading, isTrue);
      expect(loadingState.hasData, isFalse);

      final now = DateTime.now();
      final syncedState = VtopDataState<String>(
        data: 'Synced Item',
        isSyncing: false,
        lastSynced: now,
      );
      expect(syncedState.hasData, isTrue);
      expect(syncedState.lastSynced, now);
    });
  });
}
