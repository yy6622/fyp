import 'package:flutter/material.dart';

import '../../theme.dart';
import '../create_plan/create_plan_wizard.dart';
import 'join_trip_page.dart';
import 'scan_qr_page.dart';

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
          _tile(context, Icons.add_circle_outline, 'Create New Plan', 'Start a new trip with friends',
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreatePlanWizard()))),
          _tile(context, Icons.link, 'Join with invite code', 'Enter invite code to join',
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JoinTripPage()))),
          _tile(context, Icons.qr_code_scanner, 'Scan QR code', 'Scan to join a group',
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanQrPage()))),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: const Color(0xFFD9D9D9), borderRadius: BorderRadius.circular(22)),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.primary, size: 20),
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
