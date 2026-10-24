import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Translates a place/restaurant name (as scraped from OpenStreetMap or
/// the `catalog_places` collection, often in its own local script) into
/// English, for permanent storage on the record — see
/// [CatalogRepository]'s doc-writing functions, the only callers.
///
/// The app previously had a RUNTIME translation layer (TranslationService
/// + the TranslatedText widget + an Account Setting language picker) that
/// translated names only for display, leaving the stored data untouched.
/// That layer is no longer present anywhere in `lib/` (confirmed via grep
/// before building this — it's gone, not just broken), so there is
/// currently no other translation happening anywhere in the app. This
/// service is a WRITE-TIME replacement instead: whatever it returns gets
/// saved as the record's own `name` field, which is what every reader
/// (Explore, Saved Items, detail pages, the admin console) sees directly,
/// with no further translation step anywhere else in the pipeline.
///
/// Originally built on the same free Gemini Developer API key as
/// [ContentModerationService], but that key's free tier turned out to
/// cap requests at just **20/day for this project** (confirmed by hitting
/// it directly — see claude/session-2026-10-21-attraction-restaurant-
/// name-translation.md's incident writeup) and, as an LLM with a
/// token-length cap, occasionally returned a reply cut off mid-sentence
/// that got mistaken for a real translation ("Chinese (", "Stat", etc.).
///
/// Switched to the **MyMemory Translation API**
/// (api.mymemory.translated.net) instead: no API key/account at all, a
/// documented free quota of ~5,000 translated words/day per IP (plenty —
/// this service calls it once per place, and the whole ~770-name backfill
/// this project needed was a few thousand words total), and it's a plain
/// machine-translation lookup, not an LLM, so there's no "reply got cut
/// off mid-explanation" failure mode to guard against.
class NameTranslationService {
  NameTranslationService._();
  static final NameTranslationService instance = NameTranslationService._();

  static const String _endpoint = 'https://api.mymemory.translated.net/get';

  // No account/key needed for MyMemory, unlike the Gemini services this
  // project otherwise uses — this is always "configured".
  bool get isConfigured => true;

  /// A place/business name "looks non-English" when it contains any
  /// character from a non-Latin script (CJK, Hiragana/Katakana, Hangul,
  /// Thai, Arabic, Cyrillic). Deliberately NOT a stricter "every
  /// character must be ASCII" check — that would also flag genuinely
  /// fine Latin-script names (accented French/Spanish/Vietnamese names,
  /// "Côte d'Azur" style) that don't need translating at all. Same check
  /// used to survey the live data before building this (38/282
  /// attractions, 732/3760 restaurants flagged).
  static bool looksNonEnglish(String name) {
    return RegExp(r'[一-鿿぀-ヿ゠-ヿ가-힯฀-๿؀-ۿЀ-ӿ]')
        .hasMatch(name);
  }

  /// Guesses a MyMemory source-language code from which non-Latin script
  /// [name] is written in — MyMemory (unlike Gemini) has no "auto-detect
  /// source language" option, so this has to pick one explicitly. Checked
  /// in this order deliberately: Japanese text almost always mixes
  /// Hiragana/Katakana with Kanji (which overlaps the same Unicode block
  /// as Chinese), so Hiragana/Katakana/Hangul must be checked *before*
  /// the plain-CJK fallback, or Japanese/Korean would misdetect as
  /// Chinese. Returns null for anything [looksNonEnglish] wouldn't flag
  /// (shouldn't happen given this is only ever called on flagged names).
  static String? _guessSourceLang(String name) {
    if (RegExp(r'[぀-ヿ゠-ヿ]').hasMatch(name)) return 'ja'; // Hiragana/Katakana
    if (RegExp(r'[가-힯]').hasMatch(name)) return 'ko'; // Hangul
    if (RegExp(r'[一-鿿]').hasMatch(name)) return 'zh-CN'; // CJK Unified Ideographs
    if (RegExp(r'[฀-๿]').hasMatch(name)) return 'th'; // Thai
    if (RegExp(r'[؀-ۿ]').hasMatch(name)) return 'ar'; // Arabic
    if (RegExp(r'[Ѐ-ӿ]').hasMatch(name)) return 'ru'; // Cyrillic
    return null;
  }

  /// Returns an English version of [name], or null if nothing useful
  /// could be produced (no detectable source script, a network error, a
  /// timeout, the day's free quota is used up, or MyMemory simply had no
  /// translation and echoed the original back unchanged) — callers fall
  /// back to keeping the original name rather than lose it. Never throws.
  Future<String?> translateToEnglish(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final sourceLang = _guessSourceLang(trimmed);
    if (sourceLang == null) return null;
    try {
      final uri = Uri.parse(_endpoint).replace(queryParameters: {
        'q': trimmed,
        'langpair': '$sourceLang|en',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        debugPrint('[NameTranslationService] HTTP ${res.statusCode} translating "$trimmed": ${res.body}');
        return null;
      }
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      if (decoded['quotaFinished'] == true) {
        // MyMemory's free daily word quota (anonymous IP-based, ~5,000
        // words/day) is used up for today — nothing to retry, this
        // single place just keeps its original name until it resets.
        debugPrint('[NameTranslationService] MyMemory daily quota finished translating "$trimmed"');
        return null;
      }
      final translated = (decoded['responseData'] as Map?)?['translatedText'] as String?;
      final cleaned = translated?.trim() ?? '';
      if (cleaned.isEmpty) return null;
      // MyMemory echoes the original text back unchanged when it has no
      // real translation for it (rather than erroring) — that's not a
      // successful translation, so treat it the same as "couldn't
      // translate" instead of writing the still-non-English name back as
      // if it were English.
      if (cleaned.toLowerCase() == trimmed.toLowerCase() || looksNonEnglish(cleaned)) return null;
      return cleaned;
    } catch (e) {
      debugPrint('[NameTranslationService] error translating "$trimmed": $e');
      return null;
    }
  }
}
