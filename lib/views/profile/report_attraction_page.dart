import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/profile_controller.dart';
import '../../theme.dart';
import 'sub_page_scaffold.dart';

// ---------------------------------------------------------------------
// Report New Attraction — real Firestore-backed submission (see
// ReportAttractionController), with a real camera/gallery photo upload.
// Previously tapping Submit never wrote anything at all: it just showed
// a SnackBar and popped the page, and the button itself was mislabeled
// "Export" (a leftover from somewhere else, not what this button does).
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

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await controller.pickPhoto(source);
  }

  Future<void> _useCurrentLocation() async {
    final error = await controller.useCurrentLocation();
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _submit() async {
    final error = await controller.submit();
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
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
                  const Text('Upload Photo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: controller.mediaAdded ? controller.removePhoto : _pickPhoto,
                    child: Container(
                      height: controller.mediaAdded ? 160 : 56,
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFECECEC)),
                        borderRadius: BorderRadius.circular(10),
                        color: controller.mediaAdded ? AppColors.chipGrey : Colors.white,
                      ),
                      alignment: Alignment.center,
                      child: controller.mediaAdded
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(controller.photo!, fit: BoxFit.cover),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                                  ),
                                ),
                              ],
                            )
                          : const Icon(Icons.file_upload_outlined, color: AppColors.textGrey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Attraction Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 8),
                  _textField(controller.nameController, 'e.g. Batu Caves'),
                  const SizedBox(height: 16),
                  const Text('Location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 8),
                  _textField(
                    controller.locationController,
                    'Search location',
                    icon: Icons.my_location,
                    onIconTap: _useCurrentLocation,
                    iconLoading: controller.locating,
                  ),
                  const SizedBox(height: 16),
                  const Text('Description (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 8),
                  _textField(controller.descriptionController, 'What makes this spot worth visiting?', maxLines: 4),
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
                  onPressed: controller.submitting ? null : _submit,
                  child: controller.submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String hint, {
    IconData? icon,
    int maxLines = 1,
    VoidCallback? onIconTap,
    bool iconLoading = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
        suffixIcon: icon == null
            ? null
            : (iconLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : (onIconTap == null
                    ? Icon(icon, color: AppColors.primary)
                    : IconButton(icon: Icon(icon, color: AppColors.primary), onPressed: onIconTap))),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFECECEC))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFECECEC))),
      ),
    );
  }
}
