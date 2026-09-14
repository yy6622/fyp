import 'package:flutter/material.dart';

import 'theme.dart';

class NearByPage extends StatefulWidget {
  const NearByPage({super.key});

  @override
  State<NearByPage> createState() => _NearByPageState();
}

class _NearByPageState extends State<NearByPage> {
  String _selectedCategory = 'Restaurants';

  static const _categories = [
    ('Restaurants', Icons.restaurant_outlined),
    ('Cafes', Icons.local_cafe_outlined),
    ('Attractions', Icons.attractions_outlined),
    ('Shopping', Icons.shopping_bag_outlined),
    ('ATM', Icons.local_atm_outlined),
    ('Pharmacy', Icons.local_pharmacy_outlined),
  ];

  final List<_NearbyPlace> _places = const [
    _NearbyPlace(name: 'Ichiran Ramen', category: 'Japanese • Ramen', rating: '4.7', distance: '250 m'),
    _NearbyPlace(name: 'Sushi Dai', category: 'Japanese • Sushi', rating: '4.9', distance: '400 m'),
    _NearbyPlace(name: 'Ippudo', category: 'Japanese • Ramen', rating: '4.6', distance: '650 m'),
    _NearbyPlace(name: 'Gyukatsu Motomura', category: 'Japanese • Beef Cutlet', rating: '4.8', distance: '900 m'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Text('Near By', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
                ],
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final (label, icon) = _categories[i];
                  final selected = label == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = label),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.chipGrey,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(icon, size: 15, color: selected ? Colors.white : AppColors.textGrey),
                          const SizedBox(width: 6),
                          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textGrey)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(height: 170, child: CustomPaint(painter: _MapPainter(), size: Size.infinite)),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: _places.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _placeCard(_places[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeCard(_NearbyPlace place) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 4),
                Text(place.category, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 13, color: AppColors.orange),
                    const SizedBox(width: 4),
                    Text(place.rating, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.near_me_outlined, size: 14, color: AppColors.primary),
              const SizedBox(height: 4),
              Text(place.distance, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NearbyPlace {
  final String name, category, rating, distance;
  const _NearbyPlace({required this.name, required this.category, required this.rating, required this.distance});
}

/// A lightweight stand-in "map" — colored blocks + pins — since there's no
/// maps SDK wired into this project yet.
class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFFE8ECEE));
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6;
    canvas.drawLine(Offset(0, size.height * 0.35), Offset(size.width, size.height * 0.3), roadPaint);
    canvas.drawLine(Offset(size.width * 0.4, 0), Offset(size.width * 0.55, size.height), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.8), roadPaint);

    final pins = [
      Offset(size.width * 0.3, size.height * 0.3),
      Offset(size.width * 0.55, size.height * 0.5),
      Offset(size.width * 0.7, size.height * 0.25),
      Offset(size.width * 0.2, size.height * 0.65),
      Offset(size.width * 0.8, size.height * 0.7),
    ];
    final colors = [Colors.redAccent, Colors.orange, Colors.blue, Colors.green, Colors.purple];
    for (var i = 0; i < pins.length; i++) {
      canvas.drawCircle(pins[i], 8, Paint()..color = colors[i % colors.length]);
      canvas.drawCircle(pins[i], 8, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      9,
      Paint()..color = AppColors.primary,
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      9,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
