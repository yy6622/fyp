import 'package:flutter/foundation.dart';

import '../repositories/catalog_repository.dart';
import '../services/attraction_chat_service.dart';

class AttractionChatMessage {
  final bool fromUser;
  final String text;
  final List<CatalogAttraction> suggestions;
  final bool isError;
  const AttractionChatMessage({
    required this.fromUser,
    required this.text,
    this.suggestions = const [],
    this.isError = false,
  });
}

class AttractionChatController extends ChangeNotifier {
  AttractionChatController._({required this.destination, required this.candidates, required this.uid, required this.tripId});

  static final Map<String, AttractionChatController> _cache = {};

  factory AttractionChatController.forTrip({
    required String destination,
    required List<CatalogAttraction> candidates,
    required String uid,
    required String? tripId,
  }) {
    final key = '$uid|${tripId ?? destination}';
    final existing = _cache[key];
    if (existing != null) {
      existing.candidates = candidates;
      return existing;
    }
    final created = AttractionChatController._(destination: destination, candidates: candidates, uid: uid, tripId: tripId);
    _cache[key] = created;
    return created;
  }

  final String destination;
  List<CatalogAttraction> candidates;
  final String uid;
  final String? tripId;

  final List<AttractionChatMessage> messages = [];
  bool sending = false;

  final Set<String> addedIds = {};

  bool isAdded(CatalogAttraction a) => addedIds.contains(a.id) || a.isSavedForTrip(uid, tripId);

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || sending) return;
    messages.add(AttractionChatMessage(fromUser: true, text: trimmed));
    sending = true;
    notifyListeners();
    try {
      final history = messages
          .sublist(0, messages.length - 1)
          .where((m) => !m.isError)
          .map((m) => ChatTurn(role: m.fromUser ? 'user' : 'assistant', text: m.text))
          .toList();
      final reply = await AttractionChatService.instance.sendMessage(
        destination: destination,
        candidates: candidates,
        history: history,
        userMessage: trimmed,
      );
      messages.add(AttractionChatMessage(fromUser: false, text: reply.reply, suggestions: _resolve(reply.suggestedIds)));
    } on AttractionChatException catch (e) {
      messages.add(AttractionChatMessage(fromUser: false, text: e.message, isError: true));
    } catch (e) {
      messages.add(const AttractionChatMessage(
        fromUser: false,
        text: 'Something went wrong. Please try again.',
        isError: true,
      ));
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  List<CatalogAttraction> _resolve(List<String> ids) {
    final byId = {for (final c in candidates) c.id: c};
    return ids.map((id) => byId[id]).whereType<CatalogAttraction>().toList();
  }

  Future<void> addToTrip(CatalogAttraction attraction) async {
    final trip = tripId;
    if (trip == null || addedIds.contains(attraction.id)) return;
    addedIds.add(attraction.id);
    notifyListeners();
    await CatalogRepository.instance.toggleAttractionFavorite(attraction.id, uid, trip, true, categories: attraction.categoryTags);
  }
}
