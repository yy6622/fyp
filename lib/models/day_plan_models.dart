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
