import 'package:flutter/material.dart';

import '../../services/language_service.dart';
import '../../services/translation_service.dart';

// ---------------------------------------------------------------------
// Drop-in replacement for `Text(name)` on an attraction/restaurant/hotel
// (and similar real-world place) name — shows the plain name until/unless
// a translation is actually useful, then shows "<translated> (<original>)"
// instead. Renders the plain [text] immediately (never a spinner/blank —
// a name should never visibly pop in), and only swaps in the translated
// form once [TranslationService] resolves with something worth showing.
//
// Safe to use everywhere a name is shown (list cards, detail headers,
// detail titles) since it's a no-op — same as a plain Text — whenever no
// language is picked, English is picked, no API key is configured, or
// the text is already in the picked language.
// ---------------------------------------------------------------------
class TranslatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const TranslatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  State<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends State<TranslatedText> {
  String? _translated;
  String? _forLanguage;

  @override
  void initState() {
    super.initState();
    // Listens directly for the language becoming known/changing, rather
    // than only ever re-checking it when something else happens to
    // rebuild this widget (see LanguageService's doc comment for why that
    // used to leave some names — Attraction/Restaurant's in particular —
    // untranslated forever instead of just briefly, until the language
    // loaded).
    LanguageService.instance.addListener(_onLanguageChanged);
    _maybeTranslate();
  }

  @override
  void didUpdateWidget(TranslatedText old) {
    super.didUpdateWidget(old);
    // The name itself changed (a different card reused this element).
    if (old.text != widget.text) {
      _translated = null;
      _maybeTranslate();
    }
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    if (_forLanguage != LanguageService.instance.lastKnownLanguageCode) {
      setState(() => _translated = null);
      _maybeTranslate();
    }
  }

  @override
  void dispose() {
    LanguageService.instance.removeListener(_onLanguageChanged);
    super.dispose();
  }

  Future<void> _maybeTranslate() async {
    final lang = LanguageService.instance.lastKnownLanguageCode;
    _forLanguage = lang;
    if (lang == null || lang.isEmpty) return;
    final result = await TranslationService.instance.translate(widget.text, lang);
    if (mounted && result != null) setState(() => _translated = result);
  }

  @override
  Widget build(BuildContext context) {
    final display = _translated == null ? widget.text : '$_translated (${widget.text})';
    return Text(
      display,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
