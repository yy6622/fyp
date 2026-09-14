import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/profile_controller.dart';
import '../../data/countries.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../services/avatar_service.dart';
import '../../theme.dart';
import 'sub_page_scaffold.dart';

// ---------------------------------------------------------------------
// Account Setting
// ---------------------------------------------------------------------
class AccountSettingPage extends StatefulWidget {
  const AccountSettingPage({super.key});

  @override
  State<AccountSettingPage> createState() => _AccountSettingPageState();
}

class _AccountSettingPageState extends State<AccountSettingPage> {
  final ProfileController controller = ProfileController();
  bool _uploadingAvatar = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _changeAvatar() async {
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
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    final file = await AvatarService.instance.pick(source);
    if (file == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final url = await AvatarService.instance.upload(uid, file);
      await UserRepository.instance.updateProfile(uid, avatarUrl: url);
    } catch (e) {
      // Raw error, not a generic message — need to see whether this is a
      // Storage permission/setup problem or a platform-support problem.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Couldn't upload photo: $e")));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _changeCountry() async {
    final picked = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _PickerSheet<Country>(
        title: 'Country / Region',
        items: kCountries,
        labelOf: (c) => c.name,
        trailingOf: (c) => c.currencyCode,
      ),
    );
    if (picked == null) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    await UserRepository.instance.updateProfile(uid, country: picked.name);
  }

  Future<void> _changeCurrency() async {
    final picked = await showModalBottomSheet<CurrencyOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _PickerSheet<CurrencyOption>(
        title: 'Currency',
        items: kCurrencies,
        labelOf: (c) => c.code,
        trailingOf: (c) => c.symbol,
      ),
    );
    if (picked == null) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    await UserRepository.instance.updateProfile(uid, currencyCode: picked.code);
  }

  Future<void> _editField({required String label, required String current, required String field}) async {
    final ctrl = TextEditingController(text: current == 'Not set' ? '' : current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(label, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey))),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (result == null) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    await UserRepository.instance.updateProfile(uid, name: field == 'name' ? result : null, phone: field == 'phone' ? result : null);
  }

  @override
  Widget build(BuildContext context) {
    return SubPageScaffold(
      title: 'Account Setting',
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final profile = controller.profile;
          final username = profile?.name.isNotEmpty == true ? profile!.name : 'Not set';
          final email = profile?.email ?? (AuthService.instance.currentUser?.email ?? '');
          final phone = (profile?.phone.isNotEmpty ?? false) ? profile!.phone : 'Not set';
          final country = (profile?.country.isNotEmpty ?? false) ? profile!.country : 'Not set';
          final currency = (profile?.currencyCode.isNotEmpty ?? false) ? profile!.currencyCode : 'Not set';
          return ListView(
            children: [
              profileNavRow('Username', username, onTap: () => _editField(label: 'Username', current: username, field: 'name')),
              InkWell(
                onTap: _uploadingAvatar ? null : _changeAvatar,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
                  child: Row(
                    children: [
                      const Text('Avatar', style: TextStyle(fontSize: 14, color: Colors.black)),
                      const Spacer(),
                      if (_uploadingAvatar)
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                      else
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFD9D9D9),
                          backgroundImage: (profile?.avatarUrl.isNotEmpty ?? false) ? NetworkImage(profile!.avatarUrl) : null,
                          child: (profile?.avatarUrl.isNotEmpty ?? false) ? null : const Icon(Icons.person, size: 18, color: AppColors.textGrey),
                        ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 18, color: AppColors.textGrey),
                    ],
                  ),
                ),
              ),
              profileNavRow('Password', '••••••••'),
              profileNavRow('Email', email),
              profileNavRow('Phone Number', phone, onTap: () => _editField(label: 'Phone Number', current: phone, field: 'phone')),
              profileNavRow('Language', 'English'),
              profileNavRow('Country / Region', country, onTap: _changeCountry),
              profileNavRow('Currency', currency, onTap: _changeCurrency),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Delete Account', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
                        content: const Text(
                          'This permanently deletes your account and all your trips. This cannot be undone. Are you sure?',
                          style: TextStyle(color: AppColors.textGrey),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    child: const Text('Delete Account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A plain scrollable pick-one-from-a-list bottom sheet, shared by the
/// Country/Region and Currency rows above — pops the chosen item.
class _PickerSheet<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final String Function(T) labelOf;
  final String Function(T) trailingOf;
  const _PickerSheet({required this.title, required this.items, required this.labelOf, required this.trailingOf});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  return ListTile(
                    title: Text(labelOf(item), style: const TextStyle(fontSize: 13.5)),
                    trailing: Text(trailingOf(item), style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                    onTap: () => Navigator.of(context).pop(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
