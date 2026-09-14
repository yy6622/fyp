import 'package:flutter/material.dart';
import 'package:voya/detail_pages.dart';
import 'filter.dart' as filters;
import 'near_by.dart';
import 'theme.dart';

// Insurance used to be one of the categories here, but it now lives on the
// Home page instead (see homepage.dart) — Explore is for flights, hotels
// and places to visit, and Insurance was out of place next to them.

/// The category currently selected in the chip row. Drives which list
/// renders below the chips.
enum ExploreCategory { all, flights, accommodation, attractions }

extension _CategoryMeta on ExploreCategory {
  String get label {
    switch (this) {
      case ExploreCategory.all:
        return 'All';
      case ExploreCategory.flights:
        return 'Flights';
      case ExploreCategory.accommodation:
        return 'Hotels';
      case ExploreCategory.attractions:
        return 'Places';
    }
  }

  IconData get icon {
    switch (this) {
      case ExploreCategory.all:
        return Icons.grid_view_rounded;
      case ExploreCategory.flights:
        return Icons.flight_takeoff;
      case ExploreCategory.accommodation:
        return Icons.hotel_outlined;
      case ExploreCategory.attractions:
        return Icons.place_outlined;
    }
  }

  /// Maps this category to the matching filter sheet content.
  filters.FilterType get filterType {
    switch (this) {
      case ExploreCategory.all:
      case ExploreCategory.flights:
        return filters.FilterType.flight;
      case ExploreCategory.accommodation:
        return filters.FilterType.hotel;
      case ExploreCategory.attractions:
        return filters.FilterType.attraction;
    }
  }
}

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  ExploreCategory _selectedCategory = ExploreCategory.all;
  bool _favoritesOnly = false;
  bool _showTripSwitcher = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            if (_showTripSwitcher) _buildTripSwitcherOverlay(),
          ],
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
                icon: _favoritesOnly ? Icons.favorite : Icons.favorite_border,
                onTap: () => setState(() => _favoritesOnly = !_favoritesOnly),
              ),
              const SizedBox(width: 10),
              _circleIconButton(
                icon: Icons.tune,
                onTap: _openFilterSheet,
              ),
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

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => filters.FilterPage(type: _selectedCategory.filterType),
    );
  }

  // ---------------- Japan Trip card ----------------
  Widget _buildTripCard() {
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
                _tripInfoItem('Destination', 'Tokyo, Japan'),
                _verticalDivider(),
                _tripInfoItem('Date', '12 June 2026'),
                _verticalDivider(),
                _tripInfoItem('Travellers', '2 Travellers'),
                _verticalDivider(),
                _tripInfoItem('Budget', 'RM 4, 500'),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _showTripSwitcher = !_showTripSwitcher),
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
              child: const Text(
                'Japan Trip',
                style: TextStyle(
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
        onTap: () => setState(() => _showTripSwitcher = false),
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
                    children: List.generate(3, (i) {
                      return InkWell(
                        onTap: () => setState(() => _showTripSwitcher = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: i < 2
                                ? const Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))
                                : null,
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Japan Trip', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy)),
                                    SizedBox(height: 4),
                                    Text('Destination: Tokyo, Japan', style: TextStyle(fontSize: 9, color: AppColors.textGrey)),
                                    Text('Date: 12 June 2026', style: TextStyle(fontSize: 9, color: AppColors.textGrey)),
                                    Text('Travellers: 2 Travellers', style: TextStyle(fontSize: 9, color: AppColors.textGrey)),
                                    Text('Budget: RM 4, 500', style: TextStyle(fontSize: 9, color: AppColors.textGrey)),
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
          final selected = category == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = category),
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
    switch (_selectedCategory) {
      case ExploreCategory.all:
        return _buildAllView();
      case ExploreCategory.flights:
        return _buildFlightListView();
      case ExploreCategory.accommodation:
        return _buildHotelListView();
      case ExploreCategory.attractions:
        return _buildAttractionListView();
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
            onTap: () => setState(() => _selectedCategory = jumpTo),
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
  final List<_FlightData> _flights = List.generate(
    6,
        (i) => const _FlightData(
      depTime: '9:20',
      arrTime: '17:25',
      duration: '7h 5m',
      from: 'KUL',
      to: 'NRT',
      stops: 'Non-stop',
      price: 'RM 899',
      fareType: 'One Way',
    ),
  );

  Widget _buildFlightHorizontalList() {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _buildFlightCompactCard(),
      ),
    );
  }

  Widget _buildFlightCompactCard() {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DetailPageFlight()),
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
              const Icon(Icons.favorite_border, size: 16, color: AppColors.textGrey),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'KL → Tokyo',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy),
          ),
          const SizedBox(height: 4),
          const Text('12 Jun | One way', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
          const SizedBox(height: 10),
          const Text(
            'RM 899',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildFlightListView() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: _flights.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildFlightRowCard(_flights[index]),
    );
  }

  Widget _buildFlightRowCard(_FlightData flight) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DetailPageFlight()),
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
        ],
      ),
      ),
    );
  }

  // ================= ACCOMMODATION =================
  final List<_HotelData> _hotels = List.generate(
    6,
        (i) => const _HotelData(
      name: 'L Hotel',
      location: 'Shinjoku, Tokyo',
      rating: '4.8',
      reviews: '1.2k',
      price: 'RM 899',
      image: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=400',
    ),
  );

  Widget _buildHotelHorizontalList() {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _buildHotelCompactCard(),
      ),
    );
  }

  Widget _buildHotelCompactCard() {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DetailPageHotel()),
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
                  'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=400',
                  height: 95,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.favorite_border, size: 12, color: AppColors.textGrey),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'L Hotel, Khon Kaen',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy),
                ),
                const SizedBox(height: 6),
                Row(
                  children: const [
                    Icon(Icons.star, size: 12, color: AppColors.orange),
                    SizedBox(width: 4),
                    Text('4.8 (1.2k)', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                  ],
                ),
                const SizedBox(height: 6),
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'RM 899 ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      TextSpan(
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
      itemCount: _hotels.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildHotelRowCard(_hotels[index]),
    );
  }

  Widget _buildHotelRowCard(_HotelData hotel) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DetailPageHotel()),
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
          const Icon(Icons.favorite_border, size: 18, color: AppColors.textGrey),
        ],
      ),
      ),
    );
  }

  // ================= ATTRACTIONS =================
  final List<_AttractionData> _attractions = [
    const _AttractionData(
      name: 'Senso-ji Temple',
      category: 'Cultural',
      rating: '4.7',
      reviews: '3.4k',
      price: 'Free entry',
      image: 'https://images.unsplash.com/photo-1478436127897-769e1b3f0f36?w=400',
    ),
    const _AttractionData(
      name: 'TeamLab Planets',
      category: 'Museum',
      rating: '4.9',
      reviews: '2.1k',
      price: 'RM 120',
      image: 'https://images.unsplash.com/photo-1554797589-7241bb691973?w=400',
    ),
    const _AttractionData(
      name: 'Shibuya Crossing',
      category: 'Nature',
      rating: '4.6',
      reviews: '5.0k',
      price: 'Free entry',
      image: 'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?w=400',
    ),
    const _AttractionData(
      name: 'Mount Fuji Viewpoint',
      category: 'Adventure',
      rating: '4.8',
      reviews: '1.8k',
      price: 'RM 60',
      image: 'https://images.unsplash.com/photo-1570459027562-4a916cc6113f?w=400',
    ),
  ];

  Widget _buildAttractionHorizontalList() {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _buildAttractionCompactCard(_attractions[index % _attractions.length]),
      ),
    );
  }

  Widget _buildAttractionCompactCard(_AttractionData item) {
    return Container(
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
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.favorite_border, size: 12, color: AppColors.textGrey),
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
    );
  }

  Widget _buildAttractionListView() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: _attractions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildAttractionRowCard(_attractions[index]),
    );
  }

  Widget _buildAttractionRowCard(_AttractionData item) {
    return Container(
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
          const Icon(Icons.favorite_border, size: 18, color: AppColors.textGrey),
        ],
      ),
    );
  }

}

// ---------------------------------------------------------------------
// Data models (swap these for your real API models)
// ---------------------------------------------------------------------
class _FlightData {
  final String depTime, arrTime, duration, from, to, stops, price, fareType;
  const _FlightData({
    required this.depTime,
    required this.arrTime,
    required this.duration,
    required this.from,
    required this.to,
    required this.stops,
    required this.price,
    required this.fareType,
  });
}

class _HotelData {
  final String name, location, rating, reviews, price, image;
  const _HotelData({
    required this.name,
    required this.location,
    required this.rating,
    required this.reviews,
    required this.price,
    required this.image,
  });
}

class _AttractionData {
  final String name, category, rating, reviews, price, image;
  const _AttractionData({
    required this.name,
    required this.category,
    required this.rating,
    required this.reviews,
    required this.price,
    required this.image,
  });
}

