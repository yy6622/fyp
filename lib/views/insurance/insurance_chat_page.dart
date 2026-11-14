import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/insurance_models.dart';
import '../../repositories/insurance_chat_repository.dart';
import '../../repositories/insurance_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../services/currency_service.dart';
import '../../theme.dart';
import 'insurance_plan_detail_page.dart';

const List<String> _chatMonthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatChatTime(DateTime? d) {
  if (d == null) return '';
  final now = DateTime.now();
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  final time = '$hour12:$minute $ampm';
  final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
  if (sameDay) return time;
  return '${d.day} ${_chatMonthNames[d.month - 1]}, $time';
}

/// Direct-message thread between the signed-in traveller and one
/// insurance partner. Reachable both before a purchase (from a plan's
/// detail page, to ask questions) and after (from the History Insurance
/// detail page, to discuss the policy) — [planName] is only set in the
/// former case, for context on the first message.
class InsuranceChatPage extends StatefulWidget {
  final String partnerId;
  final String providerName;
  final String? planName;
  const InsuranceChatPage({super.key, required this.partnerId, required this.providerName, this.planName});

  @override
  State<InsuranceChatPage> createState() => _InsuranceChatPageState();
}

class _InsuranceChatPageState extends State<InsuranceChatPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  String? _chatId;
  bool _ready = false;
  bool _sending = false;
  final Map<String, Future<InsurancePlan?>> _planCache = {};

  Future<InsurancePlan?> _resolvePlan(String planId) =>
      _planCache.putIfAbsent(planId, () => InsuranceRepository.instance.getPlan(planId));

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    String travellerName = AuthService.instance.currentUser?.displayName ?? '';
    if (travellerName.trim().isEmpty) {
      try {
        final profile = await UserRepository.instance.fetchProfile(uid);
        travellerName = profile?.name ?? '';
      } catch (_) {
        // Fall back to whatever we already have (possibly empty) rather
        // than blocking the chat from opening.
      }
    }
    if (travellerName.trim().isEmpty) travellerName = AuthService.instance.currentUser?.email ?? 'Traveller';
    final id = await InsuranceChatRepository.instance.ensureChat(
      travellerId: uid,
      travellerName: travellerName,
      partnerId: widget.partnerId,
      providerName: widget.providerName,
      planName: widget.planName,
    );
    unawaited(InsuranceChatRepository.instance.markRead(chatId: id, asRole: 'traveller'));
    if (!mounted) return;
    setState(() {
      _chatId = id;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final chatId = _chatId;
    final uid = AuthService.instance.currentUser?.uid;
    final text = _inputCtrl.text;
    if (chatId == null || uid == null || text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    _inputCtrl.clear();
    try {
      await InsuranceChatRepository.instance.sendMessage(
        chatId: chatId,
        senderId: uid,
        senderRole: 'traveller',
        text: text,
      );
      if (_scrollCtrl.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
                duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: VoyaAppBar(
        title: Text(widget.providerName, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<InsuranceChatMessage>>(
                    stream: InsuranceChatRepository.instance.watchMessages(_chatId!),
                    builder: (context, snap) {
                      final messages = snap.data ?? const [];
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      if (messages.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Say hello to ${widget.providerName} — ask anything about your plan or policy.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
                            ),
                          ),
                        );
                      }
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollCtrl.hasClients) {
                          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                        }
                      });
                      return ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, i) => _bubble(messages[i], isMe: messages[i].senderId == uid),
                      );
                    },
                  ),
                ),
                _composer(),
              ],
            ),
    );
  }

  Widget _bubble(InsuranceChatMessage m, {required bool isMe}) {
    final planId = m.attachedPlanId;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: planId != null ? 10 : 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.chipGrey,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (planId != null) _planCard(planId, isMe) else Text(m.text, style: TextStyle(fontSize: 13.5, color: isMe ? Colors.white : Colors.black87)),
            const SizedBox(height: 4),
            Text(
              _formatChatTime(m.createdAt),
              style: TextStyle(fontSize: 9.5, color: isMe ? Colors.white70 : AppColors.textGrey),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders the attached plan as a tappable card — fetched live via
  /// [_resolvePlan] (cached per planId) rather than any snapshot stored on
  /// the message, so it always reflects the plan's current price/coverage.
  /// Shows "no longer available" if the partner has since deactivated the
  /// plan or been unapproved.
  Widget _planCard(String planId, bool isMe) {
    return FutureBuilder<InsurancePlan?>(
      future: _resolvePlan(planId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 40,
            child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final plan = snap.data;
        if (plan == null) {
          return Text(
            'This plan is no longer available.',
            style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: isMe ? Colors.white70 : AppColors.textGrey),
          );
        }
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InsurancePlanDetailPage(plan: plan))),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe ? Colors.white.withOpacity(0.12) : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(minWidth: 180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: isMe ? Colors.white : AppColors.navy),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        plan.name,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isMe ? Colors.white : AppColors.navy),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(plan.displayPrice(CurrencyService.instance.lastKnownUserCurrency), style: TextStyle(fontSize: 12, color: isMe ? Colors.white.withOpacity(0.85) : AppColors.textGrey)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('View plan', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isMe ? Colors.white : AppColors.primary)),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right, size: 14, color: isMe ? Colors.white : AppColors.primary),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(24)),
                child: TextField(
                  controller: _inputCtrl,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: const TextStyle(fontSize: 13.5, color: Colors.black),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _sending ? null : _send,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                alignment: Alignment.center,
                child: _sending
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
