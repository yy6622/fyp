import 'package:flutter/material.dart';

import '../../models/group_models.dart';
import '../../repositories/friends_repository.dart';
import '../../repositories/trip_repository.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../explore/saved_items_page.dart';
import '../shared/nice_dialog.dart';
import 'emergency_page.dart';
import 'export_itinerary_page.dart';
import 'group_setting_page.dart';
import 'invite_qr_page.dart';
import 'member_location_page.dart';

// ---------------------------------------------------------------------
// Group Info
// ---------------------------------------------------------------------
class GroupInfoPage extends StatelessWidget {
  final String tripId;
  const GroupInfoPage({super.key, required this.tripId});

  String get _uid => AuthService.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Trip?>(
      stream: TripRepository.instance.watchTrip(tripId, _uid),
      builder: (context, snapshot) {
        final trip = snapshot.data;
        if (trip == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
        }
        final members = trip.memberNames.entries.toList();
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Stack(
                  // The banner reserves only 168px of scroll space (190 - the
                  // 22px the card below overlaps it by), but still *paints*
                  // the full 190px image via OverflowBox — clipBehavior.none
                  // lets that extra 22px paint past the Stack's own box
                  // without being clipped. This achieves the "card floats up
                  // over the banner" look without any negative padding/
                  // margin, both of which assert non-negative in Flutter
                  // (a `Padding.only(top: -22)` here used to crash with
                  // "padding.isNonNegative is not true").
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      height: 168,
                      width: double.infinity,
                      child: OverflowBox(
                        maxHeight: 190,
                        alignment: Alignment.topCenter,
                        child: trip.coverImage.isEmpty
                            ? AppImage('assets/images/adventure_bg.jpg', height: 190, width: double.infinity, fit: BoxFit.cover)
                            : Image.network(
                                trip.coverImage,
                                height: 190,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    AppImage('assets/images/adventure_bg.jpg', height: 190, width: double.infinity, fit: BoxFit.cover),
                              ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16),
                  child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      const SizedBox(height: 4),
                      Text(trip.dateRangeLabel, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
                      Text('${members.length} member${members.length == 1 ? '' : 's'}',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            ...List.generate(
                              members.length,
                              (i) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => _onMemberTap(context, trip, members[i].key, members[i].value),
                                  child: Tooltip(
                                    message: members[i].value,
                                    child: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.primaries[i % Colors.primaries.length],
                                      child: Text(
                                        members[i].value.isEmpty ? '?' : members[i].value[0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _invite(context, trip),
                              child: const CircleAvatar(
                                  radius: 18, backgroundColor: AppColors.chipGrey, child: Icon(Icons.add, color: AppColors.navy)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('About', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      const SizedBox(height: 6),
                      Text(
                        trip.about.isEmpty ? 'No description yet.' : trip.about,
                        style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                      ),
                    ],
                  ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _menuGroup([
                        GroupMenuEntry(Icons.warning_amber_outlined, 'Emergency',
                            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EmergencyPage(tripId: trip.id)))),
                        GroupMenuEntry(
                          Icons.volunteer_activism_outlined,
                          'Saved List',
                          () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => SavedItemsPage(tripId: trip.id, tripName: trip.name))),
                        ),
                        GroupMenuEntry(
                          Icons.location_on_outlined,
                          'Member Location',
                          () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => MemberLocationPage(tripId: trip.id))),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      _menuGroup([
                        GroupMenuEntry(
                          Icons.qr_code_2_outlined,
                          'Invite via QR / Code',
                          () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => InviteQrPage(tripId: trip.id, tripName: trip.name))),
                        ),
                        GroupMenuEntry(Icons.settings_outlined, 'Group Setting',
                            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupSettingPage(tripId: tripId)))),
                        GroupMenuEntry(Icons.ios_share_outlined, 'Export Itinerary',
                            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExportItineraryPage()))),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _invite(BuildContext context, Trip trip) async {
    final uid = _uid;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StreamBuilder<List<FriendEntry>>(
        stream: FriendsRepository.instance.watchFriends(uid),
        builder: (context, snapshot) {
          final friends = (snapshot.data ?? const []).where((f) => !trip.memberIds.contains(f.uid)).toList();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Invite a friend', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 8),
                  if (friends.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Every friend of yours is already in this trip (or you have none yet).',
                          style: TextStyle(color: AppColors.textGrey, fontSize: 12.5)),
                    )
                  else
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: friends
                            .map((f) => ListTile(
                                  leading: const CircleAvatar(radius: 16, backgroundColor: Color(0xFFD9D9D9)),
                                  title: Text(f.name, style: const TextStyle(fontSize: 13.5)),
                                  trailing: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                                  onTap: () async {
                                    await TripRepository.instance.addMembers(trip.id, {f.uid: f.name});
                                    if (context.mounted) Navigator.of(context).pop();
                                  },
                                ))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Only the trip owner can remove a member, and never the owner
  /// themselves — a tap from anyone else, or on the owner's own avatar, is
  /// a plain no-op (their name is already shown via the [Tooltip]).
  Future<void> _onMemberTap(BuildContext context, Trip trip, String memberUid, String memberName) async {
    if (trip.ownerId.isEmpty || _uid != trip.ownerId || memberUid == trip.ownerId) return;
    final confirmed = await showNiceConfirmDialog(
      context: context,
      title: 'Remove member',
      message: "Remove $memberName from this trip? They'll lose access to its plan, chat and expenses.",
      confirmLabel: 'Remove',
      icon: Icons.person_remove_outlined,
      destructive: true,
    );
    if (confirmed) {
      await TripRepository.instance.removeMember(trip.id, memberUid);
    }
  }

  Widget _menuGroup(List<GroupMenuEntry> entries) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: entries.map((e) {
          final isLast = e == entries.last;
          return InkWell(
            onTap: e.onTap,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(e.icon, color: AppColors.navy, size: 20),
                      const SizedBox(width: 14),
                      Expanded(child: Text(e.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy))),
                    ],
                  ),
                ),
                if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF0F0F0)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
