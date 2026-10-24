import 'package:flutter/foundation.dart';

import '../repositories/catalog_repository.dart';
import '../services/attraction_chat_service.dart';

/// One message shown in the Attraction Assistant chat — either what the
/// person typed, or what the assistant replied (optionally with a few
/// real attractions resolved from the service's suggestedIds, see
/// [AttractionChatController._resolve]).
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

/// Controller for [AttractionChatPage]. Keeps the conversation and talks
/// to [AttractionChatService], grounding every reply to [candidates] — the
/// real attractions Explore already has loaded for [destination] — and
/// tracks which of them the person has tapped "Add" on so the chat's own
/// cards can show "Added" without waiting on a fresh Firestore read.
class AttractionChatController extends ChangeNotifier {
  AttractionChatController._({required this.destination, required this.candidates, required this.uid, required this.tripId});

  /// In-memory only (never written to disk) — reusing a cached
  /// controller keeps the conversation while the app process is still
  /// alive (switching tabs, navigating away and back within a minute or
  /// two), but a full app restart clears this map just like any other
  /// static state, so a brand-new session starts a fresh conversation,
  /// which is the behavior that was asked for.
  static final Map<String, AttractionChatController> _cache = {};

  /// Returns the existing controller (and its conversation so far) for
  /// this trip/destination if the chat was already opened this app
  /// session, otherwise creates and caches a new one. [candidates] is
  /// refreshed on every call even when reusing a cached controller, so
  /// grounding stays current without resetting the chat.
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

  /// Ids added to the trip's saved attractions from this chat session —
  /// checked alongside each attraction's own real `favoritedBy` so a
  /// suggestion already saved before the chat even opened also shows as
  /// added, not just ones tapped during this session.
  final Set<String> addedIds = {};

  bool isAdded(CatalogAttraction a) => addedIds.contains(a.id) || a.isSavedForTrip(uid, tripId);

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || sending) return;
    messages.add(AttractionChatMessage(fromUser: true, text: trimmed));
    sending = true;
    notifyListeners();
    try {
      // Everything added so far except the user message just appended
      // above (that one is sent separately as [userMessage]) — sliced by
      // position first, then filtered, so an error bubble earlier in the
      // conversation can't shift a later real message into this slice.
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

  /// Saves/favorites [attraction] for the current trip — the exact same
  /// write [ExploreController.toggleAttractionFavorite] uses, so "Add"
  /// here and the heart icon elsewhere in Explore are the same real
  /// action, not a parallel concept. A no-op (but still marked added in
  /// the UI) when there's no selected trip to save it against, since
  /// there's nowhere real to persist the favorite — same as the heart
  /// icon being hidden/disabled with no trip selected elsewhere.
  Future<void> addToTrip(CatalogAttraction attraction) async {
    if (addedIds.contains(attraction.id)) return;
    addedIds.add(attraction.id);
    notifyListeners();
    final trip = tripId;
    if (trip == null) return;
    await CatalogRepository.instance.toggleAttractionFavorite(attraction.id, uid, trip, true, categories: attraction.categoryTags);
  }
}
