import 'package:flutter/material.dart';

import '../../controllers/community_controller.dart';
import '../../theme.dart';

// ---------------------------------------------------------------------
// Create Post ("Community Post" / "Itinerary Post" compose form)
// ---------------------------------------------------------------------
class CreatePostPage extends StatefulWidget {
  final String? itineraryTitle;
  const CreatePostPage({super.key, this.itineraryTitle});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final CreatePostController controller = CreatePostController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final error = await controller.publish(itineraryTitle: widget.itineraryTitle);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your post has been published!')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isItinerary = widget.itineraryTitle != null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: VoyaAppBar(
        title: Text(isItinerary ? 'Itinerary Post' : 'Community Post',
            style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (isItinerary) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.map_outlined, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Linked itinerary: ${widget.itineraryTitle}',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _label('Title'),
                  const SizedBox(height: 8),
                  _textField(controller.titleController, maxLength: 100),
                  const SizedBox(height: 16),
                  _label('Description'),
                  const SizedBox(height: 8),
                  _textField(controller.descController, maxLength: 500, lines: 4),
                  const SizedBox(height: 16),
                  _label('Upload Media'),
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
                                Text('1 photo added — tap to remove', style: TextStyle(fontSize: 12.5, color: AppColors.navy)),
                              ],
                            )
                          : const Icon(Icons.file_upload_outlined, color: AppColors.textGrey),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('More Options', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 4),
                  _switchRow('Allow comments', controller.allowComments, controller.setAllowComments),
                  _switchRow('Allow others to share', controller.allowShare, controller.setAllowShare),
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
                  onPressed: controller.publishing ? null : _publish,
                  child: controller.publishing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Text('Publish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black));

  Widget _textField(TextEditingController ctrl, {required int maxLength, int lines = 1}) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFECECEC)));
    return TextField(
      controller: ctrl,
      maxLines: lines,
      maxLength: maxLength,
      onChanged: (_) => controller.refresh(),
      decoration: InputDecoration(
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.primary)),
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13.5, color: Colors.black)),
          Switch(value: value, activeColor: AppColors.primary, onChanged: onChanged),
        ],
      ),
    );
  }
}
