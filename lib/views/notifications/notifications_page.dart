import 'package:flutter/material.dart';

import '../../controllers/notifications_controller.dart';
import '../../repositories/notifications_repository.dart';
import '../../services/format_utils.dart';
import '../../theme.dart';

// ---------------------------------------------------------------------
// Notifications — real inbox behind the Home bell icon (previously just
// showed "No new notifications" with nothing behind it). A friend request
// is the one actionable type today: Accept/Decline right from the list.
// ---------------------------------------------------------------------
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationsController controller = NotificationsController();

  // Prevents a double-tap on Accept/Decline from firing the batch write
  // twice while the first call is still in flight.
  final Set<String> _busy = {};

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _respond(AppNotification n, {required bool accept}) async {
    if (_busy.contains(n.id)) return;
    setState(() => _busy.add(n.id));
    try {
      final message = await controller.respondToFriendRequest(n, accept: accept);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy.remove(n.id));
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'friend_request':
        return Icons.person_add_alt_1_outlined;
      case 'friend_request_accepted':
        return Icons.people_alt_outlined;
      case 'trip_activity_added':
      case 'trip_activity_removed':
        return Icons.map_outlined;
      case 'trip_flight_added':
        return Icons.flight_outlined;
      case 'trip_hotel_added':
        return Icons.hotel_outlined;
      case 'trip_insurance_added':
        return Icons.health_and_safety_outlined;
      case 'trip_settings_updated':
        return Icons.edit_outlined;
      case 'trip_poll_created':
        return Icons.how_to_vote_outlined;
      case 'trip_expense_added':
        return Icons.receipt_long_outlined;
      case 'trip_member_added':
        return Icons.group_add_outlined;
      case 'trip_member_removed':
      case 'trip_member_left':
        return Icons.person_remove_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Notifications', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 19)),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.loading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (controller.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 36, color: AppColors.textGrey),
                    const SizedBox(height: 12),
                    Text(controller.error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textGrey, fontSize: 12.5)),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: controller.retry,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Try again', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            );
          }
          final items = controller.items;
          if (items.isEmpty) {
            return const Center(
              child: Text('No notifications yet', style: TextStyle(color: AppColors.textGrey)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFECECEC)),
            itemBuilder: (context, i) {
              final n = items[i];
              final busy = _busy.contains(n.id);
              return InkWell(
                onTap: n.read ? null : () => controller.markRead(n.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: (n.read ? AppColors.chipGrey : AppColors.primary.withValues(alpha: 0.12)),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(_iconFor(n.type), size: 19, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    n.title,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: n.read ? FontWeight.w600 : FontWeight.bold,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ),
                                if (!n.read)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(left: 6, top: 3),
                                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(n.body, style: const TextStyle(fontSize: 12.5, color: Colors.black87)),
                            const SizedBox(height: 4),
                            Text(
                              n.createdAt == null ? '' : formatTimeAgo(n.createdAt!),
                              style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey),
                            ),
                            if (n.type == 'friend_request') ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFFD9D9D9)),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: busy ? null : () => _respond(n, accept: false),
                                      child: const Text('Decline', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w600, fontSize: 12.5)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: busy ? null : () => _respond(n, accept: true),
                                      child: busy
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (n.type != 'friend_request')
                        GestureDetector(
                          onTap: () => controller.dismiss(n.id),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 8, top: 2),
                            child: Icon(Icons.close, size: 16, color: AppColors.textGrey),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
