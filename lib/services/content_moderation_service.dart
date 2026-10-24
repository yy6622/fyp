import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/secrets.dart';

/// Result of a [ContentModerationService.check] call.
class ModerationResult {
  final bool flagged;
  final String reason;
  const ModerationResult({required this.flagged, required this.reason});

  static const ModerationResult clean = ModerationResult(flagged: false, reason: '');
}

/// Checks user-submitted text (currently: Community post titles/
/// descriptions — see [CommunityRepository.createPost]) for profanity,
/// hate speech, harassment or other content inappropriate for a public
/// travel feed, BEFORE it goes live.
///
/// Uses the same free-tier Gemini Developer API key the AI Summarise/
/// group-itinerary features call (generativelanguage.googleapis.com — a
/// plain API key from Google AI Studio, no billing account) — asked, in
/// plain language, to
/// classify the text, rather than a dedicated paid moderation API
/// (Perspective/Azure Content Moderator/etc. all exist, but either need
/// their own signup+key or a billing account this project deliberately
/// avoids after getting burned by one already). Multilingual for free, since Gemini
/// reads Chinese/Malay/etc. profanity just as well as English, unlike a
/// plain hardcoded bad-word list.
///
/// A flagged result does NOT block the post outright — see
/// [CommunityRepository.createPost] — it's saved with `autoFlagged: true`
/// and held out of the public feed until an admin approves or rejects it
/// in admin/content-moderation.html, reusing the exact same
/// "reported content" queue a human tapping "Report post" already feeds.
/// A human report stays the backstop for anything this misses.
///
/// Fails OPEN, not closed: no key configured, a network error, a timeout,
/// or a response this can't parse all just return [ModerationResult.clean]
/// rather than holding back a real person's post over an infrastructure
/// hiccup. This is a moderation *aid*, not a hard gate.
class ContentModerationService {
  ContentModerationService._();
  static final ContentModerationService instance = ContentModerationService._();

  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent';

  bool get isConfigured => geminiApiKey.isNotEmpty && geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE';

  Future<ModerationResult> check(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return ModerationResult.clean;
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
              'generationConfig': {'temperature': 0, 'maxOutputTokens': 60},
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        // Silent-to-the-UI by design
        // (see class doc — never blocks a post), but a logged reason makes
        // "why didn't this get flagged" diagnosable (a bad/restricted key,
        // or HTTP 429 free-tier rate limiting).
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
      if (reply.toUpperCase().startsWith('FLAGGED')) {
        final colonIdx = reply.indexOf(':');
        final reason = (colonIdx != -1 && colonIdx + 1 < reply.length) ? reply.substring(colonIdx + 1).trim() : '';
        return ModerationResult(flagged: true, reason: reason.isEmpty ? 'Possible inappropriate content' : reason);
      }
      return ModerationResult.clean;
    } catch (e) {
      // Deliberately not cached/retried — see class doc, fails open.
      debugPrint('[ContentModerationService] error checking text: $e');
      return ModerationResult.clean;
    }
  }
}
