import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/secrets.dart';
import '../models/day_plan_models.dart';
import '../repositories/catalog_repository.dart';

class ChatTurn {
  final String role;
  final String text;
  const ChatTurn({required this.role, required this.text});
}

/// What kind of itinerary change an [AttractionChatAction] proposes.
enum ChatActionType { addActivity, removeActivity, updateTime, moveActivity }

/// An itinerary change the assistant is proposing in reply to the
/// traveller's message. Shown in the chat as a confirm-to-apply card --
/// same "propose, then the person taps to confirm" pattern this page
/// already uses for attraction suggestions -- rather than being written to
/// the trip automatically. By the time this reaches the controller it has
/// already been validated in [AttractionChatService._parseReply] against
/// the real itinerary that was sent to the model (a day number and, for
/// anything but adding, an activityId that actually exist), but applying it
/// still goes through the same TripRepository calls a person editing the
/// plan by hand would -- the model never writes to Firestore directly.
class AttractionChatAction {
  final ChatActionType type;

  /// 1-based "Day N" this action applies to (the day something is added
  /// to/removed from/rescheduled on, or moved FROM for [ChatActionType.moveActivity]).
  final int day;

  /// Only for [ChatActionType.moveActivity]: the 1-based day to move to.
  final int? toDay;

  /// Only for [ChatActionType.addActivity]: null, since the activity
  /// doesn't exist yet -- TripRepository generates its id on write.
  final String? activityId;

  /// Human-readable activity name, always present so the chat UI can show
  /// a clear confirm card without needing to look anything up itself.
  final String label;

  /// New/kept time, for add/update/move (free text, e.g. "10:00 AM").
  final String? time;

  /// Only meaningful for add.
  final String? location;

  /// One of trip_repository.dart's activityIcons keys. Defaults to
  /// 'activity' (a generic icon) if the model left it out or sent an
  /// unrecognised key.
  final String iconKey;

  /// Set only when this add was prompted by a specific CANDIDATES
  /// attraction -- stored as the new activity's sourceRef so the
  /// "missing from your plan" suggestions elsewhere never re-suggest it.
  final String? attractionId;

  const AttractionChatAction({
    required this.type,
    required this.day,
    this.toDay,
    this.activityId,
    required this.label,
    this.time,
    this.location,
    this.iconKey = 'activity',
    this.attractionId,
  });
}

class AttractionChatReply {
  final String reply;
  final List<String> suggestedIds;
  final List<AttractionChatAction> actions;
  const AttractionChatReply({required this.reply, required this.suggestedIds, this.actions = const []});
}

class AttractionChatException implements Exception {
  final String message;
  const AttractionChatException(this.message);
  @override
  String toString() => message;
}

class AttractionChatService {
  AttractionChatService._();
  static final AttractionChatService instance = AttractionChatService._();

  static const String _endpoint = 'https://api.openai.com/v1/chat/completions';

  static const String _model = 'gpt-4o-mini';

  static const String _genericBusyMessage =
      'The attraction assistant is busy right now — please try again in a moment.';

  bool get isConfigured => openAiApiKey.isNotEmpty && openAiApiKey != 'YOUR_OPENAI_API_KEY_HERE';

  String _systemPrompt(String destination, List<CatalogAttraction> candidates, List<DayPlan> days) {
    final listing = candidates
        .map((a) => {
              'id': a.id,
              'name': a.name,
              'category': a.category,
              'rating': a.rating,
              'price': a.price,
              if (a.description.isNotEmpty) 'description': a.description,
              if (a.highlights.isNotEmpty) 'highlights': a.highlights,
            })
        .toList();
    final buffer = StringBuffer();
    buffer.write(
        'You are a friendly travel assistant inside the Voya app, helping someone '
        'plan what attractions to visit in $destination.\n\n'
        'CANDIDATES is the ONLY real, up-to-date list of attractions Voya actually '
        'knows about for $destination. You must recommend exclusively from this '
        'list — never invent, assume, or mention an attraction that is not in '
        'CANDIDATES, even if you believe it exists in real life.\n\n'
        'When matching what the person asks for against CANDIDATES, be generous, '
        'not literal: if they name a general type of place ("museum", "temple", '
        '"beach", "seafood", ...), match it against every candidate whose '
        'category, name, description, or highlights relate to that type — do not '
        'require the exact words they typed to appear in a candidate\'s name. Only '
        'say nothing was found if truly none of CANDIDATES relate to what they '
        'asked for at all. If that happens, apologize and say so honestly, naming '
        'the specific thing they asked for, e.g. '
        '"Sorry, I couldn\'t find \'<what they asked for>\' in Voya\'s listings '
        'for $destination yet." instead of making something up.\n\n'
        'CANDIDATES (JSON):\n${jsonEncode(listing)}\n\n');

    if (days.isNotEmpty) {
      final itinerary = days
          .map((d) => {
                'day': d.day,
                'weekday': d.weekday,
                'date': d.date,
                'items': d.items
                    .map((i) => {'activityId': i.id, 'time': i.time, 'label': i.label, if (i.location.isNotEmpty) 'location': i.location})
                    .toList(),
              })
          .toList();
      buffer.write(
          'You can also manage this traveller\'s itinerary for this trip. ITINERARY '
          'below is the real, current plan — every day that exists on the trip and '
          'every activity already on it, with its real activityId. Day numbers are '
          '1-based, matching what the traveller sees as "Day 1", "Day 2", etc.\n\n'
          'ITINERARY (JSON):\n${jsonEncode(itinerary)}\n\n'
          'IMPORTANT: the "only recommend from CANDIDATES" rule above applies to '
          'attraction RECOMMENDATIONS ("reply" text and "suggestedIds") — it does '
          'NOT apply to adding an activity to the itinerary. Adding to the itinerary '
          'is exactly like the traveller typing their own activity into Voya\'s '
          '"Add Activity → Type it in" form by hand: a free-text label on their '
          'plan, not a verified catalog listing, so you may add absolutely anything '
          'the traveller describes — a restaurant, a personal errand, a place to '
          'meet a friend, anything — even if it has nothing to do with CANDIDATES or '
          'doesn\'t exist in Voya\'s listings at all. Never refuse to add something '
          'to the itinerary just because it isn\'t in CANDIDATES.\n\n'
          'When the traveller asks you to add, remove, reschedule, or move something '
          'on their itinerary, propose it as an entry in "actions" (see the reply '
          'shape below), IN ADDITION to a plain-language "reply" describing exactly '
          'what you\'re about to do so they can see and confirm it before it happens '
          '(nothing in "actions" is applied automatically — the person must tap a '
          'confirm button). Rules for "actions" entries:\n'
          '- Adding a NEW activity (from CANDIDATES, or anything else the traveller '
          'describes — see above): {"type":"add_activity","day":<existing day '
          'number from ITINERARY>,"time":"<e.g. 10:00 AM>","label":"<the PLAIN place/activity '
          'name only — if this is a CANDIDATES attraction, copy its "name" field '
          'EXACTLY as given (character for character), otherwise exactly what the '
          'traveller called it. NEVER prefix it with a verb like "Visit ", "Go to ", '
          '"See ", "Explore ", "Check out ", etc. — the app matches this label back to '
          'the real attraction by exact name to show its photo/rating/price and make it '
          'tappable, exactly like an item added from the traveller\'s saved list; any '
          'added prefix or wording breaks that match.>","location":"<optional>"'
          ',"iconKey":"<one of food, hotel, flight, '
          'shopping, place, activity — pick whichever fits best>"'
          ',"attractionId":"<the CANDIDATES id, only if this came from CANDIDATES>"}\n'
          '- Removing an EXISTING activity: {"type":"remove_activity","day":<day '
          'number>,"activityId":"<copied exactly from ITINERARY>","label":"<that '
          'activity\'s label, for display>"}\n'
          '- Changing only an EXISTING activity\'s time: '
          '{"type":"update_time","day":<day number>,"activityId":"<from '
          'ITINERARY>","label":"<its label>","time":"<new time>"}\n'
          '- Moving an EXISTING activity to a different day (optionally also a new '
          'time): {"type":"move_activity","day":<CURRENT day number>,"toDay":<day '
          'to move it to>,"activityId":"<from ITINERARY>","label":"<its '
          'label>","time":"<keep the existing time if not asked to change it>"}\n'
          'Never invent a day number or activityId that is not in ITINERARY, and '
          'never propose an action the traveller did not ask for — do not add, '
          'remove, or reschedule anything on your own initiative. "actions" must be '
          'an empty array whenever you are not proposing a change this turn.\n\n'
          'Always propose add_activity, update_time, and move_activity with EXACTLY '
          'the day and time the traveller asked for (for move_activity, keep the '
          'activity\'s current time from ITINERARY if they did not mention a new '
          'one). Do NOT compare times against ITINERARY yourself, do NOT refuse or '
          'delay proposing the action over a possible time clash, and do NOT '
          'mention a clash in "reply" on your own judgement — the app checks for a '
          'genuinely double-booked slot in code, precisely, right after you '
          'propose it, and will turn your action into a message asking the '
          'traveller to pick another time automatically if (and only if) one '
          'really exists. Your own guess about a clash is frequently wrong, so '
          'leave that entirely to the app and just propose what was asked.\n\n');
    }

    buffer.write(
        'Reply with ONLY a single JSON object, no markdown fences, no extra text, '
        'in exactly this shape:\n'
        '{"reply": "<your natural-language reply to show the person>", '
        '"suggestedIds": ["<id from CANDIDATES>", ...], '
        '"actions": [${days.isNotEmpty ? '<see the itinerary rules above>' : ''}]}\n'
        '"suggestedIds" must contain only ids copied exactly from CANDIDATES that '
        'you are recommending in this specific reply (an empty array if you\'re not '
        'recommending anything yet, e.g. you\'re asking a clarifying question). '
        '"actions" must always be present as an array (empty if there\'s nothing to '
        'propose this turn).');
    return buffer.toString();
  }

  Future<AttractionChatReply> sendMessage({
    required String destination,
    required List<CatalogAttraction> candidates,
    required List<ChatTurn> history,
    required String userMessage,
    List<DayPlan> days = const [],
  }) async {
    if (!isConfigured) {
      debugPrint('[AttractionChatService] not configured — openAiApiKey is empty or still the placeholder in secrets.dart.');
      throw const AttractionChatException(_genericBusyMessage);
    }
    final messages = [
      {'role': 'system', 'content': _systemPrompt(destination, candidates, days)},
      ...history.map((t) => {'role': t.role, 'content': t.text}),
      {'role': 'user', 'content': userMessage},
    ];
    try {
      final res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $openAiApiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': messages,
              'temperature': 0.4,
              'response_format': {'type': 'json_object'},
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        debugPrint('[AttractionChatService] HTTP ${res.statusCode}: ${res.body}');
        debugPrint('[AttractionChatService] diagnosis: ${_messageForError(res.statusCode, res.body)}');
        throw const AttractionChatException(_genericBusyMessage);
      }
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List?;
      final content = (choices != null && choices.isNotEmpty) ? ((choices.first as Map)['message']?['content'] as String?) : null;
      if (content == null || content.trim().isEmpty) {
        debugPrint('[AttractionChatService] empty/null content in OpenAI response: ${res.body}');
        throw const AttractionChatException(_genericBusyMessage);
      }
      return _parseReply(content, candidates, days);
    } on AttractionChatException {
      rethrow;
    } catch (e) {
      debugPrint('[AttractionChatService] error: $e');
      throw const AttractionChatException(_genericBusyMessage);
    }
  }

  String _messageForError(int statusCode, String body) {
    String? code;
    String? apiMessage;
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>?;
      code = error?['code'] as String?;
      apiMessage = error?['message'] as String?;
    } catch (_) {
    }
    if (statusCode == 401) {
      return 'OpenAI rejected the API key in secrets.dart — check it\'s valid.';
    }
    if (statusCode == 429) {
      if (code == 'insufficient_quota') {
        return 'The OpenAI account behind this key is out of quota/credit — add a payment method or '
            'top up credit at platform.openai.com/account/billing, then try again.';
      }
      return 'OpenAI returned "too many requests" (429)${apiMessage != null ? ': $apiMessage' : ''}. '
          'For a key that has never been billed yet, this almost always means no payment method / '
          'available credit on the OpenAI account, not actual rate limiting — check '
          'platform.openai.com/account/billing.';
    }
    return 'The attraction assistant couldn\'t reach OpenAI right now (HTTP $statusCode)'
        '${apiMessage != null ? ': $apiMessage' : ''}. Try again in a moment.';
  }

  AttractionChatReply _parseReply(String content, List<CatalogAttraction> candidates, List<DayPlan> days) {
    final validIds = candidates.map((c) => c.id).toSet();
    // Authoritative id->name lookup, so an add_activity for a real
    // CANDIDATES attraction always ends up labelled with the catalog's own
    // name -- never whatever text the model wrote -- see _parseAction.
    final attractionNames = {for (final c in candidates) c.id: c.name};
    try {
      final parsed = jsonDecode(content) as Map<String, dynamic>;
      final reply = (parsed['reply'] as String?)?.trim() ?? '';
      final rawIds = (parsed['suggestedIds'] as List?) ?? const [];
      final ids = rawIds.whereType<String>().where(validIds.contains).toList();
      final rawActions = (parsed['actions'] as List?) ?? const [];
      final parsedActions = rawActions.whereType<Map>().map((a) => _parseAction(Map<String, dynamic>.from(a), days, validIds, attractionNames)).toList();
      final actions = parsedActions.map((p) => p.action).whereType<AttractionChatAction>().toList();
      // Backstop against the model double-booking a slot despite the system
      // prompt asking it to check first (see _findClash) -- a conflicting
      // action is never turned into a ready-to-confirm card; instead the
      // person sees a plain-language note asking them to pick a time,
      // appended to whatever the model already said this turn.
      final conflicts = parsedActions.map((p) => p.conflict).whereType<String>().toList();
      final finalReply = conflicts.isEmpty ? reply : [reply, ...conflicts].where((s) => s.isNotEmpty).join('\n\n');
      if (finalReply.isNotEmpty) return AttractionChatReply(reply: finalReply, suggestedIds: ids, actions: actions);
    } catch (e) {
      debugPrint('[AttractionChatService] non-JSON reply, showing as plain text: $e');
    }
    return AttractionChatReply(reply: content.trim(), suggestedIds: const []);
  }

  // Parses a free-text time ("2:00 PM", "2:00PM", "2pm", "14:00", "2:00")
  // into minutes-since-midnight, or null if it doesn't look like a time at
  // all. Used both to normalize a model-proposed time into the canonical
  // 24h "HH:MM" this app stores (see _parseAction) and to compare against
  // a possibly-differently-formatted EXISTING activity time when checking
  // for a double-booked slot (an activity added before this normalization
  // existed can still be stored as "2:00 PM" verbatim).
  int? _parseTimeToMinutes(String? raw) {
    if (raw == null) return null;
    final t = raw.trim().toUpperCase();
    final m = RegExp(r'^(\d{1,2}):?(\d{2})?\s*(AM|PM)?$').firstMatch(t);
    if (m == null) return null;
    var hour = int.tryParse(m.group(1) ?? '');
    final minute = int.tryParse(m.group(2) ?? '0') ?? 0;
    if (hour == null || minute < 0 || minute > 59) return null;
    final period = m.group(3);
    if (period != null) {
      if (hour < 1 || hour > 12) return null;
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
    } else if (hour < 0 || hour > 23) {
      return null;
    }
    return hour * 60 + minute;
  }

  // The canonical on-disk format (what the manual "Add Activity" time
  // picker has always stored) -- normalizing every chat-proposed time into
  // this same shape, rather than storing whatever free-text style the
  // model happened to use, is what the plan page's 12h display formatter
  // expects; a mismatch there is what used to render as a stray trailing
  // "2:00 PM am" clipped to "2:00 PM a" in the UI.
  String? _normalizeTime(String raw) {
    final minutes = _parseTimeToMinutes(raw);
    if (minutes == null) return null;
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _formatMinutes12h(int totalMinutes) {
    final m = totalMinutes % (24 * 60);
    final hour24 = m ~/ 60;
    final minute = m % 60;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    var hour12 = hour24 % 12;
    if (hour12 == 0) hour12 = 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  // Finds an activity already on [dayPlan] at the same time as [time]
  // (minute-for-minute, tolerating either 24h or 12h-with-AM/PM source
  // formats on either side), other than [excludingActivityId] itself --
  // that exclusion matters for update_time/move_activity, where the
  // activity being rescheduled already occupies its OLD slot and must not
  // be reported as clashing with itself.
  ({String label, String time})? _findClash(DayPlan dayPlan, String time, {String? excludingActivityId}) {
    final targetMinutes = _parseTimeToMinutes(time);
    for (final item in dayPlan.items) {
      if (excludingActivityId != null && item.id == excludingActivityId) continue;
      final itemMinutes = _parseTimeToMinutes(item.time);
      final sameSlot = (targetMinutes != null && itemMinutes != null)
          ? targetMinutes == itemMinutes
          : item.time.trim().toLowerCase() == time.trim().toLowerCase();
      if (sameSlot) return (label: item.label, time: item.time);
    }
    return null;
  }

  String _conflictMessage({required int day, required String clashLabel, required String clashTime, required String newLabel, String? proposedTime}) {
    final clashMinutes = _parseTimeToMinutes(clashTime);
    final suggestion = clashMinutes != null ? _formatMinutes12h(clashMinutes + 120) : null;
    return 'Day $day already has "$clashLabel" at $clashTime, so I didn\'t add "$newLabel" at '
        '${proposedTime ?? clashTime} to avoid double-booking that slot.'
        '${suggestion != null ? ' Want me to schedule it at $suggestion instead (about 2 hours later), or let me know another time?' : ' What time would you like instead?'}';
  }

  static const Set<String> _validIconKeys = {'flight', 'hotel', 'shopping', 'food', 'place', 'activity'};

  /// Validates one proposed action against the REAL itinerary that was sent
  /// to the model ([days]) -- never trust the model's own idea of what day
  /// or activityId exists. Returns a null [action] (silently dropped, same
  /// as an unrecognised suggestedId) for anything that doesn't check out:
  /// an unknown type, a day number not on this trip, an activityId that
  /// isn't actually on that day right now, or a time that doesn't parse at
  /// all. A non-null [conflict] means the action was otherwise valid but
  /// would double-book a slot another activity already occupies -- also no
  /// [action] in that case (never a ready-to-confirm card for it), but with
  /// a plain-language message for _parseReply to surface instead, asking
  /// the traveller to pick a time (see _findClash/_conflictMessage).
  ({AttractionChatAction? action, String? conflict}) _parseAction(
      Map<String, dynamic> raw, List<DayPlan> days, Set<String> validAttractionIds,
      Map<String, String> attractionNames) {
    const ({AttractionChatAction? action, String? conflict}) none = (action: null, conflict: null);
    final type = raw['type'] as String?;
    final day = (raw['day'] as num?)?.toInt();
    if (type == null || day == null) return none;
    DayPlan? dayPlan;
    for (final d in days) {
      if (d.day == day) {
        dayPlan = d;
        break;
      }
    }
    if (dayPlan == null) return none;

    String? activityLabelOf(String id) {
      for (final i in dayPlan!.items) {
        if (i.id == id) return i.label;
      }
      return null;
    }

    String? activityTimeOf(String id) {
      for (final i in dayPlan!.items) {
        if (i.id == id) return i.time;
      }
      return null;
    }

    final iconKey = (raw['iconKey'] as String?) ?? 'activity';
    final rawTime = (raw['time'] as String?)?.trim();
    final location = (raw['location'] as String?)?.trim();

    switch (type) {
      case 'add_activity':
        final rawLabel = (raw['label'] as String?)?.trim() ?? '';
        final attractionId = raw['attractionId'] as String?;
        // Trust the catalog's own name over whatever text the model wrote,
        // whenever this add was prompted by a real CANDIDATES attraction.
        // GroupTripController.attractionForActivity matches an itinerary
        // item back to its CatalogAttraction by comparing this label
        // against the attraction's name EXACTLY -- that match is what
        // shows the rich image/rating/price card and makes the item
        // tappable into its detail page, same as an item added from the
        // saved list. A close-but-not-exact label (e.g. the model adding a
        // "Visit " prefix despite being told not to) would silently fall
        // back to a plain generic activity, so this is enforced here
        // rather than left to the model's prompt compliance.
        final label = (attractionId != null && attractionNames.containsKey(attractionId))
            ? attractionNames[attractionId]!
            : rawLabel;
        if (label.isEmpty || rawTime == null || rawTime.isEmpty) return none;
        // Normalized to the same 24h "HH:MM" the manual Add Activity picker
        // has always stored, rather than whatever free-text style the
        // model used -- see _normalizeTime's doc for why a mismatch there
        // used to corrupt the plan page's time display.
        final normalizedTime = _normalizeTime(rawTime);
        if (normalizedTime == null) return none;
        final clash = _findClash(dayPlan, normalizedTime);
        if (clash != null) {
          return (
            action: null,
            conflict: _conflictMessage(day: day, clashLabel: clash.label, clashTime: clash.time, newLabel: label, proposedTime: rawTime),
          );
        }
        return (
          action: AttractionChatAction(
            type: ChatActionType.addActivity,
            day: day,
            label: label,
            time: normalizedTime,
            location: (location != null && location.isNotEmpty) ? location : null,
            iconKey: _validIconKeys.contains(iconKey) ? iconKey : 'activity',
            attractionId: (attractionId != null && validAttractionIds.contains(attractionId)) ? attractionId : null,
          ),
          conflict: null,
        );
      case 'remove_activity':
      case 'update_time':
      case 'move_activity':
        final activityId = raw['activityId'] as String?;
        if (activityId == null) return none;
        final existingLabel = activityLabelOf(activityId);
        if (existingLabel == null) return none; // not really on this day -- drop it
        if (type == 'remove_activity') {
          return (action: AttractionChatAction(type: ChatActionType.removeActivity, day: day, activityId: activityId, label: existingLabel), conflict: null);
        }
        if (type == 'update_time') {
          if (rawTime == null || rawTime.isEmpty) return none;
          final normalizedTime = _normalizeTime(rawTime);
          if (normalizedTime == null) return none;
          final clash = _findClash(dayPlan, normalizedTime, excludingActivityId: activityId);
          if (clash != null) {
            return (
              action: null,
              conflict: _conflictMessage(day: day, clashLabel: clash.label, clashTime: clash.time, newLabel: existingLabel, proposedTime: rawTime),
            );
          }
          return (
            action: AttractionChatAction(type: ChatActionType.updateTime, day: day, activityId: activityId, label: existingLabel, time: normalizedTime),
            conflict: null,
          );
        }
        // move_activity
        final toDay = (raw['toDay'] as num?)?.toInt();
        if (toDay == null) return none;
        DayPlan? targetDayPlan;
        for (final d in days) {
          if (d.day == toDay) {
            targetDayPlan = d;
            break;
          }
        }
        if (targetDayPlan == null) return none;
        // Always resolve a CONCRETE target time, even when the traveller
        // didn't ask to change it -- TripRepository.moveActivityToDay
        // writes whatever time string it's given verbatim with no "leave
        // it alone" case of its own, so letting a null/empty time reach it
        // would silently wipe the activity's time instead of keeping it.
        String targetTime;
        if (rawTime != null && rawTime.isNotEmpty) {
          final normalized = _normalizeTime(rawTime);
          if (normalized == null) return none;
          targetTime = normalized;
        } else {
          final currentTime = activityTimeOf(activityId) ?? '';
          targetTime = _normalizeTime(currentTime) ?? currentTime;
        }
        final clash = _findClash(targetDayPlan, targetTime, excludingActivityId: activityId);
        if (clash != null) {
          return (
            action: null,
            conflict: _conflictMessage(day: toDay, clashLabel: clash.label, clashTime: clash.time, newLabel: existingLabel, proposedTime: targetTime),
          );
        }
        return (
          action: AttractionChatAction(
            type: ChatActionType.moveActivity,
            day: day,
            toDay: toDay,
            activityId: activityId,
            label: existingLabel,
            time: targetTime,
          ),
          conflict: null,
        );
      default:
        return none;
    }
  }

}
