import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/secrets.dart';
import '../repositories/catalog_repository.dart';

/// One turn in the conversation, in the shape OpenAI's Chat Completions
/// API wants ("user" or "assistant").
class ChatTurn {
  final String role;
  final String text;
  const ChatTurn({required this.role, required this.text});
}

/// What the model handed back for one reply — the natural-language text
/// to show, plus which of the real candidate attractions (by id) it's
/// actually recommending in this reply, if any.
class AttractionChatReply {
  final String reply;
  final List<String> suggestedIds;
  const AttractionChatReply({required this.reply, required this.suggestedIds});
}

/// Thrown with a message that is safe to show to the user as-is (same
/// pattern as ItineraryAiException in itinerary_ai_service.dart).
class AttractionChatException implements Exception {
  final String message;
  const AttractionChatException(this.message);
  @override
  String toString() => message;
}

/// Powers the Attraction Assistant chatbot (Explore > Attractions > "Ask
/// AI for attraction ideas") via OpenAI's Chat Completions API — a
/// separate provider from the rest of this app's AI features (Gemini,
/// used for live translation and the group AI-itinerary feature) because
/// the person explicitly asked for OpenAI here specifically.
///
/// Every reply is grounded to a real, already-loaded list of
/// [CatalogAttraction]s for whatever destination Explore is currently
/// showing (see AttractionChatController) — the model is only ever shown
/// those candidates and told to recommend exclusively from them, never to
/// invent a place that isn't in the list, same "don't fabricate" rule
/// every other real-data feature in this app follows. If none of the
/// candidates fit what the person asked for, the model is told to say so
/// honestly rather than making something up.
class AttractionChatService {
  AttractionChatService._();
  static final AttractionChatService instance = AttractionChatService._();

  static const String _endpoint = 'https://api.openai.com/v1/chat/completions';

  /// Cost-efficient chat model — plenty for "pick a few of these real
  /// places and explain why", not a reasoning-heavy task.
  static const String _model = 'gpt-4o-mini';

  /// Shown to the person for every failure mode (bad key, out of quota,
  /// rate limited, network error, malformed reply, ...) — the specific
  /// reason is logged to the terminal via debugPrint instead, since it's
  /// only actionable by whoever is running the app in dev, not by someone
  /// just chatting with the assistant.
  static const String _genericBusyMessage =
      'The attraction assistant is busy right now — please try again in a moment.';

  bool get isConfigured => openAiApiKey.isNotEmpty && openAiApiKey != 'YOUR_OPENAI_API_KEY_HERE';

  String _systemPrompt(String destination, List<CatalogAttraction> candidates) {
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
    return 'You are a friendly travel assistant inside the Voya app, helping someone '
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
        'CANDIDATES (JSON):\n${jsonEncode(listing)}\n\n'
        'Reply with ONLY a single JSON object, no markdown fences, no extra text, '
        'in exactly this shape:\n'
        '{"reply": "<your natural-language reply to show the person>", '
        '"suggestedIds": ["<id from CANDIDATES>", ...]}\n'
        '"suggestedIds" must contain only ids copied exactly from CANDIDATES that '
        'you are recommending in this specific reply (an empty array if you\'re not '
        'recommending anything yet, e.g. you\'re asking a clarifying question).';
  }

  /// Sends the full conversation so far (see [ChatTurn]) plus a new user
  /// message, grounded to [candidates] for [destination]. Throws
  /// [AttractionChatException] with a message safe to show as-is for
  /// every failure mode (not configured, network error, bad response) —
  /// the UI turns that into an error bubble rather than crashing.
  Future<AttractionChatReply> sendMessage({
    required String destination,
    required List<CatalogAttraction> candidates,
    required List<ChatTurn> history,
    required String userMessage,
  }) async {
    if (!isConfigured) {
      debugPrint('[AttractionChatService] not configured — openAiApiKey is empty or still the placeholder in secrets.dart.');
      throw const AttractionChatException(_genericBusyMessage);
    }
    final messages = [
      {'role': 'system', 'content': _systemPrompt(destination, candidates)},
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
      // Parenthesized around the `as String?` cast — written as a bare
      // `cond ? expr as String? : null` ternary, Dart's parser reads the
      // '?' that makes the cast target nullable as the start of a second,
      // nested ternary instead, and fails with "Expected to find ':'."
      final content = (choices != null && choices.isNotEmpty) ? ((choices.first as Map)['message']?['content'] as String?) : null;
      if (content == null || content.trim().isEmpty) {
        debugPrint('[AttractionChatService] empty/null content in OpenAI response: ${res.body}');
        throw const AttractionChatException(_genericBusyMessage);
      }
      return _parseReply(content, candidates);
    } on AttractionChatException {
      rethrow;
    } catch (e) {
      debugPrint('[AttractionChatService] error: $e');
      throw const AttractionChatException(_genericBusyMessage);
    }
  }

  /// Turns a non-200 response into a specific diagnosis for the terminal
  /// only (never shown in the app) — OpenAI's error body is
  /// `{"error": {"message", "type", "code"}}`, and a bare "HTTP 429" tells
  /// whoever is reading the logs nothing about which of several very
  /// different problems it actually is (out of credits vs. a plan that
  /// doesn't cover this model vs. genuinely sending requests too fast), so
  /// this reads `error.code`/`error.message` when present.
  String _messageForError(int statusCode, String body) {
    String? code;
    String? apiMessage;
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>?;
      code = error?['code'] as String?;
      apiMessage = error?['message'] as String?;
    } catch (_) {
      // Body wasn't JSON (or wasn't shaped as expected) — fall through to
      // the generic, status-code-only messages below.
    }
    if (statusCode == 401) {
      return 'OpenAI rejected the API key in secrets.dart — check it\'s valid.';
    }
    if (statusCode == 429) {
      if (code == 'insufficient_quota') {
        return 'The OpenAI account behind this key is out of quota/credit — add a payment method or '
            'top up credit at platform.openai.com/account/billing, then try again.';
      }
      // Any other 429 on a first call (code like "rate_limit_exceeded",
      // or no code at all) is almost always the same root cause for a
      // freshly-created key: no billing set up yet, not actually sending
      // too many requests — OpenAI returns 429 for both, so this stays
      // the practical answer rather than guessing "slow down".
      return 'OpenAI returned "too many requests" (429)${apiMessage != null ? ': $apiMessage' : ''}. '
          'For a key that has never been billed yet, this almost always means no payment method / '
          'available credit on the OpenAI account, not actual rate limiting — check '
          'platform.openai.com/account/billing.';
    }
    return 'The attraction assistant couldn\'t reach OpenAI right now (HTTP $statusCode)'
        '${apiMessage != null ? ': $apiMessage' : ''}. Try again in a moment.';
  }

  /// The model is asked for strict JSON, but is parsed defensively rather
  /// than trusted blindly: a malformed/non-JSON reply is shown to the
  /// person as plain text with no suggestions, instead of the whole
  /// message failing outright.
  AttractionChatReply _parseReply(String content, List<CatalogAttraction> candidates) {
    final validIds = candidates.map((c) => c.id).toSet();
    try {
      final parsed = jsonDecode(content) as Map<String, dynamic>;
      final reply = (parsed['reply'] as String?)?.trim() ?? '';
      final rawIds = (parsed['suggestedIds'] as List?) ?? const [];
      final ids = rawIds.whereType<String>().where(validIds.contains).toList();
      if (reply.isNotEmpty) return AttractionChatReply(reply: reply, suggestedIds: ids);
    } catch (e) {
      debugPrint('[AttractionChatService] non-JSON reply, showing as plain text: $e');
    }
    return AttractionChatReply(reply: content.trim(), suggestedIds: const []);
  }
}
