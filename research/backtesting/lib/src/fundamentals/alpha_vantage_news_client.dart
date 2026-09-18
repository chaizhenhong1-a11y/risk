import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'gold_news_context.dart';
import '../forward/tradeforge_env.dart';

abstract interface class AlphaVantageNewsTransport {
  Future<Map<String, dynamic>> getJson(Uri uri, {required Duration timeout});
}

final class IoAlphaVantageNewsTransport implements AlphaVantageNewsTransport {
  IoAlphaVantageNewsTransport({HttpClient? client})
    : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    required Duration timeout,
  }) async {
    final request = await _client.getUrl(uri).timeout(timeout);
    final response = await request.close().timeout(timeout);
    final body = await utf8.decoder.bind(response).join().timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Alpha Vantage HTTP ${response.statusCode}: $body',
        uri: uri,
      );
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Alpha Vantage response is not an object.');
    }
    return Map<String, dynamic>.from(decoded);
  }
}

final class AlphaVantageNewsClient {
  AlphaVantageNewsClient({
    AlphaVantageNewsTransport? transport,
    Uri? endpoint,
    this.timeout = const Duration(seconds: 12),
  }) : _transport = transport ?? IoAlphaVantageNewsTransport(),
       endpoint = endpoint ?? Uri.parse('https://www.alphavantage.co/query');

  final AlphaVantageNewsTransport _transport;
  final Uri endpoint;
  final Duration timeout;

  Future<GoldNewsContext> loadGoldNews({
    required DateTime nowUtc,
    Duration lookBack = const Duration(hours: 12),
    int limit = 50,
  }) async {
    final key = TradeForgeEnv.load()['ALPHA_VANTAGE_API_KEY'];
    if (key == null || key.trim().isEmpty) {
      return GoldNewsContext(
        observedAtUtc: nowUtc.toUtc(),
        items: const [],
        availability: GoldNewsAvailability.unavailable,
        provider: 'alpha_vantage',
        reason: 'ALPHA_VANTAGE_API_KEY missing',
      );
    }

    final uri = endpoint.replace(
      queryParameters: <String, String>{
        'function': 'NEWS_SENTIMENT',
        'tickers': 'FOREX:USD',
        'time_from': _apiTime(nowUtc.toUtc().subtract(lookBack)),
        'sort': 'LATEST',
        'limit': '$limit',
        'apikey': key,
      },
    );

    try {
      final json = await _transport.getJson(uri, timeout: timeout);
      final providerMessage =
          json['Information'] ?? json['Note'] ?? json['Error Message'];
      if (providerMessage != null) {
        return GoldNewsContext(
          observedAtUtc: nowUtc.toUtc(),
          items: const [],
          availability: GoldNewsAvailability.unavailable,
          provider: 'alpha_vantage',
          reason: providerMessage.toString(),
        );
      }

      final feed = json['feed'];
      final items = <GoldNewsItem>[];
      if (feed is List) {
        for (final raw in feed) {
          if (raw is! Map) continue;
          final map = Map<String, dynamic>.from(raw);
          final published = _parseTime(map['time_published']?.toString());
          if (published == null) continue;

          final topics = <String>[];
          final rawTopics = map['topics'];
          if (rawTopics is List) {
            for (final rawTopic in rawTopics) {
              if (rawTopic is Map && rawTopic['topic'] != null) {
                topics.add(rawTopic['topic'].toString());
              }
            }
          }

          items.add(
            GoldNewsItem(
              title: (map['title'] ?? '').toString(),
              publishedAtUtc: published,
              source: (map['source'] ?? '').toString(),
              url: (map['url'] ?? '').toString(),
              summary: (map['summary'] ?? '').toString(),
              topics: List<String>.unmodifiable(topics),
              overallSentimentScore: double.tryParse(
                '${map['overall_sentiment_score'] ?? ''}',
              ),
            ),
          );
        }
      }

      items.sort((a, b) => b.publishedAtUtc.compareTo(a.publishedAtUtc));
      return GoldNewsContext(
        observedAtUtc: nowUtc.toUtc(),
        items: List<GoldNewsItem>.unmodifiable(items),
        availability: GoldNewsAvailability.available,
        provider: 'alpha_vantage',
      );
    } catch (error) {
      return GoldNewsContext(
        observedAtUtc: nowUtc.toUtc(),
        items: const [],
        availability: GoldNewsAvailability.unavailable,
        provider: 'alpha_vantage',
        reason: '$error',
      );
    }
  }

  String _apiTime(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}T'
        '${two(value.hour)}${two(value.minute)}';
  }

  DateTime? _parseTime(String? value) {
    if (value == null || value.length < 13) return null;
    final compact = value.replaceAll('T', '');
    if (compact.length < 12) return null;
    try {
      return DateTime.utc(
        int.parse(compact.substring(0, 4)),
        int.parse(compact.substring(4, 6)),
        int.parse(compact.substring(6, 8)),
        int.parse(compact.substring(8, 10)),
        int.parse(compact.substring(10, 12)),
        compact.length >= 14 ? int.parse(compact.substring(12, 14)) : 0,
      );
    } catch (_) {
      return null;
    }
  }
}
