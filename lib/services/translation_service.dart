import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/secrets.dart';

/// Translates attraction/restaurant/hotel names (and similar short text)
/// into whatever language the person picked in Account Setting > Language
/// (see [LanguageService]), via the Google Cloud Translation API v2 REST
/// endpoint. [TranslatedText] is the widget that actually uses this; this
/// class is just the network call + cache.
///
/// Never throws and never blocks the UI on a slow/failed call — every
/// failure mode (no key configured, network error, bad response) just
/// returns null, which callers treat as "show the plain original text",
/// exactly like [CurrencyService] falling back to an untouched price
/// when rates aren't loaded.
class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  static const String _endpoint = 'https://translation.googleapis.com/language/translate2';

  /// In-memory only (not persisted to Firestore) — translations are cheap
  /// to re-fetch within a session and this avoids adding another write
  /// path/security rule just to cache strings a handful of users will
  /// ever request in a non-English language. Keyed by "targetLang::text"
  /// so the same place name cached for two different target languages
  /// doesn't collide.
  final Map<String, String?> _cache = {};

  bool get isConfigured => googleTranslateApiKey.isNotEmpty && googleTranslateApiKey != 'YOUR_GOOGLE_TRANSLATE_API_KEY_HERE';

  /// Returns the translated text, or null when there's nothing useful to
  /// show beyond the original — not configured, blank input, a plain
  /// English target (the vast majority of this app's seed/API text is
  /// already in English, so skip the network round-trip for the common
  /// case), a failed call, or Google's own detected source language
  /// already matching [targetLang] (comparing just the base code before
  /// a "-", so "zh" and "zh-CN" count as the same language — nothing to
  /// usefully translate there).
  Future<String?> translate(String text, String targetLang) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (!isConfigured) {
      debugPrint('[TranslationService] skipped "$trimmed" — no Google Translate API key configured in secrets.dart');
      return null;
    }
    final target = targetLang.trim();
    if (target.isEmpty || _base(target) == 'en') return null;

    final cacheKey = '$target::$trimmed';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    try {
      final res = await http
          .post(
            Uri.parse('$_endpoint?key=$googleTranslateApiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'q': trimmed, 'target': target, 'format': 'text'}),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        // Silent to the UI by design (see class doc), but silent-and-
        // invisible is exactly why "the translator doesn't work" is hard
        // to diagnose — this is almost always either the Cloud
        // Translation API not being enabled on this key's GCP project, or
        // billing not being set up for it (Translation API has no free
        // tier), both of which show up here as a 403 with a clear
        // message in res.body.
        debugPrint('[TranslationService] HTTP ${res.statusCode} translating "$trimmed" -> $target: ${res.body}');
        _cache[cacheKey] = null;
        return null;
      }
      final decoded = jsonDecode(res.body);
      final translations = decoded['data']?['translations'] as List?;
      if (translations == null || translations.isEmpty) {
        _cache[cacheKey] = null;
        return null;
      }
      final first = translations.first as Map;
      final detectedSource = (first['detectedSourceLanguage'] as String?) ?? '';
      final translated = (first['translatedText'] as String?) ?? '';
      // Same language either side, Google just handed the text back
      // unchanged (e.g. a proper noun it couldn't translate), or the
      // name's own original language is English — hotel/attraction/
      // restaurant names that are already in English are usually a
      // brand name as-is (e.g. "Hilton Kuala Lumpur"), and converting
      // those reads as wrong rather than helpful, so they stay plain
      // English no matter what display language is picked. Only a
      // genuinely non-English original name gets the "translated
      // (original)" treatment.
      if (translated.isEmpty || _base(detectedSource) == _base(target) || _base(detectedSource) == 'en' || translated == trimmed) {
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

  /// "zh-CN" -> "zh", "en" -> "en" — Google's detected-source codes and
  /// this app's target codes aren't always written with the same region
  /// suffix, so compare just the base language.
  String _base(String code) => code.split('-').first.toLowerCase();
}
