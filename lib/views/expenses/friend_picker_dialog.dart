import 'package:flutter/material.dart';

import '../../repositories/trip_repository.dart';
import '../../theme.dart';

/// Picks which of the trip's real members an itemized receipt line is
/// split between.
class FriendPickerDialog extends StatefulWidget {
  final Trip trip;
  final Set<String> initialSelectedUids;
  final ValueChanged<Set<String>> onConfirm;
  const FriendPickerDialog({super.key, required this.trip, required this.initialSelectedUids, required this.onConfirm});

  @override
  State<FriendPickerDialog> createState() => _FriendPickerDialogState();
}

class _FriendPickerDialogState extends State<FriendPickerDialog> {
  late Set<String> selected = {...widget.initialSelectedUids};

  @override
  Widget build(BuildContext context) {
    final members = widget.trip.memberNames.entries.toList();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Selected (${selected.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            SizedBox(
              height: 260,
              child: ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, i) {
                  final uid = members[i].key;
                  final checked = selected.contains(uid);
                  return CheckboxListTile(
                    value: checked,
                    activeColor: Colors.green,
                    secondary: const CircleAvatar(radius: 16, backgroundColor: Color(0xFFFDFDE0)),
                    title: Text(members[i].value, style: const TextStyle(fontSize: 13)),
                    onChanged: (v) => setState(() => v! ? selected.add(uid) : selected.remove(uid)),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  widget.onConfirm(selected);
                  Navigator.of(context).pop();
                },
                child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
