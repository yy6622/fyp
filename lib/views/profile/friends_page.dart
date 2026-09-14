import 'package:flutter/material.dart';

import '../../controllers/profile_controller.dart';
import '../../repositories/friends_repository.dart';
import '../../theme.dart';

// ---------------------------------------------------------------------
// Friends — a plain friends list with block/unblock, not a chat version.
// ---------------------------------------------------------------------
class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final FriendsController controller = FriendsController();

  @override
  void initState() {
    super.initState();
    controller.search.addListener(controller.refreshSearch);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _toggleBlock(FriendEntry friend) async {
    final nowBlocked = await controller.toggleBlock(friend);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(nowBlocked ? '${friend.name} has been blocked' : '${friend.name} has been unblocked')),
    );
  }

  void _openAddFriend() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Friend', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Username or email',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                filled: true,
                fillColor: AppColors.chipGrey,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final value = ctrl.text.trim();
                  Navigator.of(ctx).pop();
                  if (value.isEmpty) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a username or email first')),
                    );
                    return;
                  }
                  final matchedName = await controller.addFriend(value);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(matchedName != null
                          ? 'You and $matchedName are now friends'
                          : 'No Voya user found for "$value"'),
                    ),
                  );
                },
                child: const Text('Send Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Friends', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final visible = controller.visible;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(24)),
                  child: TextField(
                    controller: controller.search,
                    decoration: const InputDecoration(
                      hintText: 'Search friends',
                      hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      prefixIcon: Icon(Icons.search, color: AppColors.textGrey, size: 20),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? const Center(child: Text('No friends yet — add one below', style: TextStyle(color: AppColors.textGrey)))
                    : ListView.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE4E4E4)),
                        itemBuilder: (context, i) {
                          final friend = visible[i];
                          final blocked = controller.isBlocked(friend.uid);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Row(
                              children: [
                                const CircleAvatar(radius: 20, backgroundColor: Color(0xFFD9D9D9)),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(friend.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
                                ),
                                GestureDetector(
                                  onTap: () => _toggleBlock(friend),
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: blocked ? Colors.redAccent : const Color(0xFFD9D9D9)),
                                    ),
                                    child: Icon(
                                      Icons.block,
                                      size: 16,
                                      color: blocked ? Colors.redAccent : AppColors.textGrey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _openAddFriend,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
