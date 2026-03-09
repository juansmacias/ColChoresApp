/// Identifies which side won a sync conflict.
enum ConflictWinner { local, remote }

/// The outcome of conflict resolution between local and remote entity states.
class ConflictResult {
  const ConflictResult({
    required this.winner,
    required this.winnerState,
    required this.loserState,
    required this.reason,
  });

  final ConflictWinner winner;

  /// State of the winning side. Null when the winner is a delete operation.
  final Map<String, dynamic>? winnerState;

  /// State of the losing side. Null when both sides deleted.
  final Map<String, dynamic>? loserState;

  /// Human-readable explanation of why this side won.
  final String reason;
}
