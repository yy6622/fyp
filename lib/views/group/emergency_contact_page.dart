import 'package:flutter/material.dart';

import '../../data/emergency_info.dart';
import '../../theme.dart';
import '../shared/contact_launcher.dart';

// ---------------------------------------------------------------------
// Police / Ambulance / Firefighters for [destination] — real published
// local emergency numbers (see emergency_info.dart), not one fixed set
// shown regardless of where the trip actually goes.
// ---------------------------------------------------------------------
class EmergencyContactPage extends StatelessWidget {
  final String destination;
  const EmergencyContactPage({super.key, required this.destination});

  @override
  Widget build(BuildContext context) {
    final numbers = kEmergencyNumbersByCountry[destination.trim().toLowerCase()] ?? kFallbackEmergencyNumbers;
    final isFallback = !kEmergencyNumbersByCountry.containsKey(destination.trim().toLowerCase());
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Emergency', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isFallback)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                destination.isEmpty
                    ? "This trip has no destination set yet, so 112 — the universal GSM emergency number — is shown below."
                    : "We don't have $destination's specific local numbers yet, so 112 — the universal GSM emergency number, which works in most countries — is shown below.",
                style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey, height: 1.4),
              ),
            ),
          _contactRow(context, Icons.local_police_outlined, 'Police', numbers.police),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          _contactRow(context, Icons.local_hospital_outlined, 'Ambulance', numbers.ambulance),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          _contactRow(context, Icons.local_fire_department_outlined, 'Firefighters', numbers.fire),
        ],
      ),
    );
  }

  Widget _contactRow(BuildContext context, IconData icon, String label, String number) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(color: AppColors.chipGrey, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.navy, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
                const SizedBox(height: 2),
                Text(number, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: AppColors.primary),
            onPressed: () => confirmAndLaunch(context, ContactAction.call, number),
          ),
        ],
      ),
    );
  }
}
