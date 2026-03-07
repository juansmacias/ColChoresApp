import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_chores_app/core/sync/conflict_resolver_impl.dart';
import 'package:family_chores_app/core/sync/models/conflict_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConflictResolverImpl', () {
    late ConflictResolverImpl resolver;
    late FakeFirebaseFirestore fakeFirestore;

    final t1 = DateTime(2024, 1, 1, 10, 0, 0);
    final t2 = DateTime(2024, 1, 1, 11, 0, 0); // t2 > t1

    final localState = {
      'title': 'Local version',
      'updatedAt': t1.toIso8601String(),
    };
    final remoteState = {
      'title': 'Remote version',
      'updatedAt': t2.toIso8601String(),
    };

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      resolver = ConflictResolverImpl(fakeFirestore);
    });

    group('resolve', () {
      // SE-FT-010
      test('should choose remote when remote timestamp is newer', () {
        final result = resolver.resolve(
          localState: localState,
          remoteState: remoteState,
          localUpdatedAt: t1,
          remoteUpdatedAt: t2,
          localIsDelete: false,
          remoteIsDelete: false,
        );

        expect(result.winner, ConflictWinner.remote);
        expect(result.winnerState, remoteState);
        expect(result.loserState, localState);
      });

      // SE-FT-011
      test('should choose local when local timestamp is newer', () {
        final result = resolver.resolve(
          localState: localState,
          remoteState: remoteState,
          localUpdatedAt: t2,
          remoteUpdatedAt: t1,
          localIsDelete: false,
          remoteIsDelete: false,
        );

        expect(result.winner, ConflictWinner.local);
        expect(result.winnerState, localState);
        expect(result.loserState, remoteState);
      });

      // SE-FT-012
      test('should choose remote on tie — server is authoritative', () {
        final result = resolver.resolve(
          localState: localState,
          remoteState: remoteState,
          localUpdatedAt: t1,
          remoteUpdatedAt: t1,
          localIsDelete: false,
          remoteIsDelete: false,
        );

        expect(result.winner, ConflictWinner.remote);
        expect(result.reason, contains('server is authoritative'));
      });

      // SE-FT-013
      test('should choose local delete over remote edit', () {
        final result = resolver.resolve(
          localState: localState,
          remoteState: remoteState,
          localUpdatedAt: t1,
          remoteUpdatedAt: t2,
          localIsDelete: true,
          remoteIsDelete: false,
        );

        expect(result.winner, ConflictWinner.local);
        expect(result.winnerState, isNull);
        expect(result.loserState, remoteState);
        expect(result.reason, contains('Local delete wins'));
      });

      // SE-FT-014
      test('should choose remote delete over local edit', () {
        final result = resolver.resolve(
          localState: localState,
          remoteState: remoteState,
          localUpdatedAt: t2,
          remoteUpdatedAt: t1,
          localIsDelete: false,
          remoteIsDelete: true,
        );

        expect(result.winner, ConflictWinner.remote);
        expect(result.winnerState, isNull);
        expect(result.loserState, localState);
        expect(result.reason, contains('Remote delete wins'));
      });

      // SE-FT-015
      test(
          'should return remote winner with null states when both sides deleted',
          () {
        final result = resolver.resolve(
          localState: localState,
          remoteState: remoteState,
          localUpdatedAt: t1,
          remoteUpdatedAt: t1,
          localIsDelete: true,
          remoteIsDelete: true,
        );

        expect(result.winner, ConflictWinner.remote);
        expect(result.winnerState, isNull);
        expect(result.loserState, isNull);
        expect(result.reason, contains('Both sides deleted'));
      });
    });

    group('createAuditLogEntry', () {
      // SE-FT-016
      test('should write audit entry to Firestore audit_log subcollection',
          () async {
        await resolver.createAuditLogEntry(
          familyId: 'family-1',
          entityType: 'task',
          entityId: 'task-1',
          beforeState: localState,
          afterState: remoteState,
          performedBy: 'member-1',
          deviceId: 'device-1',
        );

        final snap = await fakeFirestore
            .collection('families')
            .doc('family-1')
            .collection('tasks')
            .doc('task-1')
            .collection('audit_log')
            .get();

        expect(snap.docs, hasLength(1));
        final data = snap.docs.first.data();
        expect(data['action'], 'conflict_resolved_lww');
        expect(data['before'], localState);
        expect(data['after'], remoteState);
        expect(data['performedBy'], 'member-1');
        expect(data['deviceId'], 'device-1');
        expect(data['syncConflict'], true);
      });
    });
  });
}
