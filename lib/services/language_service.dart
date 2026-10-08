import 'package:flutter/foundation.dart';

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
///
/// A [ChangeNotifier] (not just a plain field) so [TranslatedText] can
/// subscribe directly and retry its translation the instant the language
/// becomes known/changes — a plain field here used to mean a name whose
/// card happened to be built (and never rebuilt again) *before* the
/// profile's first Firestore snapshot arrived would stay untranslated
/// forever, since nothing ever told it to look again. That race is real:
/// MainPage's four tab pages are built once as `const` widgets and kept
/// alive by an IndexedStack, so whichever tab's data loaded fastest (and
/// doesn't keep rebuilding for unrelated reasons, e.g. Explore's
/// Attraction/Restaurant sections, which load once from Firestore and
/// then sit still) was exactly the one most likely to have already built
/// its names before the language code was ready — Hotel cards "worked"
/// mostly by coincidence, picking up the language late only when some
/// other rebuild (favoriting, currency refresh) happened to re-run them.
class LanguageService extends ChangeNotifier {
  LanguageService._();
  static final LanguageService instance = LanguageService._();

  String? _lastKnownLanguageCode;

  /// Null for a signed-out session or before the first profile snapshot
  /// arrives, and '' for "never explicitly chosen" — [TranslatedText]
  /// treats both the same as English (show the plain name, don't
  /// translate).
  String? get lastKnownLanguageCode => _lastKnownLanguageCode;
  set lastKnownLanguageCode(String? value) {
    if (_lastKnownLanguageCode == value) return;
    _lastKnownLanguageCode = value;
    notifyListeners();
  }

  String labelFor(String code) {
    for (final l in kSupportedLanguages) {
      if (l.code == code) return l.label;
    }
    return code.isEmpty ? 'English' : code;
  }
}
