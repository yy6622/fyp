import 'package:flutter/material.dart';

import '../../models/community_models.dart';
import '../../models/insurance_models.dart';
import '../../repositories/community_repository.dart';
import '../../repositories/insurance_repository.dart';
import '../../repositories/notifications_repository.dart';
import '../../repositories/trip_repository.dart';
import '../../services/auth_service.dart';
import '../../services/format_utils.dart';
import '../../services/weather_service.dart';
import '../../theme.dart';
import '../community/community_page.dart';
import '../community/community_post_detail_page.dart';
import '../group/group_trip_page.dart';
import '../insurance/insurance_list_page.dart';
import '../insurance/insurance_widgets.dart';
import '../notifications/notifications_page.dart';

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
            _buildAiBanner(),
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

  // ---------------- Header ----------------
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, Teoh',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              SizedBox(height: 4),
              Text(
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

  // Real inbox behind the bell — used to be a dead icon that just showed
  // "No new notifications" with no notification system behind it at all.
  // The red dot reflects actual unread `users/{uid}/notifications` docs
  // (a pending friend request, for now).
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

  // ---------------- Adventure card ----------------
  // The signed-in person's own real soonest-upcoming trip (not yet ended),
  // picked from their actual `trips/{tripId}` docs — this used to be a
  // fixed "New York, 25 May - 7 June 2026" shown to literally everyone
  // regardless of who was signed in or what trips they actually had.
  Widget _buildAdventureCard() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return _adventureCardShell(child: _adventureCardMessage('Sign in to see your next trip'));
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
        return _adventureCardShell(trip: upcoming.first, child: _adventureCardContent(context, upcoming.first, today));
      },
    );
  }

  /// The card's background/gradient/rounding/tap target — shared by the
  /// real-content state and the "sign in" / "no upcoming trip" states so
  /// all three look like the same card rather than two different widgets.
  /// Uses the trip's own real cover photo (see TripRepository.createTrip
  /// / PlacesApiService.destinationPhoto) once there is a trip to show.
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

  Widget _adventureCardContent(BuildContext context, Trip trip, DateTime today) {
    final start = trip.startDate;
    final daysToGo = start == null ? null : start.difference(today).inDays;
    final ongoing = daysToGo != null && daysToGo <= 0;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupTripPage(tripId: trip.id))),
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
                      // Date range and "X days Y nights" on their own
                      // lines — previously one line with both joined by
                      // "·", which squeezed the nights count out under
                      // the ellipsis on anything but a very short date range.
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
                // Real weather for the destination, via Open-Meteo — free
                // and keyless, same convention as PlacesApiService's
                // Nominatim geocoding/Overpass POIs (see
                // weather_service.dart). Shows the forecast for the trip's
                // start date when that's within Open-Meteo's ~15-day
                // forecast horizon, or today's actual reading once the
                // trip has started; _WeatherTile shows '-' rather than a
                // fabricated reading when neither is available yet.
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
  Widget _buildAiBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [Color(0xFF104259), Color(0xFF379BC9), Color(0xFFA0E1FF)],
            stops: [0.0, 0.48, 1.0],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: [
            AppImage('assets/images/home_robot.png', width: 42, height: 42),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Let AI Plan your perfect trip',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 10),
                  ),
                  Text(
                    'Get a personalized itinerary in seconds',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300, fontSize: 7),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Plan My Trips',
                style: TextStyle(color: AppColors.navy, fontSize: 9, fontWeight: FontWeight.w300),
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
            'Recommend Itinerary',
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
                      ? Image.network(
                          post.images.first,
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            height: 100,
                            color: AppColors.chipGrey,
                            alignment: Alignment.center,
                            child: const Icon(Icons.image_outlined, color: AppColors.textGrey),
                          ),
                        )
                      : Container(
                          height: 100,
                          color: AppColors.chipGrey,
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_outlined, color: AppColors.textGrey),
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

  // ---------------- Insurance section ----------------
  // Moved here from the Explore page — insurance isn't something people
  // browse for alongside flights/hotels, it belongs with the rest of the
  // trip-planning shortcuts on Home.
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
              MaterialPageRoute(builder: (_) => const InsuranceListPage()),
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

  Widget _buildInsuranceList() {
    return SizedBox(
      height: 110,
      child: StreamBuilder<List<InsurancePlan>>(
        stream: InsuranceRepository.instance.watchPlans(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final plans = snapshot.data ?? const [];
          if (plans.isEmpty) {
            return const Center(
              child: Text('No insurance plans yet', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: plans.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) => InsurancePlanTile(plan: plans[index]),
          );
        },
      ),
    );
  }
}

/// One of the three small white tiles at the bottom of the "Next
/// Adventure" card (Flight / Hotel / Weather) — a plain top-level
/// function rather than a HomePage method so [_WeatherTile] below can
/// build the exact same look once its own async weather value resolves.
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

/// The "Weather" tile on Home's "Next Adventure" card — real data from
/// [WeatherService] (Open-Meteo, free and keyless), fetched once per
/// destination/date rather than on every rebuild (Home's trip stream can
/// emit often; WeatherService's own short cache also protects against
/// hammering the API if several widgets ask for the same destination at
/// once). Shows '-' rather than a fabricated reading whenever the
/// destination can't be geocoded, the date is beyond Open-Meteo's
/// forecast horizon, or the request fails for any reason.
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
