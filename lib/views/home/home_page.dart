import 'package:flutter/material.dart';

import '../../models/community_models.dart';
import '../../models/insurance_models.dart';
import '../../theme.dart';
import '../community/community_page.dart';
import '../community/community_post_detail_page.dart';
import '../insurance/insurance_list_page.dart';
import '../insurance/insurance_widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
      padding: const EdgeInsets.symmetric(horizontal: 18),
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
          GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No new notifications')),
            ),
            child: AppImage('assets/images/home_bell.png', width: 29, height: 29),
          ),
        ],
      ),
    );
  }

  // ---------------- Adventure card ----------------
  Widget _buildAdventureCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 196,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/adventure_bg.jpg'),
              fit: BoxFit.cover,
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
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New York',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '25 May - 7 June 2026',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                          Text(
                            '13 days 12 nights',
                            style: TextStyle(color: Colors.white, fontSize: 8),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Column(
                          children: [
                            Text(
                              '8',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
                            ),
                            Text(
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
                        _cardInfoTile(Icons.flight_takeoff, 'Flight', '25 May 2026, 14.30'),
                        _verticalDivider(),
                        _cardInfoTile(Icons.bed_outlined, 'Hotel', 'Artezen Hotel'),
                        _verticalDivider(),
                        _cardInfoTile(Icons.wb_cloudy_outlined, 'Weather', '24°C/18°C'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(height: 23, width: 1, color: const Color(0xFFE0E0E0));
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
            style: const TextStyle(fontSize: 7, color: Colors.black),
          ),
        ],
      ),
    );
  }

  // ---------------- AI banner ----------------
  Widget _buildAiBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
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
      padding: const EdgeInsets.symmetric(horizontal: 18),
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
    return SizedBox(
      height: 200,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _buildItineraryCard(context),
      ),
    );
  }

  Widget _buildItineraryCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CommunityPostDetailPage(post: mockCommunityPosts.first)),
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
                  child: AppImage(
                    'assets/images/adventure_bg.jpg',
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: AppImage('assets/images/icon_like.png', width: 19, height: 19),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'New York 7 days 6 night',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      AppImage('assets/images/icon_star.png', width: 12, height: 12),
                      const SizedBox(width: 4),
                      const Text('4.8(1.2k)', style: TextStyle(fontSize: 8, color: Colors.black)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Budget RM 6000 per members',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 8, color: AppColors.textGrey),
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
      padding: const EdgeInsets.symmetric(horizontal: 18),
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
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: insurancePlans.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => InsurancePlanTile(plan: insurancePlans[index]),
      ),
    );
  }
}
