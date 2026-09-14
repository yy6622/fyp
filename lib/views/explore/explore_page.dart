import 'package:flutter/material.dart';

import '../../controllers/explore_controller.dart';
import '../../models/explore_models.dart';
import '../../repositories/catalog_repository.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../detail/detail_page_attraction.dart';
import '../detail/detail_page_flight.dart';
import '../detail/detail_page_hotel.dart';
import '../detail/detail_page_restaurant.dart';
import '../detail/detail_widgets.dart' show tagChip;
import '../filter/filter_page.dart';
import '../near_by/near_by_page.dart';
import 'saved_items_page.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final ExploreController controller = ExploreController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 4),
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildTripCard(),
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                  const SizedBox(height: 14),
                  _buildCategoryChips(),
                  const SizedBox(height: 10),
                  Expanded(child: _buildBody()),
                ],
              ),
              if (controller.showTripSwitcher) _buildTripSwitcherOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Header ----------------
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Find your next adventure',
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
            ],
          ),
          Row(
            children: [
              _circleIconButton(
                icon: Icons.favorite_border,
                onTap: _openSavedItems,
              ),
              // "All" is a mixed discovery feed across every category, so
              // there's no single filter sheet that applies to it — the
              // filter button only makes sense once a specific category
              // (Flights/Hotels/Places/Restaurants) is selected.
              if (controller.selectedCategory != ExploreCategory.all) ...[
                const SizedBox(width: 10),
                _circleIconButton(
                  icon: Icons.tune,
                  onTap: _openFilterSheet,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleIconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  void _openSavedItems() {
    final trip = controller.selectedTrip;
    if (trip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a plan first to save flights, hotels and places to it.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SavedItemsPage(tripId: trip.id, tripName: trip.name)),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterPage(type: controller.selectedCategory.filterType),
    );
  }

  // ---------------- Current trip card ----------------
  Widget _buildTripCard() {
    final trip = controller.selectedTrip;
    if (trip == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: AppColors.chipGrey),
          child: const Text('No trips yet — create one from the Plan tab to see it here.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary, width: 1.2),
            ),
            child: Row(
              children: [
                _tripInfoItem('Destination', trip.destination.isEmpty ? '-' : trip.destination),
                _verticalDivider(),
                _tripInfoItem('Date', trip.startDate == null ? '-' : trip.dateRangeLabel.split(' · ').first),
                _verticalDivider(),
                _tripInfoItem('Travellers', '${trip.memberIds.length} Travellers'),
                _verticalDivider(),
                _tripInfoItem('Budget', 'RM ${trip.budgetPerPerson.toStringAsFixed(0)}'),
                const SizedBox(width: 8),
                if (controller.trips.length > 1)
                  GestureDetector(
                    onTap: () => controller.toggleTripSwitcher(),
                    child: const Icon(Icons.swap_horiz, color: AppColors.primary, size: 20),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              color: const Color(0xFFF7F8FA),
              child: Text(
                trip.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Trip switcher popup ----------------
  Widget _buildTripSwitcherOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => controller.closeTripSwitcher(),
        child: Container(
          color: Colors.black.withValues(alpha: 0.4),
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 96),
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(controller.trips.length, (i) {
                      final trip = controller.trips[i];
                      return InkWell(
                        onTap: () => controller.selectTrip(i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: i < controller.trips.length - 1
                                ? const Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))
                                : null,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(trip.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy)),
                                    const SizedBox(height: 4),
                                    Text('Destination: ${trip.destination}', style: const TextStyle(fontSize: 9, color: AppColors.textGrey)),
                                    Text('Travellers: ${trip.memberIds.length}', style: const TextStyle(fontSize: 9, color: AppColors.textGrey)),
                                    Text('Budget: RM ${trip.budgetPerPerson.toStringAsFixed(0)}', style: const TextStyle(fontSize: 9, color: AppColors.textGrey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      height: 30,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: const Color(0xFFE2E6E9),
    );
  }

  Widget _tripInfoItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textGrey)),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ---------------- Search bar ----------------
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.chipGrey,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.textGrey, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search destination, flight, hotel, place, ...',
                  hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 12.5),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            const Icon(Icons.mic_none, color: AppColors.textGrey, size: 20),
          ],
        ),
      ),
    );
  }

  // ---------------- Category chips ----------------
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: ExploreCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = ExploreCategory.values[index];
          final selected = category == controller.selectedCategory;
          return GestureDetector(
            onTap: () => controller.setSelectedCategory(category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.chipGrey,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    category.icon,
                    size: 16,
                    color: selected ? Colors.white : AppColors.textGrey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textGrey,
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

  // ---------------- Body switch (the important part) ----------------
  Widget _buildBody() {
    switch (controller.selectedCategory) {
      case ExploreCategory.all:
        return _buildAllView();
      case ExploreCategory.flights:
        return _buildFlightListView();
      case ExploreCategory.accommodation:
        return _buildHotelListView();
      case ExploreCategory.attractions:
        return _buildAttractionListView();
      case ExploreCategory.restaurants:
        return _buildRestaurantListView();
    }
  }

  // ================= ALL (mixed / discovery view) =================
  Widget _buildAllView() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildExploreBanner(),
        const SizedBox(height: 22),
        _buildSectionHeader(Icons.flight_takeoff, 'Best Flight Deals', ExploreCategory.flights),
        const SizedBox(height: 12),
        _buildFlightHorizontalList(),
        const SizedBox(height: 22),
        _buildSectionHeader(Icons.hotel_outlined, 'Recommended Hotels', ExploreCategory.accommodation),
        const SizedBox(height: 12),
        _buildHotelHorizontalList(),
        const SizedBox(height: 22),
        _buildSectionHeader(Icons.place_outlined, 'Top Places', ExploreCategory.attractions),
        const SizedBox(height: 12),
        _buildAttractionHorizontalList(),
        const SizedBox(height: 22),
        _buildSectionHeader(Icons.restaurant_outlined, 'Top Restaurants', ExploreCategory.restaurants),
        const SizedBox(height: 12),
        _buildRestaurantHorizontalList(),
        const SizedBox(height: 22),
        _buildNearbyPreview(),
      ],
    );
  }

  Widget _buildNearbyPreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.near_me_outlined, size: 18, color: AppColors.navy),
              SizedBox(width: 8),
              Text('Explore Nearby', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NearByPage())),
            child: const Text('View On Map', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Widget _buildExploreBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 180,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(
                'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800',
              ),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.05),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Explore Japan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sakura session is here',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                const Text(
                  'Up to 30 % off on flight and hotel',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Explore Now',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, ExploreCategory jumpTo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.navy),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => controller.setSelectedCategory(jumpTo),
            child: const Text(
              'View All',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= FLIGHTS =================
  Widget _buildFlightHorizontalList() {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: controller.flights.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _buildFlightCompactCard(controller.flights[index]),
      ),
    );
  }

  Widget _buildFlightCompactCard(CatalogFlight flight) {
    final favorited = flight.isSavedForTrip(AuthService.instance.currentUser?.uid ?? '', controller.selectedTrip?.id);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _flightDetailFor(flight)),
      ),
      child: Container(
      width: 145,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Color(0xFFE4372A),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'AA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => controller.toggleFlightFavorite(flight),
                child: Icon(favorited ? Icons.favorite : Icons.favorite_border,
                    size: 16, color: favorited ? Colors.redAccent : AppColors.textGrey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${flight.from} → ${flight.to}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text('${flight.depTime} | ${flight.fareType}', style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
          const SizedBox(height: 10),
          Text(
            flight.price,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ],
      ),
      ),
    );
  }

  DetailPageFlight _flightDetailFor(CatalogFlight flight) => DetailPageFlight(
        fromCode: flight.from,
        toCode: flight.to,
        depTime: flight.depTime,
        arrTime: flight.arrTime,
        duration: flight.duration,
        stops: flight.stops,
        price: flight.price,
        priceSuffix: flight.fareType,
      );

  Widget _buildFlightListView() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: controller.flights.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildFlightRowCard(controller.flights[index]),
    );
  }

  Widget _buildFlightRowCard(CatalogFlight flight) {
    final favorited = flight.isSavedForTrip(AuthService.instance.currentUser?.uid ?? '', controller.selectedTrip?.id);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _flightDetailFor(flight)),
      ),
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: AppColors.chipGrey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      flight.depTime,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            flight.duration,
                            style: const TextStyle(fontSize: 9, color: AppColors.textGrey),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            height: 1,
                            color: const Color(0xFFD9D9D9),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      flight.arrTime,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(flight.from, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
                    Text(flight.stops, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
                    Text(flight.to, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                flight.price,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Text(flight.fareType, style: const TextStyle(fontSize: 9, color: AppColors.textGrey)),
            ],
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => controller.toggleFlightFavorite(flight),
            child: Icon(favorited ? Icons.favorite : Icons.favorite_border, size: 18, color: favorited ? Colors.redAccent : AppColors.textGrey),
          ),
        ],
      ),
      ),
    );
  }

  // ================= ACCOMMODATION =================
  Widget _buildHotelHorizontalList() {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: controller.hotels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _buildHotelCompactCard(controller.hotels[index]),
      ),
    );
  }

  Widget _buildHotelCompactCard(CatalogHotel hotel) {
    final favorited = hotel.isSavedForTrip(AuthService.instance.currentUser?.uid ?? '', controller.selectedTrip?.id);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetailPageHotel(name: hotel.name, location: hotel.location, ratingLabel: '${hotel.rating}(${hotel.reviews})', pricePerNight: hotel.price)),
      ),
      child: Container(
      width: 145,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  hotel.image,
                  height: 95,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => controller.toggleHotelFavorite(hotel),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(favorited ? Icons.favorite : Icons.favorite_border, size: 12, color: favorited ? Colors.redAccent : AppColors.textGrey),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hotel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, size: 12, color: AppColors.orange),
                    const SizedBox(width: 4),
                    Text('${hotel.rating} (${hotel.reviews})', style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                  ],
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${hotel.price} ',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const TextSpan(
                        text: 'per night',
                        style: TextStyle(fontSize: 9, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildHotelListView() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: controller.hotels.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildHotelRowCard(controller.hotels[index]),
    );
  }

  Widget _buildHotelRowCard(CatalogHotel hotel) {
    final favorited = hotel.isSavedForTrip(AuthService.instance.currentUser?.uid ?? '', controller.selectedTrip?.id);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetailPageHotel(name: hotel.name, location: hotel.location, ratingLabel: '${hotel.rating}(${hotel.reviews})', pricePerNight: hotel.price)),
      ),
      child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              hotel.image,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hotel.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: AppColors.orange),
                    const SizedBox(width: 4),
                    Text('${hotel.rating}(${hotel.reviews})',
                        style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(hotel.location, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${hotel.price} ',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const TextSpan(
                        text: 'per night',
                        style: TextStyle(fontSize: 10, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => controller.toggleHotelFavorite(hotel),
            child: Icon(favorited ? Icons.favorite : Icons.favorite_border, size: 18, color: favorited ? Colors.redAccent : AppColors.textGrey),
          ),
        ],
      ),
      ),
    );
  }

  // ================= ATTRACTIONS =================
  Widget _buildAttractionHorizontalList() {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: controller.attractions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _buildAttractionCompactCard(controller.attractions[index]),
      ),
    );
  }

  Widget _buildAttractionCompactCard(CatalogAttraction item) {
    final favorited = item.isSavedForTrip(AuthService.instance.currentUser?.uid ?? '', controller.selectedTrip?.id);
    return GestureDetector(
      onTap: () => _openAttractionDetail(item, favorited),
      child: Container(
      width: 145,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(item.image, height: 95, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => controller.toggleAttractionFavorite(item),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(favorited ? Icons.favorite : Icons.favorite_border, size: 12, color: favorited ? Colors.redAccent : AppColors.textGrey),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, size: 12, color: AppColors.orange),
                    const SizedBox(width: 4),
                    Text('${item.rating} (${item.reviews})', style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(item.price, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _openAttractionDetail(CatalogAttraction item, bool favorited) {
    final tripId = controller.selectedTrip?.id;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DetailPageAttraction(
        attraction: item,
        saved: favorited,
        onToggleSave: tripId == null ? null : () => controller.toggleAttractionFavorite(item),
      ),
    ));
  }

  Widget _buildAttractionListView() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: controller.attractions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildAttractionRowCard(controller.attractions[index]),
    );
  }

  Widget _buildAttractionRowCard(CatalogAttraction item) {
    final favorited = item.isSavedForTrip(AuthService.instance.currentUser?.uid ?? '', controller.selectedTrip?.id);
    return GestureDetector(
      onTap: () => _openAttractionDetail(item, favorited),
      child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(item.image, width: 80, height: 80, fit: BoxFit.cover),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.chipGrey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(item.category, style: const TextStyle(fontSize: 9.5, color: AppColors.textGrey)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: AppColors.orange),
                    const SizedBox(width: 4),
                    Text('${item.rating} (${item.reviews})', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(item.price, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => controller.toggleAttractionFavorite(item),
            child: Icon(favorited ? Icons.favorite : Icons.favorite_border, size: 18, color: favorited ? Colors.redAccent : AppColors.textGrey),
          ),
        ],
      ),
      ),
    );
  }

  // ================= RESTAURANTS =================
  Widget _buildRestaurantHorizontalList() {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: controller.restaurants.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _buildRestaurantCompactCard(controller.restaurants[index]),
      ),
    );
  }

  void _openRestaurantDetail(CatalogRestaurant item, bool favorited) {
    final tripId = controller.selectedTrip?.id;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DetailPageRestaurant(
        restaurant: item,
        saved: favorited,
        onToggleSave: tripId == null ? null : () => controller.toggleRestaurantFavorite(item),
      ),
    ));
  }

  Widget _buildRestaurantCompactCard(CatalogRestaurant item) {
    final favorited = item.isSavedForTrip(AuthService.instance.currentUser?.uid ?? '', controller.selectedTrip?.id);
    return GestureDetector(
      onTap: () => _openRestaurantDetail(item, favorited),
      child: Container(
      width: 145,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(item.image, height: 95, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => controller.toggleRestaurantFavorite(item),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(favorited ? Icons.favorite : Icons.favorite_border, size: 12, color: favorited ? Colors.redAccent : AppColors.textGrey),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, size: 12, color: AppColors.orange),
                    const SizedBox(width: 4),
                    Text('${item.rating} (${item.reviews})', style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(item.priceRange, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildRestaurantListView() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: controller.restaurants.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildRestaurantRowCard(controller.restaurants[index]),
    );
  }

  Widget _buildRestaurantRowCard(CatalogRestaurant item) {
    final favorited = item.isSavedForTrip(AuthService.instance.currentUser?.uid ?? '', controller.selectedTrip?.id);
    return GestureDetector(
      onTap: () => _openRestaurantDetail(item, favorited),
      child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(item.image, width: 80, height: 80, fit: BoxFit.cover),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
                const SizedBox(height: 6),
                Wrap(spacing: 4, runSpacing: 4, children: item.cuisineTags.map(tagChip).toList()),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: AppColors.orange),
                    const SizedBox(width: 4),
                    Text('${item.rating} (${item.reviews})', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(item.location, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                const SizedBox(height: 4),
                Text(item.priceRange, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => controller.toggleRestaurantFavorite(item),
            child: Icon(favorited ? Icons.favorite : Icons.favorite_border, size: 18, color: favorited ? Colors.redAccent : AppColors.textGrey),
          ),
        ],
      ),
      ),
    );
  }
}
