import 'package:flutter/material.dart';

import '../../controllers/vote_controller.dart';
import '../../theme.dart';
import '../shared/nice_pickers.dart';
import 'saved_item_picker_sheet.dart';

// ---------------------------------------------------------------------
// Create Vote
// ---------------------------------------------------------------------
class CreateVotePage extends StatefulWidget {
  final String tripId;
  const CreateVotePage({super.key, required this.tripId});

  @override
  State<CreateVotePage> createState() => _CreateVotePageState();
}

class _CreateVotePageState extends State<CreateVotePage> {
  late final CreateVoteController controller = CreateVoteController(tripId: widget.tripId);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _addFromSaved() async {
    final picked = await showSavedItemPicker(context, tripId: widget.tripId, alreadyAdded: controller.savedDedupeKeys);
    if (picked == null || picked.isEmpty || !mounted) return;
    controller.addOptions(picked);
  }

  Future<void> _submit() async {
    final ok = await controller.create();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).maybePop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.lastError ?? 'Add a title and at least 2 options first')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Create Vote', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('Title', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 8),
                  _boxField(controller.titleController, hint: 'e.g. Which hotel should we book?'),
                  const SizedBox(height: 20),
                  const Text('Add Options', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 8),
                  ...controller.optionDrafts.asMap().entries.map(
                        (e) => e.value.isSaved ? _savedOptionCard(e.key, e.value) : _optionRow(e.key, e.value.textController!),
                      ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: Color(0xFFECECEC)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: controller.addOption,
                          icon: const Icon(Icons.add, color: AppColors.primary, size: 18),
                          label: const Text('Type Option', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: Color(0xFFECECEC)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _addFromSaved,
                          icon: const Icon(Icons.bookmark_outline, color: AppColors.primary, size: 18),
                          label: const Text('From Saved', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _switchRow('Allow members to add options', controller.allowAddOptions, controller.setAllowAddOptions),
                  _switchRow('Allow multiple choice', controller.allowMultipleChoice, controller.setAllowMultipleChoice),
                  const SizedBox(height: 12),
                  const Text('Deadline (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 8),
                  _deadlineField(),
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
                  onPressed: controller.saving ? null : _submit,
                  child: Text(controller.saving ? 'Creating...' : 'Create Vote',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deadlineField() {
    final deadline = controller.deadline;
    return InkWell(
      onTap: _pickDeadline,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.event_outlined, size: 18, color: AppColors.textGrey),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                deadline == null ? 'No deadline — tap to set one' : _formatDeadline(deadline),
                style: TextStyle(fontSize: 12.5, color: deadline == null ? AppColors.textGrey : Colors.black),
              ),
            ),
            if (deadline != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.textGrey),
                onPressed: () => controller.setDeadline(null),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDeadline(DateTime d) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final period = d.hour < 12 ? 'AM' : 'PM';
    return 'Closes ${d.day} ${months[d.month]}, $hour12:${d.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showVoyaDatePicker(
      context: context,
      initialDate: controller.deadline ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      title: 'Vote Deadline',
    );
    if (date == null || !mounted) return;
    final initialTime = controller.deadline != null
        ? TimeOfDay(hour: controller.deadline!.hour, minute: controller.deadline!.minute)
        : const TimeOfDay(hour: 23, minute: 59);
    final time = await showVoyaTimePicker(context: context, initialTime: initialTime, title: 'Deadline Time');
    if (time == null) return;
    controller.setDeadline(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Widget _boxField(TextEditingController textController, {required String hint}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: textController,
        decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textGrey), border: InputBorder.none),
      ),
    );
  }

  Widget _optionRow(int index, TextEditingController optionController) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: optionController,
              decoration: InputDecoration(
                hintText: 'Option ${index + 1}',
                hintStyle: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 12.5, color: Colors.black),
            ),
          ),
          if (controller.optionDrafts.length > 2)
            IconButton(
              icon: const Icon(Icons.cancel_outlined, size: 20, color: AppColors.textGrey),
              onPressed: () => controller.removeOptionAt(index),
            ),
        ],
      ),
    );
  }

  /// An option picked "From Saved" — shown as a small card (thumbnail,
  /// name, subtitle, rating) instead of a plain text field, same idea as
  /// the picker sheet's own rows and the Vote tab's option cards, so a
  /// saved pick looks like the real listing it is from the moment it's
  /// added, not just a name. Read-only (there's a real catalog item
  /// behind it, nothing to type) — the only action is removing it.
  Widget _savedOptionCard(int index, VoteOptionDraft draft) {
    final item = draft.saved!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 40,
              height: 40,
              color: AppColors.chipGrey,
              child: item.imageUrl.isEmpty
                  ? Icon(item.fallbackIcon, size: 18, color: AppColors.textGrey)
                  : Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(item.fallbackIcon, size: 18, color: AppColors.textGrey),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black)),
                if (item.subtitle.isNotEmpty || item.rating.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (item.rating.isNotEmpty) ...[
                        const Icon(Icons.star, size: 11, color: AppColors.orange),
                        const SizedBox(width: 2),
                        Text(item.rating, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
                        if (item.subtitle.isNotEmpty) const SizedBox(width: 6),
                      ],
                      if (item.subtitle.isNotEmpty)
                        Expanded(
                          child: Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (controller.optionDrafts.length > 2)
            IconButton(
              icon: const Icon(Icons.cancel_outlined, size: 20, color: AppColors.textGrey),
              onPressed: () => controller.removeOptionAt(index),
            ),
        ],
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black))),
          Switch(value: value, activeColor: AppColors.primary, onChanged: onChanged),
        ],
      ),
    );
  }
}
