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

  // Names currently mid-resend, so the button can show a spinner and
  // can't be double-tapped while the write/notification is in flight.
  final Set<String> _resending = {};

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

  Future<void> _resend(SentFriendRequest request) async {
    setState(() => _resending.add(request.toUid));
    await controller.resendRequest(request);
    if (!mounted) return;
    setState(() => _resending.remove(request.toUid));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Friend request resent to ${request.toName}')),
    );
  }

  Future<void> _cancel(SentFriendRequest request) async {
    await controller.cancelRequest(request);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Friend request to ${request.toName} cancelled')),
    );
  }

  String _outcomeMessage(FriendRequestOutcome outcome, String query) {
    switch (outcome.status) {
      case FriendRequestStatus.sent:
        // Directly says the request is waiting on the other person, not
        // just "sent" — a persistent "Pending" row below also shows this
        // for as long as it's outstanding, not just in this one snackbar.
        return 'Friend request sent to ${outcome.name} — waiting for them to accept';
      case FriendRequestStatus.autoAccepted:
        return '${outcome.name} had already requested you — you\'re now friends';
      case FriendRequestStatus.alreadyFriends:
        return 'You and ${outcome.name} are already friends';
      case FriendRequestStatus.alreadyRequested:
        return 'Friend request to ${outcome.name} is already pending';
      case FriendRequestStatus.isSelf:
        return "That's your own account";
      case FriendRequestStatus.noMatch:
        return 'No Voya user found for "$query"';
    }
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
                  final outcome = await controller.sendFriendRequest(value);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_outcomeMessage(outcome, value))),
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

  Widget _pendingSection(List<SentFriendRequest> sent) {
    if (sent.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Pending (${sent.length})',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textGrey),
            ),
          ),
          for (final request in sent)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
              child: Row(
                children: [
                  UserAvatar(uid: request.toUid, radius: 16, backgroundColor: const Color(0xFFD9D9D9)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(request.toName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
                        const Text('Pending — waiting for response', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                      ],
                    ),
                  ),
                  _resending.contains(request.toUid)
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : TextButton(
                          onPressed: () => _resend(request),
                          style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8)),
                          child: const Text('Resend', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                        ),
                  IconButton(
                    onPressed: () => _cancel(request),
                    icon: const Icon(Icons.close, size: 18, color: AppColors.textGrey),
                    tooltip: 'Cancel request',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
        ],
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
                // Horizontal 20 matches every friend row below it
                // (Padding(horizontal: 20) in the itemBuilder) — this was
                // 16 before, so the search box sat 4px further left than
                // the list under it.
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(24)),
                  // Icon as a plain Row sibling with a fixed 8px gap —
                  // the same shape every other search bar in the app
                  // uses (Plan, Community, Explore's top bar). This used
                  // to put the search icon on InputDecoration's
                  // `prefixIcon` instead, which gets its own default
                  // 48dp tap-target box and sat with different
                  // spacing/vertical centering than everywhere else —
                  // the actual cause of this search box visibly not
                  // lining up with the rest of the app.
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: AppColors.textGrey, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: controller.search,
                          decoration: const InputDecoration(
                            hintText: 'Search friends',
                            hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _pendingSection(controller.sentRequests),
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
                                UserAvatar(uid: friend.uid, radius: 20, backgroundColor: const Color(0xFFD9D9D9)),
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
