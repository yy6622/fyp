import 'package:flutter/material.dart';

import '../../controllers/profile_controller.dart';
import '../../theme.dart';
import 'blocked_users_page.dart';
import 'sub_page_scaffold.dart';

// ---------------------------------------------------------------------
// Chat Setting
// ---------------------------------------------------------------------
class ChatSettingPage extends StatefulWidget {
  const ChatSettingPage({super.key});

  @override
  State<ChatSettingPage> createState() => _ChatSettingPageState();
}

class _ChatSettingPageState extends State<ChatSettingPage> {
  final ChatSettingController controller = ChatSettingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SubPageScaffold(
      title: 'Chat Setting',
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          children: [
            profileNavRow('Auto Download Media', 'Wifi Only'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E4)))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Save Media to Gallery', style: TextStyle(fontSize: 14, color: Colors.black)),
                  Switch(value: controller.saveMedia, activeColor: AppColors.primary, onChanged: controller.setSaveMedia),
                ],
              ),
            ),
            profileNavRow('Blocked Users', '2', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BlockedUsersPage()))),
          ],
        ),
      ),
    );
  }
}
