import 'package:flutter/material.dart';

import '../../controllers/vote_controller.dart';
import '../../theme.dart';

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

  Future<void> _submit() async {
    final ok = await controller.create();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).maybePop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title and at least 2 options first')),
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
                  ...controller.optionControllers.asMap().entries.map((e) => _optionRow(e.key, e.value)),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: Color(0xFFECECEC)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: controller.addOption,
                    icon: const Icon(Icons.add, color: AppColors.primary, size: 18),
                    label: const Text('Add Options', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 20),
                  _switchRow('Allow members to add options', controller.allowAddOptions, controller.setAllowAddOptions),
                  _switchRow('Allow multiple choice', controller.allowMultipleChoice, controller.setAllowMultipleChoice),
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
          if (controller.optionControllers.length > 2)
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
