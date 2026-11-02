import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/secrets.dart';

class ModerationResult {
  final bool flagged;
  final String reason;
  const ModerationResult({required this.flagged, required this.reason});

  static const ModerationResult clean = ModerationResult(flagged: false, reason: '');
}

class ContentModerationService {
  ContentModerationService._();
  static final ContentModerationService instance = ContentModerationService._();

  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent';

  // Obvious profanity is caught locally first, so moderation still works when
  // Gemini is offline, over quota, or returns an empty answer. Gemini then
  // handles everything subtler (hate speech, harassment, other languages).
  static final RegExp _localProfanity = RegExp(
    r'\b(fuck\w*|shit\w*|bullshit|crap|bitch\w*|bastard\w*|asshole\w*|dickhead\w*|moron\w*|idiot\w*|'
    r'retard\w*|cunt\w*|wanker\w*|motherfuck\w*|stfu|wtf|pukimak|puki|bodoh|sial|celaka|lancau)\b',
    caseSensitive: false,
  );
  static const List<String> _localProfanityZh = ['他妈的', '操你', '傻逼', '傻b', '妈的', '去死', '王八蛋', '贱人', '白痴'];

  /// Local word-list check (no network). Returns the matched word, or null.
  static String? localMatch(String text) {
    final m = _localProfanity.firstMatch(text);
    if (m != null) return m.group(0);
    for (final w in _localProfanityZh) {
      if (text.contains(w)) return w;
    }
    return null;
  }

  bool get isConfigured => geminiApiKey.isNotEmpty && geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE';

  Future<ModerationResult> check(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return ModerationResult.clean;
    final hit = localMatch(trimmed);
    if (hit != null) {
      return const ModerationResult(flagged: true, reason: 'Profanity');
    }
    if (!isConfigured) {
      debugPrint('[ContentModerationService] skipped — no Gemini API key configured in secrets.dart (geminiApiKey)');
      return ModerationResult.clean;
    }
    try {
      final res = await http
          .post(
            Uri.parse('$_endpoint?key=$geminiApiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {
                      'text': 'You are a content moderation filter for a family-friendly travel social app. '
                          'Decide if the text below contains profanity, hate speech, sexual content, '
                          'harassment, or other content inappropriate for a public travel community feed, '
                          'in ANY language (English, Chinese, Malay, or any other).\n'
                          'Reply with EXACTLY one line and nothing else:\n'
                          '- If the text is fine, reply exactly: CLEAN\n'
                          '- If it is NOT fine, reply exactly: FLAGGED: <short reason, under 8 words, in English>\n\n'
                          'Text: $trimmed',
                    },
                  ],
                },
              ],
              'generationConfig': {'temperature': 0, 'maxOutputTokens': 1024},
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        debugPrint('[ContentModerationService] HTTP ${res.statusCode} checking text: ${res.body}');
        return ModerationResult.clean;
      }
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        debugPrint('[ContentModerationService] no candidates checking text: ${res.body}');
        return ModerationResult.clean;
      }
      final parts = (candidates.first as Map)['content']?['parts'] as List?;
      final reply = (parts ?? const []).map((p) => (p as Map)['text'] as String? ?? '').join().trim();
      if (reply.isEmpty) {
        debugPrint('[ContentModerationService] empty reply from Gemini: ${res.body}');
      }
      if (reply.toUpperCase().startsWith('FLAGGED')) {
        final colonIdx = reply.indexOf(':');
        final reason = (colonIdx != -1 && colonIdx + 1 < reply.length) ? reply.substring(colonIdx + 1).trim() : '';
        return ModerationResult(flagged: true, reason: reason.isEmpty ? 'Possible inappropriate content' : reason);
      }
      return ModerationResult.clean;
    } catch (e) {
      debugPrint('[ContentModerationService] error checking text: $e');
      return ModerationResult.clean;
    }
  }
}
