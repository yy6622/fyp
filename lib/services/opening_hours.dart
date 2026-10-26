// ---------------------------------------------------------------------
// A pragmatic reader for OSM's `opening_hours` tag syntax — used by the
// AI-Based Attraction Recommendation Algorithm (FYP documentation) for
// its "operating hours" mandatory constraint and its T(a) schedule-
// compatibility score (see recommendation_service.dart).
//
// OSM's actual spec (https://wiki.openstreetmap.org/wiki/Key:opening_hours)
// is large — this covers the common real-world shapes the live Overpass
// scrape in CatalogRepository actually returns: "24/7", one or more
// "<days> <time ranges>" / "<days> off" rules separated by ';' (later
// rules override earlier ones for the same day, same as the real OSM
// evaluation order), comma-separated day lists/ranges within a rule, and
// comma-separated time ranges within a day (a lunch-break split).
// Anything referencing something this parser doesn't model (a named
// holiday, a date/month range, an unrecognized keyword) returns null
// ("unknown") rather than a guess — every caller treats null as "don't
// know, don't exclude", the same fail-open stance this codebase already
// takes everywhere else OSM data is simply missing or malformed.
// ---------------------------------------------------------------------

const _kWeekdayOrder = ['mo', 'tu', 'we', 'th', 'fr', 'sa', 'su'];

/// Whether a place tagged with [raw] (its OSM `opening_hours` value, or
/// this app's own human-readable fallback like "Daily, 9:00 AM - 6:00 PM")
/// is open at [now] (defaults to [DateTime.now()]).
///
/// Returns `true`/`false` when a rule for today's weekday was found and
/// evaluated, or `null` when [raw] is empty or doesn't match a shape
/// this parser understands.
bool? isOpenNow(String raw, {DateTime? now}) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final when = now ?? DateTime.now();

  if (text.toLowerCase() == '24/7') return true;

  final normalized = _normalizeHumanReadable(text);
  final today = _todayAbbrev(when);

  // null = no rule has said anything about today yet; once a rule whose
  // days include today is evaluated, this is overwritten — matching
  // OSM's "later rules override earlier ones for the same day" order.
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
      // A keyword/shape this parser doesn't model (a public holiday
      // condition, a date or month range, ...) — too uncertain to keep
      // evaluating the remaining rules confidently.
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

/// "mo", "mo-fr", "mo,we,fr", "mo-we,fr" -> the set of day abbreviations
/// it covers. Null when any token isn't a recognized weekday abbreviation
/// (an exception like a named holiday, which this parser doesn't handle).
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

/// "09:00-18:00" or "09:00-12:00,13:00-18:00" -> whether [when]'s
/// time-of-day falls in any of those ranges. Null on anything that
/// doesn't parse as HH:MM-HH:MM pairs.
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
      // Crosses midnight (e.g. a bar open "18:00-02:00").
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

/// "Daily, 9:00 AM - 6:00 PM" / "Mon-Fri, 9:00 AM - 6:00 PM" -> OSM-style
/// "mo-su 09:00-18:00" / "mo-fr 09:00-18:00", so the one rule parser
/// above can read either this app's own seeded fallback string or a real
/// OSM `opening_hours` tag. Returns [text] unchanged if it doesn't match
/// this specific "<days>, <h>:<mm> AM/PM - <h>:<mm> AM/PM" shape (it's
/// then handled, or rejected as unparseable, as plain OSM syntax).
String _normalizeHumanReadable(String text) {
  // Comma is deliberately excluded from the day-word character class —
  // if it were allowed there, a greedy match would swallow "Daily,"'s
  // own trailing comma into group 1 (leaving "daily," instead of
  // "daily", which then fails the `== 'daily'` check below and the
  // whole string falls through unnormalized).
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
