const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Short, friendly timestamp: "Just now", "5 min ago", "Yesterday", "Tue",
/// "12 Mar", "12 Mar 2024".
String relativeTime(DateTime time, {DateTime? now}) {
  now ??= DateTime.now();
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';

  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  final days = today.difference(day).inDays;
  if (days == 0) return '${diff.inHours} h ago';
  if (days == 1) return 'Yesterday';
  if (days < 7) return _weekdays[time.weekday - 1];
  final date = '${time.day} ${_months[time.month - 1]}';
  return time.year == now.year ? date : '$date ${time.year}';
}

/// "Good morning" / "Good afternoon" / "Good evening".
String greeting({DateTime? now}) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour < 5) return 'Hello, night owl';
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}
