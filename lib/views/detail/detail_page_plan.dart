import 'package:flutter/material.dart';

import '../../controllers/detail_page_controller.dart';
import '../../models/itinerary_detail_models.dart';
import '../../theme.dart';
import 'all_reviews_page.dart';
import 'detail_widgets.dart';

// ---------------------------------------------------------------------
// Plan / itinerary detail (Itinerary / Media / Review tabs)
// ---------------------------------------------------------------------
class DetailPagePlan extends StatefulWidget {
  const DetailPagePlan({super.key});

  @override
  State<DetailPagePlan> createState() => _DetailPagePlanState();
}

class _DetailPagePlanState extends State<DetailPagePlan> {
  final DetailPagePlanController controller = DetailPagePlanController();

  final List<ItineraryDay> _days = const [
    ItineraryDay(
      day: 1,
      items: [
        ItineraryDayItem(time: '10:30', icon: Icons.flight_land, label: 'Arrive to Narita Airport (NRT)'),
        ItineraryDayItem(time: '14:30', icon: Icons.hotel_outlined, label: 'Check-in L Hotel'),
        ItineraryDayItem(time: '16:30', icon: Icons.shopping_bag_outlined, label: 'Shibaya Shopping Mall'),
        ItineraryDayItem(time: '19:30', icon: Icons.restaurant_outlined, label: 'Dinner at Uobei Shibuya'),
      ],
    ),
    ItineraryDay(day: 2, items: []),
    ItineraryDay(day: 3, items: []),
    ItineraryDay(day: 4, items: []),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const DetailHeader(title: ''),
            Expanded(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(radius: 26, backgroundColor: Color(0xFFD9D9D9)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Sarah.W', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
                              Text('1.2k saves', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: controller.toggleFollowing,
                          child: Icon(controller.isFollowing ? Icons.check : Icons.add, color: AppColors.navy),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: controller.toggleSaved,
                          child: Icon(
                            controller.isSaved ? Icons.favorite : Icons.favorite_border,
                            color: controller.isSaved ? Colors.redAccent : AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'New York 7 days 6 night',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'A carefully paced trip through the city that never sleeps — iconic sights, great food, '
                      'and a couple of days built in to just wander.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 4),
                    const Text('READ MORE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0015FF))),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _statTile('7', 'Days'),
                        _statTile('12', 'Destinations'),
                        _statTile('RM1.2k', 'Budget'),
                        _statTile('4.9', 'Rating'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _planTabButton('Itinerary', DetailPlanTab.itinerary)),
                        Expanded(child: _planTabButton('Media', DetailPlanTab.media)),
                        Expanded(child: _planTabButton('Review', DetailPlanTab.review)),
                      ],
                    ),
                    const Divider(height: 1, color: Color(0xFFECECEC)),
                    const SizedBox(height: 16),
                    if (controller.tab == DetailPlanTab.itinerary) ..._itineraryContent(),
                    if (controller.tab == DetailPlanTab.media) _mediaContent(),
                    if (controller.tab == DetailPlanTab.review) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Reviews', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const AllReviewsPage(title: 'New York 7 days 6 night', ratingSummary: '4.9 (128 reviews)'),
                            )),
                            child: const Text('View All', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.blue)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Top 3 only — the rest are a tap away via "View All".
                      ...kSampleReviews.take(3).expand((r) => [ReviewCard(data: r), const SizedBox(height: 12)]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
        ],
      ),
    );
  }

  Widget _planTabButton(String label, DetailPlanTab tab) {
    final selected = controller.tab == tab;
    return GestureDetector(
      onTap: () => controller.setTab(tab),
      child: Container(
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textGrey),
        ),
      ),
    );
  }

  List<Widget> _itineraryContent() {
    return _days.map((day) {
      final expanded = controller.expandedDay == day.day - 1;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              InkWell(
                onTap: () => controller.toggleDay(day.day - 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Day ${day.day}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.navy),
                    ],
                  ),
                ),
              ),
              if (expanded && day.items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(
                    children: day.items.map((item) => _timelineItem(item)).toList(),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _timelineItem(ItineraryDayItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(item.time, style: const TextStyle(fontSize: 11, color: AppColors.textGrey))),
          const SizedBox(width: 8),
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Icon(item.icon, size: 15, color: AppColors.navy),
          const SizedBox(width: 8),
          Expanded(child: Text(item.label, style: const TextStyle(fontSize: 12, color: Color(0xFF0015FF)))),
        ],
      ),
    );
  }

  Widget _mediaContent() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: List.generate(
        6,
        (i) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AppImage('assets/images/adventure_bg.jpg', fit: BoxFit.cover),
        ),
      ),
    );
  }
}
