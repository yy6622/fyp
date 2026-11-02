import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NameTranslationService {
  NameTranslationService._();
  static final NameTranslationService instance = NameTranslationService._();

  static const String _endpoint = 'https://api.mymemory.translated.net/get';

  bool get isConfigured => true;

  static bool looksNonEnglish(String name) {
    return RegExp(r'[一-鿿぀-ヿ゠-ヿ가-힯฀-๿؀-ۿЀ-ӿ]')
        .hasMatch(name);
  }

  static String? _guessSourceLang(String name) {
    if (RegExp(r'[぀-ヿ゠-ヿ]').hasMatch(name)) return 'ja'; // Hiragana/Katakana
    if (RegExp(r'[가-힯]').hasMatch(name)) return 'ko'; // Hangul
    if (RegExp(r'[一-鿿]').hasMatch(name)) return 'zh-CN'; // CJK Unified Ideographs
    if (RegExp(r'[฀-๿]').hasMatch(name)) return 'th'; // Thai
    if (RegExp(r'[؀-ۿ]').hasMatch(name)) return 'ar'; // Arabic
    if (RegExp(r'[Ѐ-ӿ]').hasMatch(name)) return 'ru'; // Cyrillic
    return null;
  }

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
        debugPrint('[NameTranslationService] MyMemory daily quota finished translating "$trimmed"');
        return null;
      }
      final translated = (decoded['responseData'] as Map?)?['translatedText'] as String?;
      final cleaned = translated?.trim() ?? '';
      if (cleaned.isEmpty) return null;
      if (cleaned.toLowerCase() == trimmed.toLowerCase() || looksNonEnglish(cleaned)) return null;
      return cleaned;
    } catch (e) {
      debugPrint('[NameTranslationService] error translating "$trimmed": $e');
      return null;
    }
  }
}
