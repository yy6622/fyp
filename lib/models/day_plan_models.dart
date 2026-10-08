import 'package:flutter/material.dart';

/// A single day inside a group trip's itinerary (used by [GroupTripPage]'s
/// Overview/Day pager).
class DayPlan {
  final int day;
  final String weekday;
  final String date;
  final List<ActivityItem> items;
  const DayPlan({required this.day, required this.weekday, required this.date, required this.items});
}

/// A single scheduled activity inside a [DayPlan], with group-voting info.
class ActivityItem {
  /// Empty for activities that haven't been saved yet.
  final String id;
  final String time;
  final IconData icon;
  final String label;
  // Optional place/address for this activity (e.g. "Narita Airport (NRT)"
  // or a street address) — shown under the title on the day card so the
  // group can see *where* an activity is, not just what it is.
  final String location;
  final int voted;
  final int total;
  final bool votedByMe;
  // Which of the trip's members this activity is actually for — picked in
  // the Add Activity sheet (see MemberSelectSection) when the trip has more
  // than one member, same idea/convention as TripFlight/TripHotelStay's
  // own forMemberUids. Empty means "not set" (a solo trip, or an activity
  // added before this existed) — treated the same as "everyone" wherever
  // this is read (forMembersLabel, findScheduleConflicts).
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

/// Effective members for an activity — an empty [ActivityItem.forMemberUids]
/// means "everyone on the trip", same convention as
/// TripFlight/TripHotelStay's own forMemberUids.
List<String> effectiveActivityMembers(ActivityItem item, List<String> allMemberIds) =>
    item.forMemberUids.isEmpty ? allMemberIds : item.forMemberUids;

/// Two or more activities on the same day, at the exact same time, whose
/// member lists share at least one person — that person can't actually be
/// in both places at once (e.g. one activity is "for everyone" while
/// another, booked for just a couple of members at the same time, pulls
/// them somewhere else). Surfaced by AI Summarise's "Schedule conflicts"
/// section so the group notices a double-booking before it happens, not
/// after. Pure/deterministic — this doesn't need the AI, just the plan's
/// own data, so it's always accurate and instant.
class ScheduleConflict {
  final int day;
  final String time;
  final List<ActivityItem> activities;
  final List<String> sharedMemberUids;
  const ScheduleConflict({required this.day, required this.time, required this.activities, required this.sharedMemberUids});
}

/// Finds every same-day, same-time clash between two or more activities.
/// Only compares activities that have a time set (an activity with no time
/// yet can't clash with anything). When 3+ activities share a time slot,
/// every overlapping pair is reported separately rather than merged, so
/// each conflict row names exactly the two activities and the people
/// caught between them.
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
