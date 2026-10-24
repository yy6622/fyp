import 'package:flutter/material.dart';

import '../../controllers/attraction_chat_controller.dart';
import '../../repositories/catalog_repository.dart';
import '../../services/attraction_chat_service.dart';
import '../../theme.dart';

/// "Ask AI for attraction ideas" — a conversational chatbot (OpenAI, see
/// AttractionChatService) scoped to whichever destination Explore is
/// currently showing, and grounded to the real attractions already loaded
/// there (see AttractionChatController) so it can only ever recommend
/// places Voya actually has listed, never an invented one. Each
/// recommendation shows as a real attraction card with an "Add" button
/// that saves/favorites it to the current trip — the same action as the
/// heart icon everywhere else in Explore.
class AttractionChatPage extends StatefulWidget {
  final String destination;
  final List<CatalogAttraction> candidates;
  final String uid;
  final String? tripId;

  const AttractionChatPage({
    super.key,
    required this.destination,
    required this.candidates,
    required this.uid,
    required this.tripId,
  });

  @override
  State<AttractionChatPage> createState() => _AttractionChatPageState();
}

class _AttractionChatPageState extends State<AttractionChatPage> {
  late final AttractionChatController controller = AttractionChatController.forTrip(
    destination: widget.destination,
    candidates: widget.candidates,
    uid: widget.uid,
    tripId: widget.tripId,
  );
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    // controller is NOT disposed here — it's cached by AttractionChatController
    // .forTrip and reused the next time this chat is opened for the same
    // trip/destination, so the conversation survives navigating away and back.
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text;
    if (text.trim().isEmpty) return;
    _inputCtrl.clear();
    await controller.send(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        title: Row(
          children: [
            const Icon(Icons.smart_toy_outlined, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Assistant',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    widget.destination,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textGrey, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          children: [
            if (!AttractionChatService.instance.isConfigured) _buildNotConfiguredBanner(),
            Expanded(
              child: controller.messages.isEmpty
                  ? _buildWelcome()
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: controller.messages.length + (controller.sending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= controller.messages.length) return _buildTypingBubble();
                        return _buildMessage(controller.messages[index]);
                      },
                    ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotConfiguredBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF4E5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Text(
        'Not set up yet — this needs a real OpenAI API key in secrets.dart (openAiApiKey) before it can reply.',
        style: TextStyle(fontSize: 11.5, color: AppColors.navy),
      ),
    );
  }

  Widget _buildWelcome() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy_outlined, size: 40, color: AppColors.textGrey),
            const SizedBox(height: 12),
            Text(
              'Ask me about attractions in ${widget.destination}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy),
            ),
            const SizedBox(height: 6),
            const Text(
              "I'll only suggest real places from Voya's own listings for this destination — never a made-up one.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(16)),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildMessage(AttractionChatMessage m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: m.fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: m.fromUser
                    ? AppColors.primary
                    : (m.isError ? const Color(0xFFFFE8E8) : AppColors.chipGrey),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                m.text,
                style: TextStyle(
                  fontSize: 13,
                  color: m.fromUser ? Colors.white : (m.isError ? Colors.red.shade800 : AppColors.navy),
                ),
              ),
            ),
          ),
          if (m.suggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...m.suggestions.map(_buildSuggestionCard),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(CatalogAttraction a) {
    final added = controller.isAdded(a);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 3),
                Text(
                  [a.category, if (a.price.isNotEmpty) a.price].join(' · '),
                  style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: added ? AppColors.textGrey : AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
            ),
            onPressed: added ? null : () => controller.addToTrip(a),
            child: Text(
              added ? 'Added' : 'Add',
              style: TextStyle(fontSize: 12, color: added ? AppColors.textGrey : AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(24)),
                child: TextField(
                  controller: _inputCtrl,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Ask about attractions…',
                    hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: controller.sending ? null : _send,
              icon: const Icon(Icons.send, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
