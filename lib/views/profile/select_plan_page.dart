import 'package:flutter/material.dart';

import '../../controllers/profile_controller.dart';
import 'sub_page_scaffold.dart';
import 'travel_preferences_page.dart';

// ---------------------------------------------------------------------
// Select Plan — the entry point for Travel Preferences. Pick which plan
// you want to view/edit preferences for, then it opens that plan's own
// TravelPreferencesPage.
// ---------------------------------------------------------------------
class SelectPlanPage extends StatelessWidget {
  const SelectPlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SubPageScaffold(
      title: 'Select Plan',
      body: ListView(
        children: [
          for (final plan in travelPlans)
            profileNavRow(
              plan,
              '',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TravelPreferencesPage(plan: plan)),
              ),
            ),
        ],
      ),
    );
  }
}
