import 'package:flutter/material.dart';

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
