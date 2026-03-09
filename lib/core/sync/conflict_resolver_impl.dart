import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import 'conflict_resolver.dart';
import 'models/conflict_result.dart';

@LazySingleton(as: ConflictResolver)
class ConflictResolverImpl implements ConflictResolver {
  ConflictResolverImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  ConflictResult resolve({
    required Map<String, dynamic> localState,
    required Map<String, dynamic> remoteState,
    required DateTime localUpdatedAt,
    required DateTime remoteUpdatedAt,
    required bool localIsDelete,
    required bool remoteIsDelete,
  }) {
    // Rule 1: Delete always wins over edit.
    if (localIsDelete && !remoteIsDelete) {
      return ConflictResult(
        winner: ConflictWinner.local,
        winnerState: null,
        loserState: remoteState,
        reason: 'Local delete wins over remote edit',
      );
    }

    if (remoteIsDelete && !localIsDelete) {
      return ConflictResult(
        winner: ConflictWinner.remote,
        winnerState: null,
        loserState: localState,
        reason: 'Remote delete wins over local edit',
      );
    }

    // Both sides deleted — no meaningful conflict.
    if (localIsDelete && remoteIsDelete) {
      return const ConflictResult(
        winner: ConflictWinner.remote,
        winnerState: null,
        loserState: null,
        reason: 'Both sides deleted, no conflict',
      );
    }

    // Rule 2: Later timestamp wins.
    if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
      return ConflictResult(
        winner: ConflictWinner.remote,
        winnerState: remoteState,
        loserState: localState,
        reason: 'Remote timestamp is newer',
      );
    }

    if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
      return ConflictResult(
        winner: ConflictWinner.local,
        winnerState: localState,
        loserState: remoteState,
        reason: 'Local timestamp is newer',
      );
    }

    // Rule 3: Tie → remote (server) wins.
    return ConflictResult(
      winner: ConflictWinner.remote,
      winnerState: remoteState,
      loserState: localState,
      reason: 'Timestamps equal, server is authoritative',
    );
  }

  @override
  Future<void> createAuditLogEntry({
    required String familyId,
    required String entityType,
    required String entityId,
    required Map<String, dynamic>? beforeState,
    required Map<String, dynamic>? afterState,
    required String performedBy,
    required String deviceId,
  }) async {
    final collection = _firestore
        .collection('families')
        .doc(familyId)
        .collection('${entityType}s')
        .doc(entityId)
        .collection('audit_log');

    await collection.add({
      'action': 'conflict_resolved_lww',
      'before': beforeState,
      'after': afterState,
      'performedBy': performedBy,
      'deviceId': deviceId,
      'timestamp': FieldValue.serverTimestamp(),
      'syncConflict': true,
    });
  }
}
