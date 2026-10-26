import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/group_settings_controller.dart';
import '../../services/itinerary_export_service.dart';
import '../../theme.dart';

// ---------------------------------------------------------------------
// Export Itinerary — real PDF/Image export from the trip's actual plan,
// flights, hotels and expenses (ItineraryExportService). Used to just
// show a fake "Itinerary exported as PDF" SnackBar with nothing behind
// it — see ExportItineraryController's old doc comment.
// ---------------------------------------------------------------------
class ExportItineraryPage extends StatefulWidget {
  final String tripId;
  const ExportItineraryPage({super.key, required this.tripId});

  @override
  State<ExportItineraryPage> createState() => _ExportItineraryPageState();
}

class _ExportItineraryPageState extends State<ExportItineraryPage> {
  late final ExportItineraryController controller = ExportItineraryController(tripId: widget.tripId);
  bool _exporting = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final trip = controller.trip;
    if (trip == null) return;
    setState(() => _exporting = true);
    try {
      final bytes = await ItineraryExportService.buildItineraryPdf(trip: trip, expenses: controller.expenses);
      final fileName = 'Itinerary-${trip.name.isEmpty ? 'Trip' : trip.name}'.replaceAll(RegExp(r'[^A-Za-z0-9\-]+'), '_');
      if (controller.format == 'PDF') {
        await Printing.layoutPdf(onLayout: (format) async => bytes, name: '$fileName.pdf');
      } else {
        // "Image" — rasterise every page of the same PDF content to PNG
        // and hand them to the OS share sheet, rather than claiming an
        // "Image" export when it's really just the PDF again.
        final pages = await Printing.raster(bytes, dpi: 150).toList();
        final files = [
          for (var i = 0; i < pages.length; i++)
            XFile.fromData(await pages[i].toPng(), mimeType: 'image/png', name: '$fileName-page${i + 1}.png'),
        ];
        await SharePlus.instance.share(ShareParams(files: files, subject: fileName));
      }
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not export the itinerary: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
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
                  onPressed: (controller.trip == null || _exporting) ? null : _export,
                  child: _exporting
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Export', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
