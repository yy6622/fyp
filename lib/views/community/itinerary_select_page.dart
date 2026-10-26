import 'package:flutter/material.dart';

import '../../controllers/community_controller.dart';
import '../../models/day_plan_models.dart';
import '../../repositories/trip_repository.dart';
import '../../theme.dart';
import 'create_post_page.dart';

// ---------------------------------------------------------------------
// Itinerary Post — select one of your REAL trips to turn into a post
// (FR31/FR68). Used to offer two hardcoded sample itineraries
// ("Japan Trips"/"Korea Trips") regardless of what trips the signed-in
// person actually had — see ItinerarySelectController.
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
      MaterialPageRoute(builder: (_) => CreatePostPage(itineraryTrip: controller.selectedTrip)),
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
        builder: (context, _) {
          if (controller.loading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (controller.trips.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "You don't have any trips yet — plan one first, then come back here to share it.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                ),
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text('Select an itinerary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
                    const SizedBox(height: 14),
                    ...List.generate(controller.trips.length, (i) => _itineraryTile(i)),
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
          );
        },
      ),
    );
  }

  Widget _itineraryTile(int index) {
    final trip = controller.trips[index];
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
                      child: trip.coverImage.isEmpty
                          ? Container(width: 40, height: 40, color: AppColors.chipGrey, child: const Icon(Icons.map_outlined, size: 18, color: AppColors.textGrey))
                          : Image.network(trip.coverImage, width: 40, height: 40, fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(width: 40, height: 40, color: AppColors.chipGrey)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(trip.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
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
                  children: List.generate(trip.days.length, (dayIdx) => _dayRow(index, dayIdx, trip.days[dayIdx])),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dayRow(int tileIndex, int dayIdx, DayPlan day) {
    final dayExpanded = controller.expandedDayFor(tileIndex) == dayIdx;
    final lines = [for (final item in day.items) '${item.time}  ${item.label}'];
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
                child: lines.isEmpty
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No activities planned yet', style: TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: lines
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
