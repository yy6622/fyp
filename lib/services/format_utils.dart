
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
