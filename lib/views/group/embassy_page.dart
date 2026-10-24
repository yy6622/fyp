import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/emergency_info.dart';
import '../../repositories/country_emergency_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../shared/contact_launcher.dart';

// ---------------------------------------------------------------------
// The signed-in trip member's OWN embassy/consulate for [destination] —
// the app isn't Malaysia-only, so this looks up the home country from
// the signed-in user's own Account Setting > Country/Region (falling
// back to Malaysia while that's unset, since that's the only data this
// app shipped with originally), reads live from the admin-curated
// country_emergency_info/{destination}/embassies/{homeCountry} Firestore
// collection (falling back to the static, already-verified
// emergency_info.dart maps for Malaysia only — see
// CountryEmergencyRepository). Only ever shows real, verified contact
// details — a (destination, home country) pair with nothing on file gets
// an honest "not available yet" state, for Malaysia with a link to
// Wisma Putra's own mission directory, never a guessed phone number.
// ---------------------------------------------------------------------
class EmbassyPage extends StatefulWidget {
  final String destination;
  const EmbassyPage({super.key, required this.destination});

  @override
  State<EmbassyPage> createState() => _EmbassyPageState();
}

class _EmbassyPageState extends State<EmbassyPage> {
  late final Future<_EmbassyPageData> _future = _load();

  Future<_EmbassyPageData> _load() async {
    final uid = AuthService.instance.currentUser?.uid;
    String homeCountry = 'malaysia';
    if (uid != null) {
      try {
        final profile = await UserRepository.instance.fetchProfile(uid);
        if (profile != null && profile.country.trim().isNotEmpty) {
          homeCountry = profile.country;
        }
      } catch (_) {
        // Fall back to the Malaysia default below rather than leaving
        // the page blank over a profile-read hiccup.
      }
    }
    final embassy = await CountryEmergencyRepository.instance.embassyFor(widget.destination, homeCountry);
    return _EmbassyPageData(homeCountry: homeCountry, embassy: embassy);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Embassy', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: FutureBuilder<_EmbassyPageData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final data = snapshot.data!;
          return data.embassy == null ? _notAvailable(context, data.homeCountry) : _embassyDetail(data.embassy!, data.homeCountry);
        },
      ),
    );
  }

  Widget _notAvailable(BuildContext context, String homeCountry) {
    final isMalaysia = homeCountry.trim().toLowerCase() == 'malaysia';
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.account_balance_outlined, size: 48, color: AppColors.textGrey),
        const SizedBox(height: 16),
        Text(
          widget.destination.isEmpty
              ? "This trip has no destination set yet."
              : "We don't have verified $homeCountry embassy contact details for ${widget.destination} yet.",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.navy),
        ),
        const SizedBox(height: 8),
        Text(
          isMalaysia
              ? "Rather than show a number we can't verify, use Wisma Putra's own directory to find the nearest Malaysian mission."
              : "Rather than show a number we can't verify, check with $homeCountry's own foreign affairs ministry for the nearest mission.",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.4),
        ),
        const SizedBox(height: 20),
        if (isMalaysia)
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

  Widget _embassyDetail(EmbassyRecord info, String homeCountry) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _photoOrIcon(info.embassyPhotoUrl),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(20)),
          child: Text(homeCountry, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.navy)),
        ),
        const SizedBox(height: 10),
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

  /// The embassy's real photo when an admin has uploaded one (see
  /// admin/country-emergency-form.html), with a graceful icon fallback
  /// while loading, on an empty URL, or if the image fails to load.
  Widget _photoOrIcon(String photoUrl) {
    final placeholder = Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(color: AppColors.chipGrey, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: const Icon(Icons.account_balance, color: AppColors.navy, size: 30),
    );
    if (photoUrl.isEmpty) return placeholder;
    return ClipOval(
      child: Image.network(
        photoUrl,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (context, child, progress) => progress == null ? child : placeholder,
      ),
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

class _EmbassyPageData {
  final String homeCountry;
  final EmbassyRecord? embassy;
  const _EmbassyPageData({required this.homeCountry, required this.embassy});
}
