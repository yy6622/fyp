import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../repositories/trip_repository.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import 'embassy_page.dart';
import 'emergency_contact_page.dart';

// ---------------------------------------------------------------------
// Emergency — reached from Group Info. Everything here is keyed off the
// trip's own [Trip.destination] (see emergency_info.dart), never a fixed
// country regardless of which trip it was opened from.
// ---------------------------------------------------------------------
class EmergencyPage extends StatelessWidget {
  final String tripId;
  const EmergencyPage({super.key, required this.tripId});

  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Emergency', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: StreamBuilder<Trip?>(
        stream: TripRepository.instance.watchTrip(tripId, _uid),
        builder: (context, snapshot) {
          final trip = snapshot.data;
          if (trip == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _row(
                context,
                icon: Icons.notifications_active_outlined,
                title: 'Emergency Contact',
                subtitle: 'Quickly reach local emergency contacts',
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => EmergencyContactPage(destination: trip.destination))),
              ),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              _row(
                context,
                icon: Icons.account_balance_outlined,
                title: 'Embassy',
                subtitle: 'Find embassy information',
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => EmbassyPage(destination: trip.destination))),
              ),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              _row(
                context,
                icon: Icons.share_location_outlined,
                title: 'Shared Location',
                subtitle: 'Share your current location with trusted friends',
                onTap: () => _shareCurrentLocation(context),
              ),
            ],
          );
        },
      ),
    );
  }

  /// One-tap, one-off share of the device's *current* position — not the
  /// persistent member-list feature (that's Group Info > Member
  /// Location). Captures a fresh position right now and hands a Google
  /// Maps link to the OS share sheet (WhatsApp or anything else the
  /// person picks), the same way sharing a location from a messaging app
  /// normally works. Nothing is written to Firestore by this action.
  Future<void> _shareCurrentLocation(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      // canPop: false also blocks the system back button from dismissing
      // this — without it, the unconditional pop() below (once the await
      // finishes) could end up popping EmergencyPage itself instead of an
      // already-closed dialog.
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
    );
    final position = await LocationService.instance.getCurrentPosition();
    if (!context.mounted) return;
    Navigator.of(context).pop(); // dismiss the loading dialog
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't get your current location. Check location permission and try again.")),
      );
      return;
    }
    final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
    if (!context.mounted) return;
    // sharePositionOrigin anchors the iOS/iPadOS share-sheet popover — iPad
    // requires it (the share can silently fail there without one).
    final origin = Offset.zero & MediaQuery.of(context).size;
    await SharePlus.instance.share(ShareParams(text: 'My current location: $mapsUrl', sharePositionOrigin: origin));
  }

  Widget _row(BuildContext context,
      {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
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
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}
