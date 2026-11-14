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

  // The remote classifier call (OpenAI's Moderation API — a dedicated
  // content-moderation classifier with fixed categories + confidence scores,
  // not free-text LLM judgment, and free to call) runs server-side in the
  // `moderateText` Cloud Function (functions/content_moderation.js), not
  // from this client directly. Two reasons: OpenAI's /v1/moderations
  // endpoint sends no CORS headers, so a browser (Flutter web) request to it
  // is blocked outright before it even leaves the page; and this keeps the
  // OpenAI key out of the client bundle entirely.
  //
  // Obvious profanity is still caught locally first, so moderation still
  // works offline / if the Cloud Function is ever unreachable, and the
  // common case doesn't need a network round-trip at all. The remote
  // classifier then handles everything subtler (hate speech, harassment,
  // sexual content, violence, self-harm, etc.), including other languages.
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
