/// Thrown by [EntitySyncAdapter.pushToRemote] when a write conflict is
/// detected — i.e., the remote document was modified after our local copy.
class SyncConflictException implements Exception {
  const SyncConflictException({
    required this.remoteState,
    required this.remoteUpdatedAt,
    required this.remoteIsDeleted,
  });

  final Map<String, dynamic> remoteState;
  final DateTime remoteUpdatedAt;
  final bool remoteIsDeleted;

  @override
  String toString() =>
      'SyncConflictException: conflict detected at $remoteUpdatedAt';
}
