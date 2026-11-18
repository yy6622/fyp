import 'package:flutter/foundation.dart';

import '../models/day_plan_models.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/trip_repository.dart';
import '../services/attraction_chat_service.dart';

class AttractionChatMessage {
  final bool fromUser;
  final String text;
  final List<CatalogAttraction> suggestions;
  final List<AttractionChatAction> actions;
  final bool isError;
  const AttractionChatMessage({
    required this.fromUser,
    required this.text,
    this.suggestions = const [],
    this.actions = const [],
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
  // Tracks an explicit un-like within this chat session so it always wins
  // over `candidates`' baked-in favoritedBy snapshot (candidates is only
  // fetched once, when the chat opened -- see forTrip above -- so it can't
  // see a toggle made here, or anywhere else, after the fact).
  final Set<String> removedIds = {};

  bool isAdded(CatalogAttraction a) {
    if (removedIds.contains(a.id)) return false;
    return addedIds.contains(a.id) || a.isSavedForTrip(uid, tripId);
  }

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
      // Fresh read of the itinerary right before asking, rather than a live
      // subscription kept for this controller's whole (cached, never
      // disposed -- see forTrip above) lifetime: a message-by-message
      // snapshot is all the model needs to propose the next action, and
      // this avoids holding a Firestore listener open indefinitely.
      final days = tripId == null ? const <DayPlan>[] : await _fetchDays();
      final reply = await AttractionChatService.instance.sendMessage(
        destination: destination,
        candidates: candidates,
        history: history,
        userMessage: trimmed,
        days: days,
      );
      messages.add(AttractionChatMessage(
        fromUser: false,
        text: reply.reply,
        suggestions: _resolve(reply.suggestedIds),
        actions: reply.actions,
      ));
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

  Future<List<DayPlan>> _fetchDays() async {
    try {
      final trip = await TripRepository.instance.getTrip(tripId!, uid);
      return trip?.days ?? const [];
    } catch (_) {
      return const [];
    }
  }

  List<CatalogAttraction> _resolve(List<String> ids) {
    final byId = {for (final c in candidates) c.id: c};
    return ids.map((id) => byId[id]).whereType<CatalogAttraction>().toList();
  }

  Future<void> addToTrip(CatalogAttraction attraction) async {
    final trip = tripId;
    if (trip == null || isAdded(attraction)) return;
    removedIds.remove(attraction.id);
    addedIds.add(attraction.id);
    notifyListeners();
    await CatalogRepository.instance.toggleAttractionFavorite(attraction.id, uid, trip, true, categories: attraction.categoryTags);
  }

  /// The other half of the like-style toggle on the suggestion card's
  /// heart icon -- un-favorites the attraction for this trip.
  Future<void> removeFromTrip(CatalogAttraction attraction) async {
    final trip = tripId;
    if (trip == null || !isAdded(attraction)) return;
    addedIds.remove(attraction.id);
    removedIds.add(attraction.id);
    notifyListeners();
    await CatalogRepository.instance.toggleAttractionFavorite(attraction.id, uid, trip, false, categories: attraction.categoryTags);
  }

  // Keyed by identity (object hashCode via a wrapper key string) since an
  // action has no stable id of its own until it's applied -- good enough
  // for "don't let the same card be tapped twice while it's in flight / is
  // already done", which is all this needs to do.
  final Set<AttractionChatAction> appliedActions = {};
  final Set<AttractionChatAction> _applyingActions = {};

  bool isApplied(AttractionChatAction action) => appliedActions.contains(action);
  bool isApplying(AttractionChatAction action) => _applyingActions.contains(action);

  /// Writes a confirmed itinerary action to the trip. Returns null on
  /// success, or a short message to show the person (e.g. in a SnackBar) on
  /// failure -- same "return the error, don't throw" shape as this
  /// controller's other write methods like addToTrip's caller would expect.
  Future<String?> applyAction(AttractionChatAction action) async {
    final trip = tripId;
    if (trip == null || appliedActions.contains(action) || _applyingActions.contains(action)) return null;
    _applyingActions.add(action);
    notifyListeners();
    try {
      switch (action.type) {
        case ChatActionType.addActivity:
          await TripRepository.instance.addActivity(
            trip,
            action.day - 1,
            time: action.time ?? '',
            label: action.label,
            iconKey: action.iconKey,
            location: action.location ?? '',
            sourceRef: action.attractionId != null ? 'attraction:${action.attractionId}' : '',
            actorUid: uid,
          );
          break;
        case ChatActionType.removeActivity:
          await TripRepository.instance.removeActivity(trip, action.day - 1, action.activityId!, actorUid: uid);
          break;
        case ChatActionType.updateTime:
          await TripRepository.instance.updateActivityTime(trip, action.day - 1, action.activityId!, action.time ?? '', actorUid: uid);
          break;
        case ChatActionType.moveActivity:
          await TripRepository.instance.moveActivityToDay(
            trip,
            action.day - 1,
            action.activityId!,
            (action.toDay ?? action.day) - 1,
            action.time ?? '',
            actorUid: uid,
          );
          break;
      }
      appliedActions.add(action);
      return null;
    } catch (e) {
      return "Couldn't update the plan. Please try again.";
    } finally {
      _applyingActions.remove(action);
      notifyListeners();
    }
  }
}
