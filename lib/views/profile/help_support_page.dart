import 'package:flutter/material.dart';

import '../../theme.dart';
import 'sub_page_scaffold.dart';

// ---------------------------------------------------------------------
// Help and Support
// ---------------------------------------------------------------------
class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  static const _faqs = [
    ('How do I create a group trip?', 'Go to the Plan tab and tap the + button to start a new trip and invite friends.'),
    ('How do I cancel a booking?', 'Open the booking from Profile > History and follow the cancellation steps shown there.'),
    ('Is my payment information secure?', 'Yes — all payments are processed through encrypted, PCI-compliant channels.'),
  ];

  @override
  Widget build(BuildContext context) {
    return SubPageScaffold(
      title: 'Help and Support',
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Icon(Icons.support_agent, color: AppColors.primary, size: 28),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text('Need help fast? Our support team usually replies within a few hours.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.navy)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Frequently Asked Questions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 8),
          ..._faqs.map((f) => ExpansionTile(
                title: Text(f.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
                childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
                children: [
                  Text(f.$2, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
                ],
              )),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Support request sent — we\'ll get back to you by email.')),
              ),
              icon: const Icon(Icons.email_outlined, color: AppColors.primary),
              label: const Text('Contact Support', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
