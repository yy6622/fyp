/// Small formatting helpers shared by the Firestore-backed repositories —
/// kept dependency-free (no Firestore imports) so they're easy to reuse.

/// "2h ago" / "3d ago" style relative time, matching the mock data's look.
String formatTimeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

/// Turns a display name into an "@handle" the way the mock authors had one.
String handleForName(String name) {
  final cleaned = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return '@${cleaned.isEmpty ? 'voyauser' : cleaned}';
}

/// A stable pastel avatar color derived from a name, so the same author
/// always gets the same color without storing one explicitly.
int colorValueForName(String name) {
  const palette = [0xFFE8A57C, 0xFF8CB7E8, 0xFFB39DDB, 0xFF80CBC4, 0xFFEF9A9A, 0xFFA5D6A7, 0xFFFFCC80];
  if (name.isEmpty) return palette[0];
  final idx = name.codeUnitAt(0) % palette.length;
  return palette[idx];
}
