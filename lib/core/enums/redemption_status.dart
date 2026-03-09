/// Status of a reward redemption.
enum RedemptionStatus {
  /// Redemption created, not yet confirmed by server.
  /// Per resolved decision: redemptions are auto-approved when points
  /// are sufficient. This status exists for the sync window.
  pending,

  /// Redemption approved (auto or by parent).
  approved,

  /// Redemption rejected (e.g., points insufficient after sync).
  rejected,
}
