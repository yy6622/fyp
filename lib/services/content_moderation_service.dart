import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class ModerationResult {
  final bool flagged;
  final String reason;
  const ModerationResult({required this.flagged, required this.reason});

  static const ModerationResult clean = ModerationResult(flagged: false, reason: '');
}

class ContentModerationService {
  ContentModerationService._();
  static final ContentModerationService instance = ContentModerationService._();

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

  Future<ModerationResult> check(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return ModerationResult.clean;
    final hit = localMatch(trimmed);
    if (hit != null) {
      return const ModerationResult(flagged: true, reason: 'Profanity');
    }
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'moderateText',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
      );
      final result = await callable.call({'text': trimmed});
      final data = (result.data as Map).cast<String, dynamic>();
      final flagged = data['flagged'] as bool? ?? false;
      if (!flagged) return ModerationResult.clean;
      final reason = (data['reason'] as String?)?.trim();
      return ModerationResult(flagged: true, reason: (reason == null || reason.isEmpty) ? 'Possible inappropriate content' : reason);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[ContentModerationService] moderateText failed: ${e.code} ${e.message}');
      return ModerationResult.clean;
    } catch (e) {
      debugPrint('[ContentModerationService] error checking text: $e');
      return ModerationResult.clean;
    }
  }
}
