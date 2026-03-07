/// Lifecycle status of a task.
enum TaskStatus {
  /// Task is created but not started.
  pending,

  /// Task is actively being worked on.
  inProgress,

  /// Task has been marked as done by the assignee.
  completed,

  /// Task completion has been verified by a parent.
  verified,

  /// Task was skipped (e.g., recurring task not done that day).
  skipped,
}
