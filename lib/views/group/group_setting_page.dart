import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/group_settings_controller.dart';
import '../../services/trip_cover_service.dart';
import '../../theme.dart';
import '../shared/nice_dialog.dart';
import 'travel_preferences_page.dart';

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
            _navRow('Travel Preferences', '', onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => TravelPreferencesPage(tripId: widget.tripId)))),
            _navRow('Notification', controller.notificationOption, onTap: () => _pickNotificationOption()),
            _switchRow('Mute Chat', controller.muteChat, controller.setMuteChat),
            _switchRow('Pin Chat', controller.pinChat, controller.setPinChat),
            _switchRow(
              'Real-Time Location',
              controller.realTimeLocation,
              controller.isOwner ? controller.setRealTimeLocation : null,
              disabledHint: 'Only the trip owner can turn Real-Time Location on or off',
            ),
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

  Future<void> _editField(String label, TextEditingController fieldController, Future<void> Function(String) onSave) async {
    final result = await showNiceFormDialog(
      context: context,
      title: 'Edit $label',
      headerIcon: Icons.edit_outlined,
      confirmLabel: 'Save',
      fieldsBuilder: (ctx, setState) => [
        niceDialogField(fieldController, label, autofocus: true, maxLines: label == 'Group About' ? 3 : 1),
      ],
    );
    if (result == true) {
      await onSave(fieldController.text);
    }
  }

  static const _notificationOptions = ['All Messages', 'Mentions Only', 'None'];

  void _pickNotificationOption() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Notification', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
            ),
            ..._notificationOptions.map((option) {
              final selected = controller.notificationOption == option;
              return ListTile(
                title: Text(option, style: const TextStyle(fontSize: 13.5)),
                trailing: selected ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  controller.setNotificationOption(option);
                  Navigator.of(sheetContext).pop();
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLeaveGroup(BuildContext context) async {
    final confirmed = await showNiceConfirmDialog(
      context: context,
      title: 'Leave Group',
      message: "Are you sure you want to leave this group? You'll lose access to its plan, chat and expenses.",
      confirmLabel: 'Leave',
      icon: Icons.logout,
      destructive: true,
    );
    if (!confirmed) return;
    await controller.leaveGroup();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You have left the group')),
    );
  }

  // [value]'s box is the sole flexible child (an Expanded, not a Spacer +
  // a second competing Flexible) so it always claims the row's entire
  // leftover width and its textAlign:right then actually hugs the right
  // edge next to the chevron — with Spacer()+Flexible() (the old code),
  // the two split that leftover space evenly and the value only reached
  // the edge when it happened to be long enough to fill its half, which
  // is why some rows' values/chevrons lined up flush right and others
  // (short values, or none at all) sat noticeably left of it.
  Widget _navRow(String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13.5, color: Colors.black)),
            const SizedBox(width: 8),
            Expanded(
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
    final url = controller.trip?.coverImage ?? '';
    return InkWell(
      onTap: _changeGroupPhoto,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
        child: Row(
          children: [
            const Text('Group Photo', style: TextStyle(fontSize: 13.5, color: Colors.black)),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: url.isEmpty
                  ? AppImage('assets/images/adventure_bg.jpg', width: 36, height: 36, fit: BoxFit.cover)
                  : Image.network(
                      url,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => AppImage('assets/images/adventure_bg.jpg', width: 36, height: 36, fit: BoxFit.cover),
                    ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }

  Future<void> _changeGroupPhoto() async {
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
    if (source == null) return;
    final file = await TripCoverService.instance.pick(source);
    if (file == null) return;
    try {
      final url = await TripCoverService.instance.upload(widget.tripId, file);
      await controller.saveCoverImage(url);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Couldn't upload photo: $e")));
    }
  }

  /// [onChanged] null means this setting can't be changed by the signed-in
  /// user right now — the [Switch] renders disabled, and [disabledHint], if
  /// given, is shown as a snackbar when they tap the label to ask why.
  Widget _switchRow(String label, bool value, ValueChanged<bool>? onChanged, {String? disabledHint}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onChanged == null && disabledHint != null
                ? () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(disabledHint)))
                : null,
            child: Text(label, style: const TextStyle(fontSize: 13.5, color: Colors.black)),
          ),
          Switch(value: value, activeColor: AppColors.primary, onChanged: onChanged),
        ],
      ),
    );
  }
}
