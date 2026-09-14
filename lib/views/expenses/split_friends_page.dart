import 'package:flutter/material.dart';

import '../../controllers/expenses_controller.dart';
import '../../theme.dart';

/// Full-page member checklist for "Split Method: Equally" — picks which of
/// the trip's real members [AddExpenseController.selectedUids] the amount
/// is split between.
class SplitFriendsPage extends StatefulWidget {
  final AddExpenseController controller;
  const SplitFriendsPage({super.key, required this.controller});

  @override
  State<SplitFriendsPage> createState() => _SplitFriendsPageState();
}

class _SplitFriendsPageState extends State<SplitFriendsPage> {
  late Set<String> selected = {...widget.controller.selectedUids};

  @override
  Widget build(BuildContext context) {
    final members = widget.controller.trip.memberNames.entries.toList();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Split With', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: members.length,
              itemBuilder: (context, i) {
                final uid = members[i].key;
                final checked = selected.contains(uid);
                return CheckboxListTile(
                  value: checked,
                  activeColor: AppColors.primary,
                  controlAffinity: ListTileControlAffinity.trailing,
                  secondary: const CircleAvatar(radius: 18, backgroundColor: Color(0xFFD9D9D9)),
                  title: Text(members[i].value, style: const TextStyle(fontSize: 14, color: Colors.black)),
                  onChanged: (v) => setState(() => v! ? selected.add(uid) : selected.remove(uid)),
                );
              },
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
                onPressed: () {
                  widget.controller.setSelectedUids(selected);
                  Navigator.of(context).maybePop();
                },
                child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
