import 'models/conflict_result.dart';

/// Resolves conflicts between local and remote entity states using
/// Last-Write-Wins (LWW) with an audit trail.
abstract class ConflictResolver {
  /// Compares local and remote states and determines the winner.
  ///
  /// Conflict rules (in priority order):
  /// 1. Delete always beats edit (regardless of timestamps).
  /// 2. Later [updatedAt] timestamp wins.
  /// 3. Tie → remote wins (server is authoritative).
  ConflictResult resolve({
    required Map<String, dynamic> localState,
    required Map<String, dynamic> remoteState,
    required DateTime localUpdatedAt,
    required DateTime remoteUpdatedAt,
    required bool localIsDelete,
    required bool remoteIsDelete,
  });

  /// Creates an immutable audit log entry in the Firestore audit_log subcollection.
  ///
  /// Firestore path: `families/{familyId}/{entityType}s/{entityId}/audit_log/{logId}`
  Future<void> createAuditLogEntry({
    required String familyId,
    required String entityType,
    required String entityId,
    required Map<String, dynamic>? beforeState,
    required Map<String, dynamic>? afterState,
    required String performedBy,
    required String deviceId,
  });
}
