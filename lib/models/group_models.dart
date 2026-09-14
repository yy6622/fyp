import 'package:flutter/material.dart';

class GroupMenuEntry {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  GroupMenuEntry(this.icon, this.label, this.onTap);
}
