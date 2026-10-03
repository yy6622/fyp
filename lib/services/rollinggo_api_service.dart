import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/secrets.dart';
import '../data/country_gateways.dart';
import '../models/duffel_models.dart';

/// Talks to RollingGo's real hotel data (2M+ hotels, wholesale rates) —
/// Explore's real Hotels data source, used instead of Duffel Stays
/// because Duffel's Hotels/Stays product needs a separate account
/// approval beyond the Flights sandbox token (`duffelApiKey` in
/// secrets.dart keeps powering [DuffelApiService.searchFlights] —
/// nothing about Flights changes). See
/// https://github.com/RollingGo-AI/RollingGo-Hotel-MCP-Global.
///
/// IMPORTANT — unlike Duffel, RollingGo doesn't publish a plain REST
/// API: it's an MCP (Model Context Protocol) server reached over HTTP
/// with JSON-RPC 2.0 request bodies (the same protocol Claude and other
/// AI tools use to call external tools), not a normal `GET`/`POST
/// {json}` REST endpoint. This service speaks that protocol directly
/// (an `initialize` handshake, then a `tools/call` for `searchHotels`)
/// instead of pulling in a full MCP client package, since all this app
/// needs is the one tool.
///
/// [_extractHotels] reads the response shape confirmed by RollingGo's
/// own published example (`hotelInformationList`, with each hotel's
/// price under `price.lowestPrice`/`price.currency`) — a first version
/// of this file guessed at a few plausible key names before that
/// example was found, which is why hotel search silently came back
/// empty against the real server even though the request itself worked
/// (no error — a genuinely empty result list looks identical to "found
/// the array under the wrong key"). The older guessed key names are
/// kept as a fallback in [_extractHotels] in case a different RollingGo
/// deployment/version ever shapes it differently.
class RollingGoApiService {
  RollingGoApiService._();
  static final RollingGoApiService instance = RollingGoApiService._();

  // RollingGo publishes two endpoints for this same MCP server: a
  // China-domestic one (mcp.rollinggo.cn) and this global one. Switch to
  // the `.cn` host instead if the key came from RollingGo's China
  // console rather than https://global.rollinggo.store/apply.
  static const String _base = 'https://mcp.rollinggo.ai/mcp';

  Map<String, String> _headers([String? sessionId]) => {
        'Authorization': 'Bearer $rollingGoApiKey',
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/event-stream',
        if (sessionId != null) 'Mcp-Session-Id': sessionId,
      };

  bool get isConfigured => rollingGoApiKey.isNotEmpty && rollingGoApiKey != 'YOUR_ROLLINGGO_API_KEY_HERE';

  /// Hotel search for [destinationQuery] between [checkIn] and
  /// [checkOut] — same signature/contract as
  /// [DuffelApiService.searchStays] (including the "a bare
  /// [kCountries] name gets swapped for [CountryGateway.hotelPlaceQuery]
  /// first" behaviour), so [CatalogRepository] can call either
  /// interchangeably. [adults]/[rooms] are accepted for that same
  /// interface compatibility but aren't threaded into the `searchHotels`
  /// call below yet — RollingGo's docs never named a guests/occupancy
  /// field, and every call site in this app currently searches with the
  /// defaults anyway, so this was left rather than guessed at.
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
    // An empty list here is ambiguous: it's either a real "no hotels for
    // this search" (fine — the UI already shows that as a plain empty
    // state) or a parsing mismatch against a response shape this app
    // hasn't actually seen yet (already happened once — see the
    // `hotelInformationList` fix in _extractHotels's doc comment).
    // _emptyResultDiagnostic tells the two apart: null means a known key
    // was genuinely found with nothing in it, a non-null message means
    // none of the expected keys were found at all, which this surfaces
    // as a real, specific, visible error (via hotelError in the UI)
    // instead of silently looking identical to a real empty result.
    if (hotels.isEmpty) {
      // Diagnostic-only console log (no UI/behaviour change) — searches
      // for a past checkIn date reportedly come back with hotels while
      // the same destination with a future checkIn date doesn't, which
      // isn't explained by anything _extractHotels/_emptyResultDiagnostic
      // can tell from here. Logging RollingGo's raw payload (it may carry
      // its own `message` explaining an empty-but-known-key result, which
      // _emptyResultDiagnostic currently doesn't surface) is the only way
      // to see why without being able to call RollingGo directly from
      // either sandbox (both are blocked from mcp.rollinggo.ai).
      dynamic payload = result['structuredContent'];
      payload ??= _parsedTextContent(result);
      // ignore: avoid_print
      print('[RollingGo] empty result | place=$resolvedQuery checkIn=${_dateOnly(checkIn)} stayNights=$stayNights | payload: $payload');
      final diagnostic = _emptyResultDiagnostic(result);
      if (diagnostic != null) throw RollingGoApiException(diagnostic);
    } else {
      // Same diagnostic logging for the success case, so a past-date vs
      // future-date search for the same place can be compared side by
      // side in the `flutter run` console.
      // ignore: avoid_print
      print('[RollingGo] place=$resolvedQuery checkIn=${_dateOnly(checkIn)} stayNights=$stayNights -> ${hotels.length} hotels');
    }
    // One oddly-shaped hotel entry shouldn't blank out an otherwise-good
    // result list — skip it and keep the rest, same "degrade, don't
    // crash" approach DuffelApiService takes parsing a third-party
    // response it doesn't fully control.
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

  /// Standard MCP handshake — a server is allowed to require a session
  /// before accepting `tools/call`, so this always runs first (a lenient
  /// server that doesn't need it just gets one extra round trip, which
  /// is cheap and safe; skipping it against a strict server would break
  /// every call). Returns the `Mcp-Session-Id` response header if the
  /// server sent one, or null for a server that doesn't use sessions.
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

  /// The MCP spec has the client send this right after `initialize`
  /// succeeds, before any `tools/call` — no response is expected (it's a
  /// JSON-RPC *notification*, not a request: no `id` field). A lenient
  /// server ignores it; a strict one may refuse `tools/call` without it
  /// first. Best-effort only — a failure here shouldn't block the actual
  /// search, since plenty of MCP servers don't enforce this at all.
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
      // Best-effort — see doc comment above.
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

  /// A streamable-http MCP server may answer with plain `application/json`
  /// or with an `text/event-stream` body (one or more `data: {...}`
  /// frames) — this app only sends one request at a time and only cares
  /// about the final JSON-RPC message, so it takes the last `data:`
  /// line when the body is SSE-framed.
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

  /// MCP tool results carry their payload either as `result.structuredContent`
  /// (the newer, directly-parseable form) or as a JSON string inside
  /// `result.content[0].text` (the original, text-only form) — tried in
  /// that order. The hotel list itself is nested under
  /// `hotelInformationList` — confirmed against RollingGo's own
  /// published example response (`{"message": "Hotel search succeeded",
  /// "hotelInformationList": [{"hotelId": ..., "name": ..., "price":
  /// {"currency": ..., "lowestPrice": ...}, ...}]}` — see
  /// github.com/RollingGo-AI/RollingGo-Hotel-MCP-Global), which is also
  /// exactly what [DuffelStayResult.fromRollingGo] already reads
  /// (hotelId/name/address/starRating/price.lowestPrice/price.currency
  /// all match). The other key names are kept as a fallback in case a
  /// different RollingGo deployment/version ever shapes it differently.
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

  /// See the call site in [searchStays] — null means the empty hotel
  /// list is real (a known key was found, just with nothing in it, or
  /// the payload was itself a bare empty array), non-null means none of
  /// the shapes [_extractHotels] knows how to read were found at all,
  /// so the caller throws this as a concrete, visible error instead of
  /// it looking identical to a genuine zero-result search.
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

/// Thrown by [RollingGoApiService] on a non-2xx response, an MCP-level
/// error, or a request that couldn't be made at all.
class RollingGoApiException implements Exception {
  final String message;
  const RollingGoApiException(this.message);
  @override
  String toString() => message;
}
