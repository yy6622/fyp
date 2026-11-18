
String formatTimeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

String handleForName(String name) {
  final cleaned = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return '@${cleaned.isEmpty ? 'voyauser' : cleaned}';
}

int colorValueForName(String name) {
  const palette = [0xFFE8A57C, 0xFF8CB7E8, 0xFFB39DDB, 0xFF80CBC4, 0xFFEF9A9A, 0xFFA5D6A7, 0xFFFFCC80];
  if (name.isEmpty) return palette[0];
  final idx = name.codeUnitAt(0) % palette.length;
  return palette[idx];
}

String compactCount(int n) {
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}

const List<String> _kFullMonths = [
  '',
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String formatLongDate(DateTime d) => '${d.day} ${_kFullMonths[d.month]} ${d.year}';

int? _monthIndexOf(String name) {
  final lower = name.trim().toLowerCase();
  for (var i = 1; i < _kFullMonths.length; i++) {
    if (_kFullMonths[i].toLowerCase() == lower) return i;
  }
  return null;
}

/// Reverses [formatLongDate] ("20 November 2026" -> DateTime). Returns null
/// if the text isn't in that exact "d MMMM yyyy" shape.
DateTime? parseLongDate(String text) {
  final m = RegExp(r"^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})$").firstMatch(text.trim());
  if (m == null) return null;
  final day = int.tryParse(m.group(1)!);
  final month = _monthIndexOf(m.group(2)!);
  final year = int.tryParse(m.group(3)!);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

/// Parses a 24h "HH:mm" clock string, e.g. from an [ActivityItem.time] or a
/// manually-typed flight time. Returns null if it isn't that exact shape.
({int hour, int minute})? parseClockTime(String text) {
  final m = RegExp(r"^([0-2]?\d):([0-5]\d)$").firstMatch(text.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final mi = int.parse(m.group(2)!);
  if (h > 23) return null;
  return (hour: h, minute: mi);
}

/// Reverses the "20 November 2026, 14:30" shape used for a manually-typed
/// flight's combined date+time text (date and 24h time joined by ", ").
DateTime? parseLongDateTime(String text) {
  final parts = text.split(",");
  if (parts.length < 2) return parseLongDate(text.trim());
  final date = parseLongDate(parts.first.trim());
  if (date == null) return null;
  final time = parseClockTime(parts.sublist(1).join(",").trim());
  if (time == null) return date;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
