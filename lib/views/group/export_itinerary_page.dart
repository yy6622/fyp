import 'package:flutter/material.dart';

import '../../controllers/group_settings_controller.dart';
import '../../theme.dart';

// ---------------------------------------------------------------------
// Export Itinerary
// ---------------------------------------------------------------------
class ExportItineraryPage extends StatefulWidget {
  const ExportItineraryPage({super.key});

  @override
  State<ExportItineraryPage> createState() => _ExportItineraryPageState();
}

class _ExportItineraryPageState extends State<ExportItineraryPage> {
  final ExportItineraryController controller = ExportItineraryController();

  void _export() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Itinerary exported as ${controller.format}')),
    );
    Navigator.of(context).maybePop();
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
        title: Text('Export Itinerary', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('Export format', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _formatChip('PDF', Icons.picture_as_pdf_outlined),
                      const SizedBox(width: 10),
                      _formatChip('Image', Icons.image_outlined),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: AppColors.textGrey),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'The full day-by-day plan, flights, hotels and expenses for this group will be included.',
                            style: TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _export,
                  child: const Text('Export', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formatChip(String label, IconData icon) {
    final selected = controller.format == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.setFormat(label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.chipGrey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : AppColors.textGrey),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textGrey, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}
