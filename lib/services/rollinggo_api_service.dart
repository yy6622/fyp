import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/secrets.dart';
import '../data/country_gateways.dart';
import '../models/duffel_models.dart';

class RollingGoApiService {
  RollingGoApiService._();
  static final RollingGoApiService instance = RollingGoApiService._();

  static const String _base = 'https://mcp.rollinggo.ai/mcp';

  Map<String, String> _headers([String? sessionId]) => {
        'Authorization': 'Bearer $rollingGoApiKey',
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/event-stream',
        if (sessionId != null) 'Mcp-Session-Id': sessionId,
      };

  bool get isConfigured => rollingGoApiKey.isNotEmpty && rollingGoApiKey != 'YOUR_ROLLINGGO_API_KEY_HERE';

  Future<List<DuffelStayResult>> searchStays({
    required String destinationQuery,
    required DateTime checkIn,
    required DateTime checkOut,
    int adults = 1,
    int rooms = 1,
  }) async {
    if (!isConfigured) {
      throw const RollingGoApiException('RollingGo API key is not set yet — see lib/config/secrets.dart.');
    }
    final resolvedQuery = kCountryGateways[destinationQuery.trim().toLowerCase()]?.hotelPlaceQuery ?? destinationQuery;
    final stayNights = checkOut.difference(checkIn).inDays.clamp(1, 30);

    final sessionId = await _initialize();
    final result = await _callTool(
      'searchHotels',
      {
        'originQuery': '$resolvedQuery hotels',
        'place': resolvedQuery,
        'placeType': 'City',
        'checkInParam': {'checkInDate': _dateOnly(checkIn), 'stayNights': stayNights},
        'size': 15,
      },
      sessionId,
    );

    final hotels = _extractHotels(result);
    if (hotels.isEmpty) {
      dynamic payload = result['structuredContent'];
      payload ??= _parsedTextContent(result);
      // ignore: avoid_print
      print('[RollingGo] empty result | place=$resolvedQuery checkIn=${_dateOnly(checkIn)} stayNights=$stayNights | payload: $payload');
      final diagnostic = _emptyResultDiagnostic(result);
      if (diagnostic != null) throw RollingGoApiException(diagnostic);
    } else {
      print('[RollingGo] place=$resolvedQuery checkIn=${_dateOnly(checkIn)} stayNights=$stayNights -> ${hotels.length} hotels');
    }
    final parsed = <DuffelStayResult>[];
    for (final h in hotels) {
      try {
        parsed.add(DuffelStayResult.fromRollingGo(h, checkIn: checkIn, checkOut: checkOut));
      } catch (_) {
        continue;
      }
    }
    return parsed;
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<String?> _initialize() async {
    http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(_base),
            headers: _headers(),
            body: jsonEncode({
              'jsonrpc': '2.0',
              'id': 0,
              'method': 'initialize',
              'params': {
                'protocolVersion': '2024-11-05',
                'capabilities': <String, dynamic>{},
                'clientInfo': {'name': 'voya-app', 'version': '1.0.0'},
              },
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw RollingGoApiException('Could not reach RollingGo: $e');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw RollingGoApiException('RollingGo request failed (${res.statusCode}).');
    }
    final sessionId = res.headers['mcp-session-id'];
    await _sendInitializedNotification(sessionId);
    return sessionId;
  }

  Future<void> _sendInitializedNotification(String? sessionId) async {
    try {
      await http
          .post(
            Uri.parse(_base),
            headers: _headers(sessionId),
            body: jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
    }
  }

  Future<Map<String, dynamic>> _callTool(String name, Map<String, dynamic> arguments, String? sessionId) async {
    http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(_base),
            headers: _headers(sessionId),
            body: jsonEncode({
              'jsonrpc': '2.0',
              'id': 1,
              'method': 'tools/call',
              'params': {'name': name, 'arguments': arguments},
            }),
          )
          .timeout(const Duration(seconds: 25));
    } catch (e) {
      throw RollingGoApiException('Could not reach RollingGo: $e');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw RollingGoApiException('RollingGo request failed (${res.statusCode}).');
    }

    final envelope = _decodeJsonRpcBody(res);
    if (envelope == null) {
      throw const RollingGoApiException('Unexpected response from RollingGo.');
    }
    if (envelope['error'] != null) {
      final err = envelope['error'];
      final msg = err is Map ? (err['message'] as String?) : null;
      throw RollingGoApiException(msg ?? 'RollingGo request failed.');
    }
    final result = envelope['result'];
    if (result is! Map) throw const RollingGoApiException('Unexpected response from RollingGo.');
    final casted = result.cast<String, dynamic>();
    if (casted['isError'] == true) {
      throw RollingGoApiException(_textFromContent(casted) ?? 'RollingGo could not complete that search.');
    }
    return casted;
  }

  Map<String, dynamic>? _decodeJsonRpcBody(http.Response res) {
    final body = res.body.trim();
    if (body.isEmpty) return null;
    final contentType = res.headers['content-type'] ?? '';
    try {
      if (contentType.contains('text/event-stream')) {
        final dataLines = body.split('\n').where((l) => l.startsWith('data:')).map((l) => l.substring(5).trim()).where((l) => l.isNotEmpty).toList();
        if (dataLines.isEmpty) return null;
        final decoded = jsonDecode(dataLines.last);
        return decoded is Map ? decoded.cast<String, dynamic>() : null;
      }
      final decoded = jsonDecode(body);
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _extractHotels(Map<String, dynamic> result) {
    dynamic payload = result['structuredContent'];
    payload ??= _parsedTextContent(result);
    if (payload == null) return const [];
    if (payload is List) return payload.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    if (payload is Map) {
      for (final key in ['hotelInformationList', 'hotels', 'results', 'data', 'items']) {
        final v = payload[key];
        if (v is List) return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
    }
    return const [];
  }

  String? _emptyResultDiagnostic(Map<String, dynamic> result) {
    dynamic payload = result['structuredContent'];
    payload ??= _parsedTextContent(result);
    if (payload == null) {
      return 'RollingGo response had no structuredContent and no parseable content[].text — raw keys: ${result.keys.toList()}.';
    }
    if (payload is List) return null;
    if (payload is Map) {
      for (final key in ['hotelInformationList', 'hotels', 'results', 'data', 'items']) {
        if (payload.containsKey(key)) return null;
      }
      final message = payload['message'];
      return 'RollingGo payload had none of the expected hotel-list keys — payload keys: ${payload.keys.toList()}'
          '${message != null ? ', message: $message' : ''}.';
    }
    return 'RollingGo payload was an unexpected type: ${payload.runtimeType}.';
  }

  dynamic _parsedTextContent(Map<String, dynamic> result) {
    final text = _textFromContent(result);
    if (text == null) return null;
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

  String? _textFromContent(Map<String, dynamic> result) {
    final content = result['content'];
    if (content is! List) return null;
    for (final item in content) {
      if (item is Map && item['type'] == 'text' && item['text'] is String) return item['text'] as String;
    }
    return null;
  }
}

class RollingGoApiException implements Exception {
  final String message;
  const RollingGoApiException(this.message);
  @override
  String toString() => message;
}
