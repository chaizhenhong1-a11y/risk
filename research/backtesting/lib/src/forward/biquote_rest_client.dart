import 'dart:convert';
import 'dart:io';

import 'biquote_market_data.dart';

final class BiQuoteRestClient {
  BiQuoteRestClient({Uri? baseUri, HttpClient? httpClient})
    : baseUri = baseUri ?? Uri.parse('https://biquote.io'),
      _httpClient = httpClient ?? HttpClient();

  final Uri baseUri;
  final HttpClient _httpClient;

  Future<BiQuoteTick> latestTick(String symbol) async {
    final json = await _getJson(
      '/api/$symbol',
      query: const {'allowStale': 'false'},
    );
    return BiQuoteTick.fromJson(json);
  }

  /// Returns null only for BiQuote's explicit "no tick data available" 404.
  /// Transport/auth/server failures remain errors and are not disguised as a
  /// closed market.
  Future<BiQuoteTick?> latestTickOrNull(String symbol) async {
    try {
      return await latestTick(symbol);
    } on HttpException catch (error) {
      if (error.message.startsWith('BiQuote 404:') &&
          error.message.contains('No tick data available')) {
        return null;
      }
      rethrow;
    }
  }

  Future<BiQuoteOhlcResponse> closedBars({
    required String symbol,
    required BiQuoteTimeframe timeframe,
    int limit = 500,
  }) async {
    if (limit < 1 || limit > 1000) {
      throw RangeError.range(limit, 1, 1000, 'limit');
    }
    final json = await _getJson(
      '/api/$symbol/ohlc',
      query: {'interval': timeframe.apiValue, 'limit': '$limit'},
    );
    return const BiQuoteOhlcParser().parse(json, timeframe: timeframe);
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = baseUri.replace(path: path, queryParameters: query);
    final request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('BiQuote ${response.statusCode}: $body', uri: uri);
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('BiQuote response is not a JSON object');
    }
    return Map<String, dynamic>.from(decoded);
  }

  void close() => _httpClient.close(force: true);
}
