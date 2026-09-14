import 'package:flutter/material.dart';

import '../../controllers/community_controller.dart';
import '../../models/community_models.dart';
import '../../theme.dart';
import 'create_post_page.dart';

// ---------------------------------------------------------------------
// Itinerary Post — select one of your plans to turn into a post
// ---------------------------------------------------------------------
class ItinerarySelectPage extends StatefulWidget {
  const ItinerarySelectPage({super.key});

  @override
  State<ItinerarySelectPage> createState() => _ItinerarySelectPageState();
}

class _ItinerarySelectPageState extends State<ItinerarySelectPage> {
  final ItinerarySelectController controller = ItinerarySelectController();

  void _continue() {
    if (controller.selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an itinerary to continue')));
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => CreatePostPage(itineraryTitle: myItineraries[controller.selected!].title)),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Itinerary Post', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('Select an itinerary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 14),
                  ...List.generate(myItineraries.length, (i) => _itineraryTile(i)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _continue,
                  child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itineraryTile(int index) {
    final item = myItineraries[index];
    final expanded = controller.expanded == index;
    final selected = controller.selected == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary : const Color(0xFFECECEC), width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => controller.select(index),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(item.image, width: 40, height: 40, fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(width: 40, height: 40, color: AppColors.chipGrey)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    ),
                    Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.textGrey),
                  ],
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  children: List.generate(item.days.length, (dayIdx) => _dayRow(index, dayIdx, item.days[dayIdx])),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dayRow(int tileIndex, int dayIdx, List<String> items) {
    final dayExpanded = controller.expandedDayFor(tileIndex) == dayIdx;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            InkWell(
              onTap: () => controller.setExpandedDay(tileIndex, dayIdx),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Day ${dayIdx + 1}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    ),
                    Icon(dayExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: AppColors.textGrey),
                  ],
                ),
              ),
            ),
            if (dayExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: items.isEmpty
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No activities planned yet', style: TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: items
                            .map((line) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Text(line, style: const TextStyle(fontSize: 11.5, color: Color(0xFF0015FF))),
                                ))
                            .toList(),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
