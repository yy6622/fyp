import 'package:flutter/material.dart';

import '../../theme.dart';
import '../create_plan/create_plan_wizard.dart';

// ---------------------------------------------------------------------
// New Plan chooser (reached from the Plan tab's "+" button)
// ---------------------------------------------------------------------
class NewPlanPage extends StatelessWidget {
  const NewPlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('New Plan', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: Column(
        children: [
          _tile(context, 'Create New Plan', 'Start a new trip with friends',
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreatePlanWizard()))),
          _tile(context, 'Join with invite link', 'Enter invite link to join', () {}),
          _tile(context, 'Scan QR code', 'Scan to join a group', () {}),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: const Color(0xFFFDFDE0), borderRadius: BorderRadius.circular(22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.navy),
          ],
        ),
      ),
    );
  }
}
