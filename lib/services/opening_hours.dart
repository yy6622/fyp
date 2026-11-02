
const _kWeekdayOrder = ['mo', 'tu', 'we', 'th', 'fr', 'sa', 'su'];

bool? isOpenNow(String raw, {DateTime? now}) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final when = now ?? DateTime.now();

  if (text.toLowerCase() == '24/7') return true;

  final normalized = _normalizeHumanReadable(text);
  final today = _todayAbbrev(when);

  bool? resultForToday;

  for (final rawRule in normalized.split(';')) {
    final rule = rawRule.trim();
    if (rule.isEmpty) continue;
    final lowerRule = rule.toLowerCase();

    final offMatch = RegExp(r'^([a-z,\-]+)\s+(off|closed)$').firstMatch(lowerRule);
    if (offMatch != null) {
      final days = _expandDays(offMatch.group(1)!);
      if (days == null) return null;
      if (days.contains(today)) resultForToday = false;
      continue;
    }

    final match = RegExp(r'^([a-z,\-]*)\s*([\d:,\-]+)$').firstMatch(lowerRule);
    if (match == null) {
      return null;
    }
    final dayPart = match.group(1)!.trim();
    final timePart = match.group(2)!.trim();

    final days = dayPart.isEmpty ? _kWeekdayOrder.toSet() : _expandDays(dayPart);
    if (days == null) return null;
    if (!days.contains(today)) continue;

    final isOpen = _timeMatches(timePart, when);
    if (isOpen == null) return null;
    resultForToday = isOpen;
  }

  return resultForToday;
}

String _todayAbbrev(DateTime when) => _kWeekdayOrder[when.weekday - 1];

Set<String>? _expandDays(String dayPart) {
  final out = <String>{};
  for (final token in dayPart.split(',')) {
    final t = token.trim();
    if (t.isEmpty) continue;
    if (t.contains('-')) {
      final bounds = t.split('-');
      if (bounds.length != 2) return null;
      final startIdx = _kWeekdayOrder.indexOf(bounds[0].trim());
      final endIdx = _kWeekdayOrder.indexOf(bounds[1].trim());
      if (startIdx == -1 || endIdx == -1) return null;
      var i = startIdx;
      while (true) {
        out.add(_kWeekdayOrder[i]);
        if (i == endIdx) break;
        i = (i + 1) % 7;
      }
    } else {
      if (!_kWeekdayOrder.contains(t)) return null;
      out.add(t);
    }
  }
  return out;
}

bool? _timeMatches(String timePart, DateTime when) {
  final nowMinutes = when.hour * 60 + when.minute;
  var matched = false;
  for (final range in timePart.split(',')) {
    final bounds = range.split('-');
    if (bounds.length != 2) return null;
    final start = _minutesOf(bounds[0]);
    final end = _minutesOf(bounds[1]);
    if (start == null || end == null) return null;
    if (end <= start) {
      if (nowMinutes >= start || nowMinutes < end) matched = true;
    } else {
      if (nowMinutes >= start && nowMinutes < end) matched = true;
    }
  }
  return matched;
}

int? _minutesOf(String hhmm) {
  final parts = hhmm.trim().split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

String _normalizeHumanReadable(String text) {
  final match = RegExp(
    r'^([A-Za-z\- ]+),?\s*(\d{1,2}):(\d{2})\s*(AM|PM)\s*-\s*(\d{1,2}):(\d{2})\s*(AM|PM)$',
    caseSensitive: false,
  ).firstMatch(text.trim());
  if (match == null) return text;
  final dayWord = match.group(1)!.trim().toLowerCase();
  final dayToken = dayWord == 'daily'
      ? 'mo-su'
      : dayWord
          .replaceAll('mon', 'mo')
          .replaceAll('tue', 'tu')
          .replaceAll('wed', 'we')
          .replaceAll('thu', 'th')
          .replaceAll('fri', 'fr')
          .replaceAll('sat', 'sa')
          .replaceAll('sun', 'su');
  final start = _to24h(match.group(2)!, match.group(3)!, match.group(4)!);
  final end = _to24h(match.group(5)!, match.group(6)!, match.group(7)!);
  return '$dayToken $start-$end';
}

String _to24h(String h, String mm, String ampm) {
  var hour = int.parse(h) % 12;
  if (ampm.toUpperCase() == 'PM') hour += 12;
  return '${hour.toString().padLeft(2, '0')}:$mm';
}
