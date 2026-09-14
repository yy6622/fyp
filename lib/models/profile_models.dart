import 'package:flutter/material.dart';

class ProfileMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showChevron;
  ProfileMenuItem(this.icon, this.label, this.onTap, {this.showChevron = true});
}
