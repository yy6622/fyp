import 'package:flutter/material.dart';

import 'theme.dart';

// ---------------------------------------------------------------------
// Flight detail
// ---------------------------------------------------------------------
class DetailPageFlight extends StatelessWidget {
  const DetailPageFlight({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _DetailHeader(title: 'Air Asia'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('KUL', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy)),
                            SizedBox(height: 4),
                            Text('Kuala Lumpur', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.arrow_forward, color: AppColors.navy),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: const [
                            Text('NRT', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy)),
                            SizedBox(height: 4),
                            Text('Tokyo (Narita)', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('9:20', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                            SizedBox(height: 4),
                            Text('12 June 2026', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: const [
                            Text('7h5m', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                            SizedBox(height: 6),
                            Divider(color: AppColors.textGrey, thickness: 1),
                            Text('Non-stop', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: const [
                            Text('17:25', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                            SizedBox(height: 4),
                            Text('12 June 2026', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFECECEC)),
                  const SizedBox(height: 16),
                  const Text('Flight Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.chipGrey,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: const [
                            Expanded(child: _InfoField(label: 'Airline', value: 'Air Asia')),
                            Expanded(child: _InfoField(label: 'Aircraft', value: 'Airbus A330-300')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: const [
                            Expanded(child: _InfoField(label: 'Baggage', value: '20kg checked bag')),
                            Expanded(child: _InfoField(label: 'Cabin', value: 'Economy')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _BookingBar(price: 'RM 899', priceSuffix: 'One Way', buttonLabel: 'Select Flight'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Hotel detail (Details / Review tabs)
// ---------------------------------------------------------------------
class DetailPageHotel extends StatefulWidget {
  const DetailPageHotel({super.key});

  @override
  State<DetailPageHotel> createState() => _DetailPageHotelState();
}

class _DetailPageHotelState extends State<DetailPageHotel> {
  bool _showReview = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const _DetailHeader(title: 'L Hotel'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                children: [
                  const Text('L Hotel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 8),
                  Row(
                    children: const [
                      Icon(Icons.star, size: 16, color: AppColors.orange),
                      SizedBox(width: 4),
                      Text('4.8(1.2k)', style: TextStyle(fontSize: 13, color: Colors.black)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Shinjoku, Tokyo   1.2km to city center', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 74,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: const [
                        _AmenityIcon(icon: Icons.wifi, label: 'Free Wifi'),
                        _AmenityIcon(icon: Icons.free_breakfast_outlined, label: 'Breakfast'),
                        _AmenityIcon(icon: Icons.cleaning_services_outlined, label: 'Housekeeping'),
                        _AmenityIcon(icon: Icons.luggage_outlined, label: 'Luggage storage'),
                        _AmenityIcon(icon: Icons.support_agent_outlined, label: '24h Desk'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _tabButton('Details', !_showReview)),
                      Expanded(child: _tabButton('Review', _showReview)),
                    ],
                  ),
                  const Divider(height: 1, color: Color(0xFFECECEC)),
                  const SizedBox(height: 16),
                  if (!_showReview) ..._detailsContent() else ..._reviewContent(),
                ],
              ),
            ),
            _BookingBar(price: 'RM 320', priceSuffix: 'per night · Total RM960 (3 nights)', buttonLabel: 'Select Hotel'),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, bool selected) {
    return GestureDetector(
      onTap: () => setState(() => _showReview = label == 'Review'),
      child: Container(
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textGrey,
          ),
        ),
      ),
    );
  }

  List<Widget> _detailsContent() {
    return [
      _bookingRow('Check-in', '12 Jun 2026', 'Check-out', '15 Jun 2026'),
      const SizedBox(height: 10),
      _bookingRowSingle('2 Guests / 1 Room'),
      const SizedBox(height: 20),
    ];
  }

  Widget _bookingRow(String label1, String value1, String label2, String value2) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: _InfoField(label: label1, value: value1)),
          Container(height: 30, width: 1, color: const Color(0xFFDDDDDD)),
          const SizedBox(width: 16),
          Expanded(child: _InfoField(label: label2, value: value2)),
          const Icon(Icons.chevron_right, color: AppColors.textGrey),
        ],
      ),
    );
  }

  Widget _bookingRowSingle(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black)),
          const Icon(Icons.chevron_right, color: AppColors.textGrey),
        ],
      ),
    );
  }

  List<Widget> _reviewContent() {
    return List.generate(2, (i) => const _ReviewCard()).expand((w) => [w, const SizedBox(height: 12)]).toList();
  }
}

class _AmenityIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _AmenityIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: AppColors.chipGrey, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: AppColors.navy),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 56,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 8.5, color: AppColors.textGrey),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.chipGrey,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 16, backgroundColor: Color(0xFFD9D9D9)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Vivi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                    Text('🇲🇾 Malaysia', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (i) => const Icon(Icons.star, size: 13, color: AppColors.orange)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'The room was comfortable, clean, and spacious, and the air conditioning was cold enough.',
            style: TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Plan / itinerary detail (Itinerary / Media / Review tabs)
// ---------------------------------------------------------------------
class DetailPagePlan extends StatefulWidget {
  const DetailPagePlan({super.key});

  @override
  State<DetailPagePlan> createState() => _DetailPagePlanState();
}

enum _PlanTab { itinerary, media, review }

class _DetailPagePlanState extends State<DetailPagePlan> {
  _PlanTab _tab = _PlanTab.itinerary;
  int? _expandedDay = 0;
  bool _isFollowing = false;
  bool _isSaved = false;

  final List<_DayPlan> _days = const [
    _DayPlan(
      day: 1,
      items: [
        _DayItem(time: '10:30', icon: Icons.flight_land, label: 'Arrive to Narita Airport (NRT)'),
        _DayItem(time: '14:30', icon: Icons.hotel_outlined, label: 'Check-in L Hotel'),
        _DayItem(time: '16:30', icon: Icons.shopping_bag_outlined, label: 'Shibaya Shopping Mall'),
        _DayItem(time: '19:30', icon: Icons.restaurant_outlined, label: 'Dinner at Uobei Shibuya'),
      ],
    ),
    _DayPlan(day: 2, items: []),
    _DayPlan(day: 3, items: []),
    _DayPlan(day: 4, items: []),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const _DetailHeader(title: ''),
            Expanded(
              child: ListView(
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
                        onTap: () => setState(() => _isFollowing = !_isFollowing),
                        child: Icon(_isFollowing ? Icons.check : Icons.add, color: AppColors.navy),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => setState(() => _isSaved = !_isSaved),
                        child: Icon(
                          _isSaved ? Icons.favorite : Icons.favorite_border,
                          color: _isSaved ? Colors.redAccent : AppColors.textGrey,
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
                      Expanded(child: _planTabButton('Itinerary', _PlanTab.itinerary)),
                      Expanded(child: _planTabButton('Media', _PlanTab.media)),
                      Expanded(child: _planTabButton('Review', _PlanTab.review)),
                    ],
                  ),
                  const Divider(height: 1, color: Color(0xFFECECEC)),
                  const SizedBox(height: 16),
                  if (_tab == _PlanTab.itinerary) ..._itineraryContent(),
                  if (_tab == _PlanTab.media) _mediaContent(),
                  if (_tab == _PlanTab.review) ...List.generate(4, (i) => const _ReviewCard()).expand((w) => [w, const SizedBox(height: 12)]),
                ],
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

  Widget _planTabButton(String label, _PlanTab tab) {
    final selected = _tab == tab;
    return GestureDetector(
      onTap: () => setState(() => _tab = tab),
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
      final expanded = _expandedDay == day.day - 1;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(() => _expandedDay = expanded ? null : day.day - 1),
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

  Widget _timelineItem(_DayItem item) {
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

class _DayPlan {
  final int day;
  final List<_DayItem> items;
  const _DayPlan({required this.day, required this.items});
}

class _DayItem {
  final String time;
  final IconData icon;
  final String label;
  const _DayItem({required this.time, required this.icon, required this.label});
}

// ---------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------
class _DetailHeader extends StatelessWidget {
  final String title;
  const _DetailHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    // A plain white app bar (back button + centered title + bottom
    // border) sitting above the hero photo — matching the flight/hotel
    // detail designs — rather than the title being overlaid on the image.
    return Column(
      children: [
        Container(
          height: 52,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFECECEC), width: 1)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        AppImage('assets/images/adventure_bg.jpg', height: 160, width: double.infinity, fit: BoxFit.cover),
      ],
    );
  }
}

class _InfoField extends StatelessWidget {
  final String label;
  final String value;
  const _InfoField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
      ],
    );
  }
}

class _BookingBar extends StatelessWidget {
  final String price;
  final String priceSuffix;
  final String buttonLabel;
  const _BookingBar({required this.price, required this.priceSuffix, required this.buttonLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(price, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                Text(priceSuffix, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
                title: Text('$buttonLabel confirmed', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
                content: Text('$price ($priceSuffix) has been added to your trip.',
                    textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textGrey)),
                actions: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).maybePop();
                      },
                      child: const Text('Done', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            child: Text(buttonLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
