import 'package:flutter/material.dart';

import '../../repositories/insurance_chat_repository.dart';
import '../../services/auth_service.dart';
import '../../services/format_utils.dart';
import '../../theme.dart';
import 'insurance_chat_page.dart';

/// Every insurance conversation the signed-in traveller has started, across
/// every partner -- the traveller-side counterpart of the partner console's
/// own Messages page (admin_web/partner/messages.html). Reached from the
/// Profile menu, whose "Insurance Messages" row and whose own bottom-nav
/// tab both carry a red dot while [InsuranceChatSummary.unreadForTraveller]
/// is true on any thread here (see MainPage in views/shared/bottom_nav.dart
/// and ProfilePage's own badge wiring).
class InsuranceMessagesPage extends StatelessWidget {
  const InsuranceMessagesPage({super.key});

  String _initialsFor(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    return words.length == 1 ? words.first.substring(0, 1).toUpperCase() : (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VoyaAppBar(
        title: Text('Insurance Messages', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<InsuranceChatSummary>>(
              stream: InsuranceChatRepository.instance.watchChatsForTraveller(uid),
              builder: (context, snap) {
                if (snap.hasError) {
                  // Surfaced instead of leaving the spinner running forever
                  // on a stream failure (e.g. a missing Firestore index) --
                  // see InsuranceChatRepository.watchChatsForTraveller's
                  // doc comment for the bug this previously caused.
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        "Couldn't load your insurance messages. Pull to refresh or try again later.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                      ),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                final chats = snap.data!;
                if (chats.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.mail_outline, size: 40, color: AppColors.textGrey),
                          const SizedBox(height: 12),
                          const Text(
                            'No messages yet',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Chat with an insurance partner from any plan\'s detail page to ask questions before you buy, or about a policy you already have.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: chats.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final c = chats[i];
                    final unread = c.unreadForTraveller;
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => InsuranceChatPage(
                            partnerId: c.partnerId,
                            providerName: c.providerName,
                            planName: c.planName,
                          ),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: unread ? AppColors.primary.withOpacity(0.06) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: unread ? AppColors.primary : const Color(0xFFECECEC)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.navy,
                              child: Text(_initialsFor(c.providerName), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          c.providerName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 13.5, fontWeight: unread ? FontWeight.w800 : FontWeight.w700, color: AppColors.navy),
                                        ),
                                      ),
                                      if (unread) ...[
                                        const SizedBox(width: 6),
                                        Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (c.lastSenderRole == 'traveller' ? 'You: ' : '') +
                                        (c.lastMessage.isEmpty ? (c.planName ?? 'General enquiry') : c.lastMessage),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
                                      color: unread ? AppColors.navy : AppColors.textGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (c.lastMessageAt != null)
                              Text(formatTimeAgo(c.lastMessageAt!), style: const TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
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
