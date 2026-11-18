import 'package:flutter/material.dart';

import '../../models/insurance_models.dart';
import '../../theme.dart';
import 'insurance_chat_page.dart';
import 'insurance_partner_list_page.dart' show partnerLogo;
import 'insurance_quote_page.dart';

class InsurancePartnerDetailPage extends StatelessWidget {
  final InsurancePartner partner;
  final String? tripId;
  const InsurancePartnerDetailPage({super.key, required this.partner, this.tripId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: VoyaAppBar(
        title: Text(partner.companyName, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFECECEC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    partnerLogo(partner, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(partner.companyName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (partner.registrationNumber.isNotEmpty || partner.phone.isNotEmpty || partner.supportEmail.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFEDEDED)),
                  const SizedBox(height: 14),
                  if (partner.registrationNumber.isNotEmpty)
                    _infoRow(Icons.badge_outlined, 'Registration No.', partner.registrationNumber),
                  if (partner.phone.isNotEmpty) _infoRow(Icons.call_outlined, 'Phone', partner.phone),
                  if (partner.supportEmail.isNotEmpty) _infoRow(Icons.email_outlined, 'Support email', partner.supportEmail),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: const BorderSide(color: AppColors.primary),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => InsuranceChatPage(partnerId: partner.id, providerName: partner.companyName),
              ),
            ),
            icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 18),
            label: const Text('Chat with this insurer', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: partner.activePlanCount == 0
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => InsuranceQuotePage(partner: partner, tripId: tripId)),
                    ),
            child: Text(
              partner.activePlanCount == 0 ? 'No plans available yet' : 'Get a Quote',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textGrey),
          const SizedBox(width: 10),
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5, color: Colors.black87))),
        ],
      ),
    );
  }
}
