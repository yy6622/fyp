import 'package:flutter/material.dart';

import '../../controllers/group_settings_controller.dart';
import '../../theme.dart';

// ---------------------------------------------------------------------
// Group Setting
// ---------------------------------------------------------------------
class GroupSettingPage extends StatefulWidget {
  final String tripId;
  const GroupSettingPage({super.key, required this.tripId});

  @override
  State<GroupSettingPage> createState() => _GroupSettingPageState();
}

class _GroupSettingPageState extends State<GroupSettingPage> {
  late final GroupSettingController controller = GroupSettingController(tripId: widget.tripId);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Group Setting', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _navRow('Group Name', controller.trip?.name ?? '', onTap: () => _editField('Group Name', controller.nameController, controller.saveName)),
            _photoRow(),
            _navRow('Group About', controller.trip?.about ?? '',
                onTap: () => _editField('Group About', controller.aboutController, controller.saveAbout)),
            _navRow('Notification', 'All Message'),
            _switchRow('Mute Chat', controller.muteChat, controller.setMuteChat),
            _switchRow('Pin Chat', controller.pinChat, controller.setPinChat),
            _switchRow('Real-Time Location', controller.realTimeLocation, controller.setRealTimeLocation),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _confirmLeaveGroup(context),
                child: const Text('Leave Group', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editField(String label, TextEditingController fieldController, Future<void> Function(String) onSave) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit $label', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
        content: TextField(controller: fieldController, autofocus: true, maxLines: label == 'Group About' ? 3 : 1),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              onSave(fieldController.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveGroup(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Group', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
        content: const Text(
          "Are you sure you want to leave this group? You'll lose access to its plan, chat and expenses.",
          style: TextStyle(color: AppColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await controller.leaveGroup();
              if (!context.mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('You have left the group')),
              );
            },
            child: const Text('Leave', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _navRow(String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13.5, color: Colors.black)),
            const Spacer(),
            Flexible(
              child: Text(value, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            ),
            if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }

  Widget _photoRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
      child: Row(
        children: [
          const Text('Group Photo', style: TextStyle(fontSize: 13.5, color: Colors.black)),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: AppImage('assets/images/adventure_bg.jpg', width: 36, height: 36, fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
        ],
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
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
