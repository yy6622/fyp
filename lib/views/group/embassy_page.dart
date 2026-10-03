import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/emergency_info.dart';
import '../../theme.dart';
import '../shared/contact_launcher.dart';

// ---------------------------------------------------------------------
// Nearest Malaysian embassy/consulate for [destination]. Only shows real,
// verified contact details (see emergency_info.dart's doc comment on why
// that map is deliberately small) — a destination not in it gets an
// honest "not available yet" state with a link to Wisma Putra's own
// mission directory, never a guessed phone number or a stale example
// shown regardless of the trip.
// ---------------------------------------------------------------------
class EmbassyPage extends StatelessWidget {
  final String destination;
  const EmbassyPage({super.key, required this.destination});

  @override
  Widget build(BuildContext context) {
    final info = kEmbassyInfoByCountry[destination.trim().toLowerCase()];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Embassy', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: info == null ? _notAvailable(context) : _embassyDetail(info),
    );
  }

  Widget _notAvailable(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.account_balance_outlined, size: 48, color: AppColors.textGrey),
        const SizedBox(height: 16),
        Text(
          destination.isEmpty
              ? "This trip has no destination set yet."
              : "We don't have verified Malaysian embassy contact details for $destination yet.",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.navy),
        ),
        const SizedBox(height: 8),
        const Text(
          "Rather than show a number we can't verify, use Wisma Putra's own directory to find the nearest Malaysian mission.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.4),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => _open(context, kMalaysianMissionsDirectoryUrl),
            icon: const Icon(Icons.open_in_new, color: Colors.white, size: 18),
            label: const Text('Find Nearest Malaysian Mission', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _embassyDetail(EmbassyInfo info) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: AppColors.chipGrey, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const Icon(Icons.account_balance, color: AppColors.navy, size: 30),
        ),
        const SizedBox(height: 14),
        Text(info.missionName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 4),
        Text(info.address, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey, height: 1.4)),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _infoCard(Icons.email_outlined, 'Email', info.email, AppColors.primary),
            _infoCard(Icons.call_outlined, 'Office Lines', info.officeLines.join('\n'), Colors.blueAccent),
            if (info.emergencyPhone != null)
              _infoCard(Icons.warning_amber_rounded, 'Emergency (after hours)', info.emergencyPhone!, Colors.redAccent),
          ],
        ),
      ],
    );
  }

  Widget _infoCard(IconData icon, String label, String value, Color color) {
    return Builder(
      builder: (context) => InkWell(
        onTap: () => label == 'Email'
            ? confirmAndLaunch(context, ContactAction.email, value)
            : confirmAndLaunch(context, ContactAction.call, value.split('\n').first),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
              const SizedBox(height: 2),
              Expanded(
                child: Text(value,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.black)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open that")));
    }
  }
}
