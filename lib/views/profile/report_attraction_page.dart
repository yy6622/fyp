import 'package:flutter/material.dart';

import '../../controllers/profile_controller.dart';
import '../../theme.dart';
import 'sub_page_scaffold.dart';

// ---------------------------------------------------------------------
// Report New Attraction
// ---------------------------------------------------------------------
class ReportAttractionPage extends StatefulWidget {
  const ReportAttractionPage({super.key});

  @override
  State<ReportAttractionPage> createState() => _ReportAttractionPageState();
}

class _ReportAttractionPageState extends State<ReportAttractionPage> {
  final ReportAttractionController controller = ReportAttractionController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (controller.locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a location first')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks! Your new spot has been reported for review.')));
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return SubPageScaffold(
      title: 'Report New Attraction',
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('Upload Media', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: controller.toggleMediaAdded,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFECECEC)),
                        borderRadius: BorderRadius.circular(10),
                        color: controller.mediaAdded ? AppColors.chipGrey : Colors.white,
                      ),
                      alignment: Alignment.center,
                      child: controller.mediaAdded
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, size: 18, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Photo added — tap to remove', style: TextStyle(fontSize: 12.5, color: AppColors.navy)),
                              ],
                            )
                          : const Icon(Icons.file_upload_outlined, color: AppColors.textGrey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller.locationController,
                    decoration: InputDecoration(
                      hintText: 'Search location',
                      hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
                      suffixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFECECEC))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFECECEC))),
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
                  onPressed: _submit,
                  child: const Text('Export', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
