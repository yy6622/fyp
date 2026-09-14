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
  final int voted;
  final int total;
  final bool votedByMe;
  const ActivityItem({
    this.id = '',
    required this.time,
    required this.icon,
    required this.label,
    required this.voted,
    required this.total,
    this.votedByMe = false,
  });
}
