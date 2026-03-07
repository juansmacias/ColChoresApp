/// Role of a family member within the household.
enum MemberRole {
  /// Has Firebase Auth account, can manage tasks/rewards/settings.
  parent,

  /// Profile managed by parents, no Firebase Auth account.
  child,
}
