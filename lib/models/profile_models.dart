import 'package:flutter/material.dart';

class ProfileMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showChevron;
  // Small red dot next to the label -- used by Insurance Messages to show
  // there's an unread reply from a partner without opening it first.
  final bool badge;
  ProfileMenuItem(this.icon, this.label, this.onTap, {this.showChevron = true, this.badge = false});
}
