import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/community_models.dart';
import '../../models/insurance_models.dart';
import '../../repositories/community_repository.dart';
import '../../repositories/insurance_chat_repository.dart';
import '../../repositories/insurance_repository.dart';
import '../../repositories/notifications_repository.dart';
import '../../repositories/trip_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../services/format_utils.dart';
import '../../services/weather_service.dart';
import '../../theme.dart';
import '../community/community_page.dart';
import '../community/my_community_posts_page.dart';
import '../community/community_post_detail_page.dart';
import '../group/group_trip_page.dart';
import '../insurance/insurance_messages_page.dart';
import '../insurance/insurance_partner_detail_page.dart';
import '../insurance/insurance_partner_list_page.dart';
import '../notifications/notifications_page.dart';
import '../profile/report_attraction_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildAdventureCard(),
            const SizedBox(height: 14),
            _buildQuickLinksRow(context),
            const SizedBox(height: 20),
            _buildRecommendedHeader(context),
            const SizedBox(height: 12),
            _buildRecommendedList(context),
            const SizedBox(height: 20),
            _buildInsuranceHeader(context),
            const SizedBox(height: 12),
            _buildInsuranceList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              (uid == null || uid.isEmpty)
                  ? const Text(
                      'Hi there',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                      ),
                    )
                  : StreamBuilder<AppUser?>(
                      stream: UserRepository.instance.watchProfile(uid),
                      builder: (context, snapshot) {
                        final name = snapshot.data?.name.trim() ?? '';
                        return Text(
                          name.isEmpty ? 'Hi there' : 'Hi, $name',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy,
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 4),
              const Text(
                'Where do you want to explore next ?',
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
            ],
          ),
          _notificationsBell(context),
        ],
      ),
    );
  }

  Widget _notificationsBell(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        HeaderIconButton(
          icon: Icons.notifications_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsPage()),
          ),
        ),
        if (uid != null)
          StreamBuilder<int>(
            stream: NotificationsRepository.instance.watchUnreadCount(uid),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildAdventureCard() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return _adventureCardShell(child: _adventureCardMessage('Sign in to see your next trip'));
    // Outer stream reads which trip (if any) the traveller pinned via the
    // card's switcher — see AppUser.pinnedTripId's doc comment.
    return StreamBuilder<AppUser?>(
      stream: UserRepository.instance.watchProfile(uid),
      builder: (context, profileSnap) {
        final pinnedTripId = profileSnap.data?.pinnedTripId;
        return StreamBuilder<List<Trip>>(
          stream: TripRepository.instance.watchMyTrips(uid),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return _adventureCardShell(
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
              );
            }
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final upcoming = snapshot.data!.where((t) => t.endDate != null && !t.endDate!.isBefore(today)).toList()
              ..sort((a, b) => (a.startDate ?? today).compareTo(b.startDate ?? today));
            if (upcoming.isEmpty) {
              return _adventureCardShell(child: _adventureCardMessage("No upcoming trip yet — let's plan one!"));
            }
            final pinnedMatch = upcoming.where((t) => t.id == pinnedTripId);
            final trip = pinnedMatch.isNotEmpty ? pinnedMatch.first : upcoming.first;
            return _adventureCardShell(
              trip: trip,
              child: _adventureCardContent(context, trip, today, uid: uid, upcoming: upcoming),
            );
          },
        );
      },
    );
  }

  void _showTripSwitcherSheet(BuildContext context, String uid, List<Trip> upcoming, String currentTripId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your Upcoming Trips', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
              const SizedBox(height: 4),
              const Text("Pick one to open — the home card will remember your choice next time.", style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
              const SizedBox(height: 14),
              ...upcoming.map((t) => _tripSwitcherRow(sheetContext, uid, t, selected: t.id == currentTripId)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tripSwitcherRow(BuildContext sheetContext, String uid, Trip t, {required bool selected}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final navigator = Navigator.of(sheetContext);
        navigator.pop();
        await UserRepository.instance.setPinnedTripId(uid, t.id);
        navigator.push(MaterialPageRoute(builder: (_) => GroupTripPage(tripId: t.id)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.08) : AppColors.chipGrey,
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: AppColors.primary) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.destination.isNotEmpty ? t.destination : t.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  if (t.dateRangeLabel.isNotEmpty)
                    Text(t.dateRangeLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _adventureCardShell({Trip? trip, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 196,
          decoration: BoxDecoration(
            color: AppColors.navy,
            image: DecorationImage(
              image: (trip != null && trip.coverImage.isNotEmpty)
                  ? NetworkImage(trip.coverImage)
                  : const AssetImage('assets/images/adventure_bg.jpg') as ImageProvider,
              fit: BoxFit.cover,
              onError: (_, __) {},
            ),
          ),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0x80000000), Color(0x00000000)],
                stops: [0.28, 0.6],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _adventureCardMessage(String message) {
    return Center(
      child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _adventureCardContent(BuildContext context, Trip trip, DateTime today, {required String uid, required List<Trip> upcoming}) {
    final start = trip.startDate;
    final daysToGo = start == null ? null : start.difference(today).inDays;
    final ongoing = daysToGo != null && daysToGo <= 0;
    return GestureDetector(
      // One upcoming trip: tapping the card opens it directly, same as
      // before. More than one: tapping opens the switcher sheet so there
      // is something to choose between — each row there both pins and
      // opens the chosen trip (see _tripSwitcherRow), so entering a trip
      // never needs more than this one tap either way.
      onTap: () => upcoming.length > 1
          ? _showTripSwitcherSheet(context, uid, upcoming, trip.id)
          : Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupTripPage(tripId: trip.id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Next Adventure',
            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.destination.isNotEmpty ? trip.destination : trip.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    if (trip.dateRangeLabel.isEmpty)
                      Text(
                        trip.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      )
                    else ...[
                      Text(
                        trip.dateOnlyLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trip.nightsLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: ongoing
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 3),
                        child: Text('Ongoing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black)),
                      )
                    : Column(
                        children: [
                          Text(
                            '${daysToGo ?? '-'}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
                          ),
                          const Text(
                            'days to go',
                            style: TextStyle(fontSize: 8, color: Colors.black),
                          ),
                        ],
                      ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                _cardInfoTile(Icons.flight_takeoff, 'Flight', trip.flights.isNotEmpty ? trip.flights.first.dateTime : '-'),
                _verticalDivider(),
                _cardInfoTile(Icons.bed_outlined, 'Hotel', trip.hotelStays.isNotEmpty ? trip.hotelStays.first.name : '-'),
                _verticalDivider(),
                _WeatherTile(
                  destination: trip.destination.isNotEmpty ? trip.destination : trip.name,
                  forDate: trip.startDate == null ? null : DateTime(trip.startDate!.year, trip.startDate!.month, trip.startDate!.day),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(height: 23, width: 1, color: const Color(0xFFE0E0E0));
  }

  // ---------------- AI banner ----------------
  // Community Post, Insurance Messages and Report new attraction spot used
  // to live on the Profile page, which felt like an odd place for them --
  // moved here, replacing the old "Let AI Plan" banner (Create Plan is
  // already reachable from the Next Adventure card and the Plan tab).
  Widget _buildQuickLinksRow(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _quickLinkCard(
              context,
              icon: Icons.dynamic_feed_outlined,
              label: 'My Post',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyCommunityPostsPage())),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: uid.isEmpty
                ? _quickLinkCard(
                    context,
                    icon: Icons.mail_outline,
                    label: 'Insurance Messages',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InsuranceMessagesPage())),
                  )
                : StreamBuilder<List<InsuranceChatSummary>>(
                    stream: InsuranceChatRepository.instance.watchChatsForTraveller(uid),
                    builder: (context, snapshot) {
                      final hasUnread = (snapshot.data ?? const []).any((c) => c.unreadForTraveller);
                      return _quickLinkCard(
                        context,
                        icon: Icons.mail_outline,
                        label: 'Insurance Messages',
                        badge: hasUnread,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InsuranceMessagesPage())),
                      );
                    },
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _quickLinkCard(
              context,
              icon: Icons.add_location_alt_outlined,
              label: 'Report New Attraction',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportAttractionPage())),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickLinkCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool badge = false,
  }) {
    // Shrunk from the original (34px icon circle, 12px vertical padding) --
    // the row read as three oversized tiles competing with the trip card
    // above them. Smaller icon + tighter padding reads as a row of compact
    // quick links instead.
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(icon, size: 13, color: AppColors.primary),
                ),
                if (badge)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            // Fixed 2-line height regardless of how many lines this
            // particular label actually wraps to ('My Post' is one line,
            // 'Report New Attraction' is two) -- otherwise the three cards
            // in the row end up visibly different heights.
            SizedBox(
              height: 24,
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.navy, height: 1.25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Recommended itinerary header ----------------
  Widget _buildRecommendedHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Community',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CommunityPage()),
            ),
            child: const Text(
              'View All',
              style: TextStyle(fontSize: 12, color: Color(0xFF0015FF)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedList(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text('Sign in to see community itineraries', style: TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
        ),
      );
    }
    return SizedBox(
      height: 200,
      child: StreamBuilder<List<CommunityPost>>(
        stream: CommunityRepository.instance.watchPosts(uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final posts = snapshot.data!.take(6).toList();
          if (posts.isEmpty) {
            return const Center(
              child: Text('No community itineraries yet', style: TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _buildItineraryCard(context, posts[index], uid),
          );
        },
      ),
    );
  }

  Widget _buildItineraryCard(BuildContext context, CommunityPost post, String uid) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CommunityPostDetailPage(post: post)),
      ),
      child: Container(
        width: 139,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 5, spreadRadius: 2),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                  child: post.images.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: post.images.first,
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (c, u) => Container(height: 100, color: AppColors.chipGrey),
                          errorWidget: (c, u, e) => Container(
                            height: 100,
                            color: AppColors.chipGrey,
                            alignment: Alignment.center,
                            child: const Icon(Icons.photo_camera_outlined, color: AppColors.textGrey),
                          ),
                        )
                      : Container(
                          height: 100,
                          color: AppColors.chipGrey,
                          alignment: Alignment.center,
                          child: const Icon(Icons.photo_camera_outlined, color: AppColors.textGrey),
                        ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => CommunityRepository.instance.toggleLike(post.id, uid, !post.liked),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(post.liked ? Icons.favorite : Icons.favorite_border,
                          size: 13, color: post.liked ? Colors.redAccent : AppColors.textGrey),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: AppColors.orange),
                      const SizedBox(width: 4),
                      Text('${post.avgRating.toStringAsFixed(1)} (${compactCount(post.ratingCount)})',
                          style: const TextStyle(fontSize: 8, color: Colors.black)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    post.location.isEmpty ? 'Unknown' : post.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 8, color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsuranceHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Insurance',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const InsurancePartnerListPage()),
            ),
            child: const Text(
              'View All',
              style: TextStyle(fontSize: 12, color: Color(0xFF0015FF)),
            ),
          ),
        ],
      ),
    );
  }

  // Shows insurers, not individual plans -- matches
  // insurance_partner_list_page.dart's deliberate partner-first design (its
  // own doc comment: "no 'browse all plans' shortcut... a plan is only ever
  // shown once a partner has been chosen"). This tile used to stream
  // InsuranceRepository.watchPlans() straight onto the homepage, which
  // skipped that flow entirely; now it mirrors the "View All" header right
  // above, which already pointed at InsurancePartnerListPage.
  Widget _buildInsuranceList() {
    return SizedBox(
      height: 110,
      child: StreamBuilder<List<InsurancePartner>>(
        stream: InsuranceRepository.instance.watchApprovedPartners(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final partners = snapshot.data ?? const [];
          if (partners.isEmpty) {
            return const Center(
              child: Text('No insurance partners yet', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: partners.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _InsurancePartnerTile(partner: partners[index]),
          );
        },
      ),
    );
  }
}

class _InsurancePartnerTile extends StatelessWidget {
  final InsurancePartner partner;
  const _InsurancePartnerTile({required this.partner});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => InsurancePartnerDetailPage(partner: partner)),
      ),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            partnerLogo(partner, size: 34),
            const SizedBox(height: 6),
            Text(
              partner.companyName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.navy),
            ),
            const SizedBox(height: 2),
            Text(
              partner.activePlanCount == 1 ? '1 plan available' : '${partner.activePlanCount} plans available',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _cardInfoTile(IconData icon, String label, String value) {
  return Expanded(
    child: Column(
      children: [
        Icon(icon, size: 13, color: Colors.black),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w500, color: Colors.black)),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 7, color: Colors.black),
        ),
      ],
    ),
  );
}

class _WeatherTile extends StatefulWidget {
  final String destination;
  final DateTime? forDate;
  const _WeatherTile({required this.destination, required this.forDate});

  @override
  State<_WeatherTile> createState() => _WeatherTileState();
}

class _WeatherTileState extends State<_WeatherTile> {
  DestinationWeather? _weather;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_WeatherTile old) {
    super.didUpdateWidget(old);
    if (old.destination != widget.destination || old.forDate != widget.forDate) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final weather = await WeatherService.instance.forDestination(widget.destination, forDate: widget.forDate);
    if (!mounted) return;
    setState(() {
      _weather = weather;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final weather = _weather;
    final icon = weather?.icon ?? Icons.wb_cloudy_outlined;
    final value = _loading ? '...' : (weather == null ? '-' : '${weather.tempLabel} ${weather.label}');
    return _cardInfoTile(icon, 'Weather', value);
  }
}
