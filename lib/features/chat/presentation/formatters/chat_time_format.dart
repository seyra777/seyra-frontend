String formatConversationTime(DateTime value, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final local = value.toLocal();
  final today = DateTime(current.year, current.month, current.day);
  final date = DateTime(local.year, local.month, local.day);
  final difference = today.difference(date).inDays;

  if (difference == 0) {
    return _two(local.hour, local.minute);
  }
  if (difference == 1) {
    return 'Yesterday';
  }
  if (difference < 7) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[local.weekday - 1];
  }
  return '${local.day}/${local.month}/${local.year}';
}

String formatMessageTime(DateTime value) {
  final local = value.toLocal();
  return _two(local.hour, local.minute);
}

String formatDateSeparator(DateTime value, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final local = value.toLocal();
  final today = DateTime(current.year, current.month, current.day);
  final date = DateTime(local.year, local.month, local.day);
  final difference = today.difference(date).inDays;
  if (difference == 0) {
    return 'Today';
  }
  if (difference == 1) {
    return 'Yesterday';
  }
  return '${local.day}/${local.month}/${local.year}';
}

String formatShortDateTime(DateTime value) {
  final local = value.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d ${formatMessageTime(local)}';
}

String describeDevice(String userAgent) {
  final value = userAgent.trim();
  final lower = value.toLowerCase();
  if (lower.contains('android')) {
    return 'Android';
  }
  if (lower.contains('iphone') ||
      lower.contains('ipad') ||
      lower.contains('ios')) {
    return 'iOS';
  }
  if (lower.contains('windows')) {
    return 'Windows';
  }
  if (value.isEmpty) {
    return 'Unknown device';
  }
  if (value.length > 42) {
    return '${value.substring(0, 40)}…';
  }
  return value;
}

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _two(int hour, int minute) {
  final hh = hour.toString().padLeft(2, '0');
  final mm = minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
