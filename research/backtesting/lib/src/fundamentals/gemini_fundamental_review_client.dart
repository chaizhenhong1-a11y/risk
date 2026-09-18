import 'dart:convert';
import 'dart:io';

import '../forward/tradeforge_env.dart';
import 'gemini_fundamental_review.dart';

abstract interface class GeminiFundamentalTransport {
  Future<Map<String, dynamic>> postJson(
    Uri uri,
    Map<String, dynamic> body, {
    required Duration timeout,
  });
}

final class IoGeminiFundamentalTransport implements GeminiFundamentalTransport {
  IoGeminiFundamentalTransport({HttpClient? client})
    : _client = client ?? HttpClient();
  final HttpClient _client;

  @override
  Future<Map<String, dynamic>> postJson(
    Uri uri,
    Map<String, dynamic> body, {
    required Duration timeout,
  }) async {
    final request = await _client.postUrl(uri).timeout(timeout);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close().timeout(timeout);
    final text = await utf8.decoder.bind(response).join().timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Gemini HTTP ${response.statusCode}: $text',
        uri: uri,
      );
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('Gemini response is not an object.');
    }
    return Map<String, dynamic>.from(decoded);
  }
}

final class GeminiFundamentalReviewClient {
  GeminiFundamentalReviewClient({
    GeminiFundamentalTransport? transport,
    this.timeout = const Duration(seconds: 20),
  }) : _transport = transport ?? IoGeminiFundamentalTransport();

  final GeminiFundamentalTransport _transport;
  final Duration timeout;

  Future<GeminiFundamentalReview> review({
    required Map<String, dynamic> candidate,
    required Map<String, dynamic> economicCalendar,
    required Map<String, dynamic> newsContext,
  }) async {
    final env = TradeForgeEnv.load();
    final key = env['GEMINI_API_KEY']?.trim();
    final configured = env['GEMINI_MODEL']?.trim();
    final model = configured != null && configured.isNotEmpty
        ? configured
        : 'gemini-3.5-flash-lite';
    if (key == null || key.isEmpty) {
      return GeminiFundamentalReview.unavailable(
        model: model,
        reason: 'GEMINI_API_KEY missing',
      );
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$model:generateContent',
    ).replace(queryParameters: {'key': key});

    try {
      final response = await _transport.postJson(
        uri,
        _body(candidate, economicCalendar, newsContext),
        timeout: timeout,
      );
      return _parse(response, model);
    } catch (error) {
      return GeminiFundamentalReview.unavailable(
        model: model,
        reason: '$error',
      );
    }
  }

  Map<String, dynamic> _body(
    Map<String, dynamic> candidate,
    Map<String, dynamic> calendar,
    Map<String, dynamic> news,
  ) {
    final prompt =
        """
You are TradeForge's XAUUSD fundamental/news reviewer.
The trading strategy has already produced a candidate. You are NOT a trade gate.
Never invalidate, delete, approve, reject, or replace the strategy signal.
Use ONLY the supplied calendar/news facts. Do not invent current events.
Classify event/news risk around this candidate as normal, caution, or high_risk.
goldBias must be bullish, bearish, mixed, or unclear.
Focus on gold-relevant facts: Fed/rates, inflation, US labour, USD, Treasury/yields,
geopolitics, tariffs/sanctions, safe-haven shocks, and directly relevant gold news.
Ignore weakly related company/mining-stock articles unless they materially affect spot gold.
Explain briefly and name relevant factor titles/names from supplied facts.

CANDIDATE:
${jsonEncode(candidate)}

ECONOMIC_CALENDAR:
${jsonEncode(calendar)}

NEWS_CONTEXT:
${jsonEncode(news)}
""";
    return {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.1,
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'risk': {
              'type': 'STRING',
              'enum': ['normal', 'caution', 'high_risk'],
            },
            'goldBias': {
              'type': 'STRING',
              'enum': ['bullish', 'bearish', 'mixed', 'unclear'],
            },
            'summary': {'type': 'STRING'},
            'relevantFactors': {
              'type': 'ARRAY',
              'items': {'type': 'STRING'},
            },
          },
          'required': ['risk', 'goldBias', 'summary', 'relevantFactors'],
        },
      },
    };
  }

  GeminiFundamentalReview _parse(Map<String, dynamic> response, String model) {
    final candidates = response['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const FormatException('Gemini returned no candidates.');
    }
    final first = candidates.first;
    if (first is! Map) {
      throw const FormatException('Invalid Gemini candidate.');
    }
    final content = first['content'];
    if (content is! Map || content['parts'] is! List) {
      throw const FormatException('Gemini content missing.');
    }
    final text = (content['parts'] as List)
        .whereType<Map>()
        .map((p) => p['text'])
        .whereType<String>()
        .join();
    if (text.isEmpty) throw const FormatException('Gemini text missing.');
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('Gemini JSON is not an object.');
    }
    final json = Map<String, dynamic>.from(decoded);
    final risk = switch (json['risk']) {
      'high_risk' => FundamentalRisk.highRisk,
      'caution' => FundamentalRisk.caution,
      _ => FundamentalRisk.normal,
    };
    final factors = json['relevantFactors'] is List
        ? (json['relevantFactors'] as List)
              .map((e) => '$e')
              .toList(growable: false)
        : const <String>[];
    return GeminiFundamentalReview(
      available: true,
      risk: risk,
      goldBias: '${json['goldBias'] ?? 'unclear'}',
      summary: '${json['summary'] ?? ''}',
      relevantFactors: factors,
      model: model,
    );
  }
}
