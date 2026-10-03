import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/expenses_controller.dart';
import '../../repositories/trip_repository.dart';
import '../../services/auth_service.dart';
import '../../services/receipt_service.dart';
import '../../theme.dart';
import 'expense_details_form_page.dart';

// ---------------------------------------------------------------------
// Add Expense flow — loads the trip once, then shares one
// [AddExpenseController] across every page in the flow so the amount,
// category and participants chosen on one step are still there on the
// next.
// ---------------------------------------------------------------------
class AddExpenseChoicePage extends StatefulWidget {
  final String tripId;
  const AddExpenseChoicePage({super.key, required this.tripId});

  @override
  State<AddExpenseChoicePage> createState() => _AddExpenseChoicePageState();
}

class _AddExpenseChoicePageState extends State<AddExpenseChoicePage> {
  AddExpenseController? _controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = AuthService.instance.currentUser?.uid ?? '';
    final trip = await TripRepository.instance.watchTrip(widget.tripId, uid).first;
    if (!mounted || trip == null) return;
    setState(() => _controller = AddExpenseController(tripId: widget.tripId, trip: trip));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Add Expenses', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: controller == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                _tile(context, Icons.upload_outlined, 'Upload Receipt', 'Take photo or upload', () => _startUploadReceipt(context, controller)),
                _tile(context, Icons.edit_outlined, 'Manual Entry', 'Enter expenses manually',
                    () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExpenseDetailsFormPage(controller: controller)))),
              ],
            ),
    );
  }

  /// Real photo capture/pick — not decorative. Picks (or takes) a photo,
  /// stashes it on the shared [AddExpenseController] so the Details form
  /// can preview it, then opens that same form (no OCR, so every field
  /// still needs the person's own input; the photo is just kept as a real
  /// reference/receipt of record, uploaded to Storage on submit).
  Future<void> _startUploadReceipt(BuildContext context, AddExpenseController controller) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await ReceiptService.instance.pick(source);
    if (file == null || !context.mounted) return;
    controller.setReceiptImage(file);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExpenseDetailsFormPage(controller: controller)));
  }

  Widget _tile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: const Color(0xFFD9D9D9), borderRadius: BorderRadius.circular(22)),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.navy),
          ],
        ),
      ),
    );
  }
}
