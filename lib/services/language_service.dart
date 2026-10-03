/// One entry in Account Setting's Language picker (and
/// [TranslationService]'s target-language list). [code] is a Google
/// Cloud Translation target-language code.
class LanguageOption {
  final String code;
  final String label;
  const LanguageOption(this.code, this.label);
}

/// A reasonably-sized set of languages a Malaysian traveller's trip
/// might actually need — not Google Translate's entire ~130-language
/// list, which would make the picker unusably long for what this app
/// needs. Easy to extend later since [TranslationService] accepts any
/// Google-supported code, not just the ones listed here.
const List<LanguageOption> kSupportedLanguages = [
  LanguageOption('en', 'English'),
  LanguageOption('ms', 'Bahasa Malaysia'),
  LanguageOption('zh-CN', 'Chinese (Simplified)'),
  LanguageOption('zh-TW', 'Chinese (Traditional)'),
  LanguageOption('ta', 'Tamil'),
  LanguageOption('ja', 'Japanese'),
  LanguageOption('ko', 'Korean'),
  LanguageOption('th', 'Thai'),
  LanguageOption('vi', 'Vietnamese'),
  LanguageOption('id', 'Indonesian'),
  LanguageOption('fr', 'French'),
  LanguageOption('es', 'Spanish'),
];

/// Keeps the signed-in person's chosen display language (Account Setting
/// > Language, [AppUser.languageCode]) available synchronously to any
/// widget that wants to show a translated name — same pattern as
/// [CurrencyService.lastKnownUserCurrency]: kept current by MainPage's
/// long-lived profile subscription (see bottom_nav.dart) for as long as
/// they're signed in, rather than every [TranslatedText] running its own
/// profile stream just for this.
class LanguageService {
  LanguageService._();
  static final LanguageService instance = LanguageService._();

  /// Null for a signed-out session or before the first profile snapshot
  /// arrives, and '' for "never explicitly chosen" — [TranslatedText]
  /// treats both the same as English (show the plain name, don't
  /// translate).
  String? lastKnownLanguageCode;

  String labelFor(String code) {
    for (final l in kSupportedLanguages) {
      if (l.code == code) return l.label;
    }
    return code.isEmpty ? 'English' : code;
  }
}
