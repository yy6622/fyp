import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/secrets.dart';
import '../repositories/catalog_repository.dart';

class ChatTurn {
  final String role;
  final String text;
  const ChatTurn({required this.role, required this.text});
}

class AttractionChatReply {
  final String reply;
  final List<String> suggestedIds;
  const AttractionChatReply({required this.reply, required this.suggestedIds});
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
