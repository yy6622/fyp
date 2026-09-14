import 'package:flutter/material.dart';

import '../../controllers/profile_controller.dart';
import '../../repositories/friends_repository.dart';
import '../../theme.dart';
import 'sub_page_scaffold.dart';

// ---------------------------------------------------------------------
// Blocked Users
// ---------------------------------------------------------------------
class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final BlockedUsersController controller = BlockedUsersController();

  Future<void> _unblock(FriendEntry friend) async {
    await controller.unblock(friend);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${friend.name} has been unblocked')));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SubPageScaffold(
      title: 'Blocked Users',
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.blocked.isEmpty) {
            return const Center(child: Text('No blocked users', style: TextStyle(color: AppColors.textGrey)));
          }
          return ListView.separated(
            itemCount: controller.blocked.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE4E4E4)),
            itemBuilder: (context, i) {
              final friend = controller.blocked[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 20, backgroundColor: Color(0xFFD9D9D9)),
                    const SizedBox(width: 14),
                    Expanded(child: Text(friend.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black))),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () => _unblock(friend),
                      child: const Text('Unblock', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
