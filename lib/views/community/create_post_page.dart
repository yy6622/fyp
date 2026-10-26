import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/community_controller.dart';
import '../../models/community_models.dart';
import '../../repositories/trip_repository.dart';
import '../../theme.dart';

// ---------------------------------------------------------------------
// Create Post ("Community Post" / "Itinerary Post" compose form) — also
// reused as the Edit Post form (FR62): pass [editingPost] and this same
// page pre-fills from it and saves in place instead of publishing a new
// post. See CreatePostController's editingPostId/editingPost.
//
// [itineraryTrip] (FR31/FR68) is the signed-in person's own REAL trip
// being shared — previously this took a plain [String] title looked up
// in a hardcoded two-entry mock list, so every "Itinerary Post" on
// Community was actually one of those two fake sample trips regardless
// of what the person had actually planned. See ItinerarySelectController.
// ---------------------------------------------------------------------
class CreatePostPage extends StatefulWidget {
  final Trip? itineraryTrip;
  final CommunityPost? editingPost;
  const CreatePostPage({super.key, this.itineraryTrip, this.editingPost});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  late final CreatePostController controller =
      CreatePostController(editingPostId: widget.editingPost?.id, editingPost: widget.editingPost);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final error = await controller.publish(itineraryTrip: widget.itineraryTrip);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (controller.isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your post has been updated.')));
      Navigator.of(context).pop();
      return;
    }
    // Content moderation (see CommunityRepository.createPost) may have
    // auto-flagged this post for review instead of publishing it live —
    // controller.lastPublishWasFlagged tells us which message is true.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(controller.lastPublishWasFlagged
          ? "Your post was submitted and is pending review before it appears publicly."
          : 'Your post has been published!'),
    ));
    Navigator.of(context).pop();
  }

  /// FR65 — "AI summary when sharing". Only offered for an Itinerary
  /// Post; there's nothing to summarise when there's no attached trip.
  Future<void> _generateAiSummary() async {
    final trip = widget.itineraryTrip;
    if (trip == null) return;
    final message = await controller.generateAiSummary(trip);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// FR61 — the single photo/video attachment, now a real picker instead
  /// of a bare toggle (see CreatePostController.pickMedia).
  Future<void> _pickMedia() async {
    if (controller.mediaAdded) {
      controller.removeMedia();
      return;
    }
    final choice = await showModalBottomSheet<({ImageSource source, bool video})>(
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
              onTap: () => Navigator.of(ctx).pop((source: ImageSource.camera, video: false)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Choose a Photo'),
              onTap: () => Navigator.of(ctx).pop((source: ImageSource.gallery, video: false)),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined, color: AppColors.primary),
              title: const Text('Record a Video'),
              onTap: () => Navigator.of(ctx).pop((source: ImageSource.camera, video: true)),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined, color: AppColors.primary),
              title: const Text('Choose a Video'),
              onTap: () => Navigator.of(ctx).pop((source: ImageSource.gallery, video: true)),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final error = await controller.pickMedia(choice.source, video: choice.video);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isItinerary = widget.itineraryTrip != null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: VoyaAppBar(
        title: Text(controller.isEditing ? 'Edit Post' : (isItinerary ? 'Itinerary Post' : 'Community Post'),
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
                            child: Text('Linked itinerary: ${widget.itineraryTrip!.name}',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _label('Description'),
                      // FR65 — only meaningful with a real itinerary to
                      // summarise.
                      if (isItinerary)
                        GestureDetector(
                          onTap: controller.generatingSummary ? null : _generateAiSummary,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (controller.generatingSummary)
                                const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2))
                              else
                                const Icon(Icons.auto_awesome, size: 15, color: AppColors.primary),
                              const SizedBox(width: 5),
                              const Text('AI Summary', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _textField(controller.descController, maxLength: 500, lines: 4),
                  const SizedBox(height: 16),
                  _label('Tags'),
                  const SizedBox(height: 8),
                  _tagInput(),
                  if (controller.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _tagChips(),
                  ],
                  const SizedBox(height: 16),
                  _label('Upload Media'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickMedia,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFECECEC)),
                        borderRadius: BorderRadius.circular(10),
                        color: controller.mediaAdded ? AppColors.chipGrey : Colors.white,
                      ),
                      alignment: Alignment.center,
                      child: controller.mediaAdded
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(controller.mediaIsVideo ? Icons.videocam : Icons.check_circle, size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  '1 ${controller.mediaIsVideo ? 'video' : 'photo'} added — tap to remove',
                                  style: const TextStyle(fontSize: 12.5, color: AppColors.navy),
                                ),
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
                      : Text(controller.isEditing ? 'Save' : 'Publish',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
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

  /// A plain hashtag text field with an inline "Add" button — pressing it
  /// or hitting enter on the keyboard both call [CreatePostController.
  /// addTagFromInput], which does the trimming/dedup and clears the field
  /// for the next tag.
  Widget _tagInput() {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFECECEC)));
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller.tagInputController,
            onSubmitted: (_) => controller.addTagFromInput(),
            decoration: InputDecoration(
              hintText: 'e.g. foodie, budget, solo',
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.primary)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: controller.addTagFromInput,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }

  /// The author's own added-so-far tag chips, each with a tiny "✕" to
  /// remove it before publishing.
  Widget _tagChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: controller.tags
          .map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('#$tag', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => controller.removeTag(tag),
                      child: const Icon(Icons.close, size: 14, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ))
          .toList(),
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
