import 'package:flutter/material.dart';

import '../../controllers/profile_controller.dart';
import 'sub_page_scaffold.dart';

// ---------------------------------------------------------------------
// Travel Preferences — for one specific plan, picked beforehand on
// SelectPlanPage. This page itself no longer has a plan switcher.
// ---------------------------------------------------------------------
class TravelPreferencesPage extends StatelessWidget {
  final String plan;
  const TravelPreferencesPage({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    final preferences = travelPreferencesByPlan[plan] ?? const {};
    return SubPageScaffold(
      title: '$plan · Preferences',
      body: ListView(
        children: [
          for (final entry in preferences.entries) profileNavRow(entry.key, entry.value),
        ],
      ),
    );
  }
}
