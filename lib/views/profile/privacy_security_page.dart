import 'package:flutter/material.dart';

import '../../controllers/profile_controller.dart';
import '../../theme.dart';
import 'sub_page_scaffold.dart';

// ---------------------------------------------------------------------
// Privacy and Security
// ---------------------------------------------------------------------
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
            _switchTile('Two-Factor Authentication', 'Add an extra layer of security when logging in',
                controller.twoFactor, controller.setTwoFactor),
            profileNavRow('Change Password', ''),
            profileNavRow('Download My Data', ''),
          ],
        ),
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
