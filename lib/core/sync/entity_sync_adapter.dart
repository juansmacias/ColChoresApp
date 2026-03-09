import '../enums/operation_type.dart';
import 'sync_status.dart';

/// Represents a changed entity document fetched from Firestore.
class RemoteChange {
  const RemoteChange({
    required this.id,
    required this.data,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String id;
  final Map<String, dynamic> data;
  final DateTime updatedAt;
  final bool isDeleted;
}

/// Represents a local Drift entity that participates in sync.
abstract class SyncableEntity {
  String get remoteId;
  SyncStatus get syncStatus;
  DateTime get updatedAt;
  Map<String, dynamic> toMap();
}

/// Type-specific adapter for syncing a particular entity type with Firestore.
///
/// Implemented per entity type (TaskSyncAdapter, MemberSyncAdapter, etc.).
/// The sync engine uses this interface to remain agnostic of entity-specific
/// serialization and Firestore collection paths.
abstract class EntitySyncAdapter {
  /// Entity type string used as the key in the adapter registry.
  /// Examples: "task", "member", "reward", "category".
  String get entityType;

  /// Timestamp of the last successful pull for this entity type.
  /// Used to fetch only changed documents (incremental sync).
  DateTime? get lastSyncTimestamp;

  /// Pushes a single operation to Firestore.
  ///
  /// Throws [SyncConflictException] if a write conflict is detected.
  /// Throws other [Exception]s for transient network failures.
  Future<void> pushToRemote({
    required String entityId,
    required OperationType operationType,
    required String payload,
  });

  /// Fetches changed documents from Firestore since [since].
  /// Pass null to fetch all documents (initial sync).
  Future<List<RemoteChange>> fetchChangesSince({
    required String familyId,
    required DateTime? since,
  });

  /// Finds a local Drift entity by its Firestore document ID.
  Future<SyncableEntity?> findLocalByRemoteId(String remoteId);

  /// Inserts a new entity from Firestore into the local database.
  Future<void> insertLocal(RemoteChange change);

  /// Updates an existing local entity from Firestore state.
  Future<void> updateLocal(RemoteChange change);

  /// Deletes a local entity by its Firestore document ID.
  Future<void> deleteLocal(String remoteId);
}
