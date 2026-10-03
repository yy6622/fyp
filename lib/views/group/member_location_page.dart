import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import '../../repositories/trip_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import 'group_setting_page.dart';

// ---------------------------------------------------------------------
// Member Location — real, not mock: for a trip whose owner has turned on
// Real-Time Location (Group Setting), this checks each member's own
// Privacy and Security > "Share Location with Group" flag and shows only
// the members who actually have it on, with their last captured
// position. A member with it off is shown as off, never a fake pin.
// ---------------------------------------------------------------------
class MemberLocationPage extends StatefulWidget {
  final String tripId;
  const MemberLocationPage({super.key, required this.tripId});

  @override
  State<MemberLocationPage> createState() => _MemberLocationPageState();
}

class _MemberLocationPageState extends State<MemberLocationPage> {
  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    // Refresh my own position (if I have sharing on) so my entry in this
    // list — and everyone else's view of it — isn't stale from whenever I
    // last toggled the switch. A no-op if I have sharing off.
    _refreshMyLocation();
  }

  Future<void> _refreshMyLocation() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    final me = await UserRepository.instance.fetchProfile(uid);
    if (me == null || !me.shareLocation) return;
    final position = await LocationService.instance.getCurrentPosition();
    if (position != null) {
      await UserRepository.instance.updateLocation(uid, position.latitude, position.longitude);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Member Location', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: StreamBuilder<Trip?>(
        stream: TripRepository.instance.watchTrip(widget.tripId, _uid),
        builder: (context, snapshot) {
          final trip = snapshot.data;
          if (trip == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (!trip.realTimeLocation) {
            return _off(trip);
          }
          final members = trip.memberNames.entries.toList();
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F0F0)),
            itemBuilder: (context, i) =>
                _MemberLocationRow(key: ValueKey(members[i].key), uid: members[i].key, name: members[i].value),
          );
        },
      ),
    );
  }

  Widget _off(Trip trip) {
    final isOwner = trip.ownerId.isNotEmpty && trip.ownerId == _uid;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_off_outlined, size: 48, color: AppColors.textGrey),
          const SizedBox(height: 16),
          Text(
            isOwner
                ? "Real-Time Location is off for this trip. Turn it on in Group Setting to see members who share their location."
                : "Real-Time Location is off for this trip. Ask the trip owner to turn it on in Group Setting.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.4),
          ),
          if (isOwner) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary)),
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupSettingPage(tripId: widget.tripId))),
              child: const Text('Open Group Setting', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

}

/// One member's row — a separate [StatefulWidget] (keyed by [uid] in the
/// parent's [ListView.separated]) rather than a [StreamBuilder] built
/// inline inside `itemBuilder`. [MemberLocationPage]'s own trip stream
/// re-fires on nearly every write anywhere in the trip (chat, votes,
/// expenses — anything that bumps `lastActivityAt`), which would rebuild
/// an inline `StreamBuilder` with a brand-new `Stream` instance each
/// time, cancelling and resubscribing every member's profile listener
/// from scratch and flashing each row back to its default state. Owning
/// the stream in this widget's own [State] (created once, kept alive by
/// the key across the parent's rebuilds) avoids that churn.
class _MemberLocationRow extends StatefulWidget {
  final String uid;
  final String name;
  const _MemberLocationRow({super.key, required this.uid, required this.name});

  @override
  State<_MemberLocationRow> createState() => _MemberLocationRowState();
}

class _MemberLocationRowState extends State<_MemberLocationRow> {
  late final Stream<AppUser?> _stream = UserRepository.instance.watchProfile(widget.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _stream,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final sharing = user?.shareLocation ?? false;
        final hasFix = sharing && user?.lastLat != null && user?.lastLng != null;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: hasFix ? AppColors.primary.withValues(alpha: 0.15) : AppColors.chipGrey,
                    child: Text(widget.name.isEmpty ? '?' : widget.name[0].toUpperCase(),
                        style: TextStyle(color: hasFix ? AppColors.primary : AppColors.textGrey, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
                        const SizedBox(height: 2),
                        Text(
                          !sharing
                              ? 'Location sharing is off'
                              : hasFix
                                  ? 'Updated ${_relativeTime(user!.locationUpdatedAt)}'
                                  : "Sharing is on, but hasn't sent a location yet",
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                        ),
                      ],
                    ),
                  ),
                  if (hasFix)
                    IconButton(
                      icon: const Icon(Icons.open_in_new, color: AppColors.primary),
                      tooltip: 'Open in Maps',
                      onPressed: () => _openInMaps(user!.lastLat!, user.lastLng!),
                    ),
                ],
              ),
              if (hasFix) ...[
                const SizedBox(height: 8),
                _StaticMapPreview(lat: user!.lastLat!, lng: user.lastLng!),
              ],
            ],
          ),
        );
      },
    );
  }

  String _relativeTime(DateTime? t) {
    if (t == null) return 'a moment ago';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open maps")));
    }
  }
}

/// A small, non-interactive in-app map centred on one member's last known
/// position — real OpenStreetMap tiles (no API key, same no-key approach
/// `duffel_api_service.dart` already uses for geocoding), not an external
/// "open in maps" link. Interaction is switched off so it reads as a
/// static snapshot in the list, same as how a shared-location preview
/// looks in a chat app; [MemberLocationRowState._openInMaps] is still
/// there for anyone who wants the full, pannable map.
class _StaticMapPreview extends StatelessWidget {
  final double lat;
  final double lng;
  const _StaticMapPreview({required this.lat, required this.lng});

  @override
  Widget build(BuildContext context) {
    final point = ll.LatLng(lat, lng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 130,
        width: double.infinity,
        child: IgnorePointer(
          // Read-only preview — no pan/zoom/tap, so it behaves like a
          // static map image even though it's real embedded tiles.
          child: FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: 14,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.voya.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.location_on, color: AppColors.primary, size: 36),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
