extension DateTimeDisplayExtension on DateTime {
  String toDisplayDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(year, month, day);
    final diff = date.difference(today).inDays;

    return switch (diff) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      _ when diff > 1 => 'In $diff days',
      _ => '${diff.abs()} days ago',
    };
  }
}
