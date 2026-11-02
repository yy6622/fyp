import 'package:flutter/material.dart';

import '../../controllers/profile_controller.dart';
import '../../theme.dart';
import '../shared/nice_dialog.dart';
import 'blocked_users_page.dart';
import 'sub_page_scaffold.dart';

class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  final PrivacySecurityController controller = PrivacySecurityController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SubPageScaffold(
      title: 'Privacy and Security',
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          children: [
            _switchTile('Public Profile', 'Let other travellers find and follow you', controller.profileVisible,
                controller.setProfileVisible),
            _switchTile('Share Location with Group', 'Group members can see your live location during a trip',
                controller.shareLocation, controller.setShareLocation),
            _infoTile(
              'Two-step Verification',
              'Always on. A 6-digit code is emailed when you sign in on a new device (trusted for 30 days), '
                  'make a payment, or change your password, email or account.',
            ),
            profileNavRow('Sign Out of Trusted Devices', '', onTap: _forgetDevices),
            profileNavRow('Blocked Users', '', onTap: () => _push(const BlockedUsersPage())),
          ],
        ),
      ),
    );
  }

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  Future<void> _forgetDevices() async {
    final ok = await showNiceConfirmDialog(
      context: context,
      title: 'Sign Out of Trusted Devices',
      message: 'Every phone, including this one, will need a new email code at the next sign-in. Continue?',
      confirmLabel: 'Continue',
      icon: Icons.phonelink_lock_outlined,
    );
    if (!ok || !mounted) return;
    final n = await controller.forgetTrustedDevices();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed $n trusted device(s).')));
  }

  Widget _infoTile(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.black)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.black)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
              ],
            ),
          ),
          Switch(value: value, activeColor: AppColors.primary, onChanged: onChanged),
        ],
      ),
    );
  }
}
