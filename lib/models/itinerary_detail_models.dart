import 'package:flutter/material.dart';

/// A day inside a community/public itinerary post (`DetailPagePlan`).
/// Kept separate from [DayPlan] (group_trip) since that one carries
/// group-voting fields these itinerary posts don't have.
class ItineraryDay {
  final int day;
  final List<ItineraryDayItem> items;
  const ItineraryDay({required this.day, required this.items});
}

class ItineraryDayItem {
  final String time;
  final IconData icon;
  final String label;
  const ItineraryDayItem({required this.time, required this.icon, required this.label});
}
