import 'package:flutter/material.dart';

class DayPlan {
  final int day;
  final String weekday;
  final String date;
  final List<ActivityItem> items;
  const DayPlan({required this.day, required this.weekday, required this.date, required this.items});
}

class ActivityItem {
  final String id;
  final String time;
  final IconData icon;
  final String label;
  final String location;
  final int voted;
  final int total;
  final bool votedByMe;
  final List<String> forMemberUids;
  const ActivityItem({
    this.id = '',
    required this.time,
    required this.icon,
    required this.label,
    this.location = '',
    required this.voted,
    required this.total,
    this.votedByMe = false,
    this.forMemberUids = const [],
  });
}

List<String> effectiveActivityMembers(ActivityItem item, List<String> allMemberIds) =>
    item.forMemberUids.isEmpty ? allMemberIds : item.forMemberUids;

// Keyword guess at whether an activity happens indoors, used to decide
// whether a bad-weather/traffic nudge is even worth showing for a day (no
// point suggesting a re-optimise for rain when nothing that day is outdoors).
// Returns true (confidently indoor), false (confidently outdoor), or null
// (can't tell) — callers should treat null as "not confidently indoor" so a
// day with unclassifiable activities still gets the nudge as before.
final RegExp _indoorWords = RegExp(
  r'(museum|gallery|mall|shopping (centre|center)|department store|supermarket|'
  r'cinema|movie|theatre|theater|aquarium|planetarium|arcade|bowling|karaoke|'
  r'spa|massage|indoor|casino|ice rink|restaurant|cafe|café|food court|'
  r'博物馆|美术馆|商场|购物中心|百货|电影院|水族馆|按摩|室内|咖啡|餐厅)',
  caseSensitive: false,
);
final RegExp _outdoorWords = RegExp(
  r'(beach|hiking?|trail|park|garden|zoo|safari|mountain|lake|river|'
  r'waterfall|outdoor|night market|street food|market|viewpoint|cruise|boat|'
  r'island|cycling|bike|trekking|climbing|ski|surfing|rooftop|walking tour|'
  r'picnic|sunrise|sunset|海滩|沙滩|爬山|登山|公园|花园|动物园|夜市|海岛|骑车|徒步|日出|日落)',
  caseSensitive: false,
);

bool? isLikelyIndoor(String label) {
  final indoor = _indoorWords.hasMatch(label);
  final outdoor = _outdoorWords.hasMatch(label);
  if (indoor && !outdoor) return true;
  if (outdoor && !indoor) return false;
  return null; // no match, or both matched (ambiguous) — unknown either way
}

/// True only when every activity in [items] is confidently indoor — an empty
/// list is not "all indoor" (nothing to be confident about).
bool allActivitiesLikelyIndoor(List<ActivityItem> items) =>
    items.isNotEmpty && items.every((a) => isLikelyIndoor(a.label) == true);

class ScheduleConflict {
  final int day;
  final String time;
  final List<ActivityItem> activities;
  final List<String> sharedMemberUids;
  const ScheduleConflict({required this.day, required this.time, required this.activities, required this.sharedMemberUids});
}

List<ScheduleConflict> findScheduleConflicts(List<DayPlan> days, List<String> allMemberIds) {
  final conflicts = <ScheduleConflict>[];
  for (final day in days) {
    final byTime = <String, List<ActivityItem>>{};
    for (final item in day.items) {
      if (item.time.isEmpty) continue;
      byTime.putIfAbsent(item.time, () => []).add(item);
    }
    for (final entry in byTime.entries) {
      final items = entry.value;
      if (items.length < 2) continue;
      for (var i = 0; i < items.length; i++) {
        for (var j = i + 1; j < items.length; j++) {
          final a = effectiveActivityMembers(items[i], allMemberIds).toSet();
          final b = effectiveActivityMembers(items[j], allMemberIds).toSet();
          final shared = a.intersection(b);
          if (shared.isNotEmpty) {
            conflicts.add(ScheduleConflict(day: day.day, time: entry.key, activities: [items[i], items[j]], sharedMemberUids: shared.toList()));
          }
        }
      }
    }
  }
  return conflicts;
}
