import 'package:flutter/material.dart';

import '../../theme.dart';
import 'detail_widgets.dart';

// ---------------------------------------------------------------------
// Full review list — reached via "View All" from a Reviews preview
// section (Hotel/Restaurant detail pages show only the top 3 there).
// ---------------------------------------------------------------------
class AllReviewsPage extends StatelessWidget {
  final String title;
  final String ratingSummary;
  const AllReviewsPage({super.key, required this.title, required this.ratingSummary});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Reviews', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.star, size: 16, color: AppColors.orange),
              const SizedBox(width: 4),
              Text(ratingSummary, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFECECEC)),
          const SizedBox(height: 16),
          ...kSampleReviews.expand((r) => [ReviewCard(data: r), const SizedBox(height: 12)]),
        ],
      ),
    );
  }
}
