import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/secrets.dart';
import 'language_service.dart';

/// Translates attraction/restaurant/hotel names (and similar short text)
/// into whatever language the person picked in Account Setting > Language
/// (see [LanguageService]), via the free-tier Gemini API
/// (generativelanguage.googleapis.com — a plain API key from Google AI
/// Studio, NOT Vertex AI, and not the paid Cloud Translation API this used
/// to call). [TranslatedText] is the widget that actually uses this; this
/// class is just the network call + cache.
///
/// Why Gemini instead of a dedicated translation API: it was switched here
/// to get off every Google service that needs a billing account — this
/// app's Vertex AI usage (AI Summarise) hit a billing "dunning"
/// (payment-failed) hold that blocked it outright, and Cloud Translation
/// was on the very same billing account, so it's exactly as exposed to the
/// same problem happening again. The Gemini Developer API key is a
/// separate product with a genuinely free tier (no card on file anywhere),
/// asked in plain language to translate rather than called through a
/// translate-specific endpoint — works just as well for a short place
/// name and sidesteps the whole billing dependency.
///
/// Never throws and never blocks the UI on a slow/failed call — every
/// failure mode (no key configured, network error, bad response) just
/// returns null, which callers treat as "show the plain original text",
/// exactly like [CurrencyService] falling back to an untouched price
/// when rates aren't loaded.
class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent';

  /// What the model replies with when [trimmed] is already in the target
  /// language, or is a proper name/brand with no sensible translation —
  /// told to say this exact word rather than echo the original back, so a
  /// short reply that happens to equal the input isn't mistaken for "the
  /// model didn't understand the instruction".
  static const String _sameMarker = 'SAME';

  /// In-memory only (not persisted to Firestore) — translations are cheap
  /// to re-fetch within a session and this avoids adding another write
  /// path/security rule just to cache strings a handful of users will
  /// ever request in a non-English language. Keyed by "targetLang::text"
  /// so the same place name cached for two different target languages
  /// doesn't collide.
  final Map<String, String?> _cache = {};

  bool get isConfigured => geminiApiKey.isNotEmpty && geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE';

  /// Returns the translated text, or null when there's nothing useful to
  /// show beyond the original — not configured, blank input, a failed
  /// call, or the model itself saying there's nothing to translate (see
  /// [_sameMarker]).
  ///
  /// This used to also hard-skip whenever [targetLang] was English —
  /// reasoned as "most of this app's seed/API text is already in
  /// English, so skip the round-trip for the common case" — but that
  /// broke the exact opposite, very real case: a place pulled from OSM
  /// for a destination in China/Japan/Korea/etc. has its `name` tag in
  /// that place's own script, not English, so a person who set their
  /// language to English and expected THOSE names translated into
  /// English got nothing at all. English is just another target now;
  /// asking the model to judge "is this already in the target language"
  /// per-call (rather than comparing language codes ourselves) still
  /// correctly skips a name that's already in English, or already in
  /// whatever the target language is.
  Future<String?> translate(String text, String targetLang) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (!isConfigured) {
      debugPrint('[TranslationService] skipped "$trimmed" — no Gemini API key configured in secrets.dart (geminiApiKey)');
      return null;
    }
    final target = targetLang.trim();
    if (target.isEmpty) return null;
    final languageName = _languageName(target);
    if (languageName == null) return null;

    final cacheKey = '$target::$trimmed';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

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
                      'text': 'Translate the following short text into $languageName.\n'
                          'If it is already in $languageName, or is a proper name/brand with no '
                          'sensible translation, reply with exactly the single word "$_sameMarker" '
                          'and nothing else. Otherwise reply with ONLY the translation — no quotes, '
                          'no explanation, no original text.\n\n'
                          'Text: $trimmed',
                    },
                  ],
                },
              ],
              'generationConfig': {'temperature': 0, 'maxOutputTokens': 200},
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        // Silent to the UI by design (see class doc), but silent-and-
        // invisible is exactly why "the translator doesn't work" is hard
        // to diagnose — a non-200 here almost always has a clear reason
        // in res.body (bad/restricted key, free-tier rate limit hit —
        // HTTP 429, not 403, if so).
        debugPrint('[TranslationService] HTTP ${res.statusCode} translating "$trimmed" -> $target: ${res.body}');
        _cache[cacheKey] = null;
        return null;
      }
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        // A prompt/response safety block shows up here (candidates
        // present but empty, or a `promptFeedback.blockReason` instead) —
        // vanishingly unlikely for a short place name, but still just
        // "nothing to show" rather than a crash.
        debugPrint('[TranslationService] no candidates translating "$trimmed" -> $target: ${res.body}');
        _cache[cacheKey] = null;
        return null;
      }
      final parts = (candidates.first as Map)['content']?['parts'] as List?;
      final translated = (parts ?? const [])
          .map((p) => (p as Map)['text'] as String? ?? '')
          .join()
          .trim();
      if (translated.isEmpty || translated.toUpperCase() == _sameMarker || translated == trimmed) {
        _cache[cacheKey] = null;
        return null;
      }
      _cache[cacheKey] = translated;
      return translated;
    } catch (e) {
      // Deliberately not cached — a transient network hiccup shouldn't
      // permanently stop this text from ever being retried this session.
      debugPrint('[TranslationService] error translating "$trimmed" -> $target: $e');
      return null;
    }
  }

  /// The plain-English name of [code] the prompt asks for — the model
  /// understands a name like "Traditional Chinese" far more reliably than
  /// it would a bare code, and this also keeps zh-CN/zh-TW unambiguous
  /// (a raw "zh" leaves that to guesswork). Reuses the same labels
  /// Account Setting's own Language picker shows, so there's exactly one
  /// place that maps a code to what it means. Null for a code this app
  /// doesn't actually offer as a target (shouldn't happen — every caller
  /// passes a code from [kSupportedLanguages] — but a stale/garbage value
  /// has nothing sensible to ask the model for).
  String? _languageName(String code) {
    for (final l in kSupportedLanguages) {
      if (l.code == code) return l.label;
    }
    return null;
  }
}
