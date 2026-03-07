import 'package:family_chores_app/core/error/failures.dart';
import 'package:family_chores_app/core/presentation/base_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BaseState hierarchy', () {
    test('InitialState is the default empty state', () {
      expect(const InitialState(), equals(const InitialState()));
      expect(const InitialState().isOffline, isFalse);
    });

    test('LoadingState carries previous data in equality', () {
      expect(
        const LoadingState<List<int>>(previousData: [1, 2, 3]),
        equals(const LoadingState<List<int>>(previousData: [1, 2, 3])),
      );
    });

    test('LoadedState carries offline metadata and supports copyWith', () {
      final initial = LoadedState<List<int>>(
        data: const [1, 2],
        lastSyncedAt: DateTime(2026),
      );

      final updated = initial.copyWith(
        isOffline: true,
        lastSyncedAt: DateTime(2026, 1, 2),
      );

      expect(updated.data, [1, 2]);
      expect(updated.isOffline, isTrue);
      expect(updated.lastSyncedAt, DateTime(2026, 1, 2));
    });

    test('ErrorState keeps failure and previous data', () {
      const state = ErrorState(
        failure: NetworkFailure(message: 'Network error occurred'),
        previousData: 'cached-data',
      );

      expect(
        state.failure,
        const NetworkFailure(message: 'Network error occurred'),
      );
      expect(state.previousData, 'cached-data');
    });
  });
}
