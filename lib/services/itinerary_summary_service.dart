import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/secrets.dart';
import '../models/day_plan_models.dart';

class ItinerarySummaryService {
  ItinerarySummaryService._();
  static final ItinerarySummaryService instance = ItinerarySummaryService._();

  static const String _endpoint = 'https://api.openai.com/v1/chat/completions';

  static const String _model = 'gpt-4o-mini';

  bool get isConfigured => openAiApiKey.isNotEmpty && openAiApiKey != 'YOUR_OPENAI_API_KEY_HERE';

  String _planText(String destination, List<DayPlan> days) {
    final buffer = StringBuffer('Destination: $destination\n');
    for (final day in days) {
      if (day.items.isEmpty) continue;
      buffer.writeln('Day ${day.day}:');
      for (final item in day.items) {
        final where = item.location.trim().isEmpty ? '' : ' at ${item.location.trim()}';
        buffer.writeln('- ${item.time} ${item.label}$where');
      }
    }
    return buffer.toString();
  }

  Future<String?> summarise(String destination, List<DayPlan> days) async {
    if (!isConfigured) {
      debugPrint('[ItinerarySummaryService] skipped — no OpenAI API key configured in secrets.dart (openAiApiKey)');
      return null;
    }
    if (days.every((d) => d.items.isEmpty)) return null;
    final planText = _planText(destination, days);
    try {
      final res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $openAiApiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {
                  'role': 'system',
                  'content': 'You write short, friendly social-media post descriptions for a travel app\'s '
                      'community feed. Be specific about real highlights from the itinerary given to you — '
                      'never invent places or activities that aren\'t listed. Reply with the description '
                      'text only: 2-4 sentences, under 60 words, plain text, no markdown, no hashtags, no '
                      'quotation marks around the whole thing.',
                },
                {'role': 'user', 'content': planText},
              ],
              'temperature': 0.6,
              'max_tokens': 120,
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        debugPrint('[ItinerarySummaryService] HTTP ${res.statusCode}: ${res.body}');
        return null;
      }
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List?;
      final content = (choices != null && choices.isNotEmpty) ? ((choices.first as Map)['message']?['content'] as String?) : null;
      final reply = content?.trim() ?? '';
      return reply.isEmpty ? null : reply;
    } catch (e) {
      debugPrint('[ItinerarySummaryService] error: $e');
      return null;
    }
  }
}
