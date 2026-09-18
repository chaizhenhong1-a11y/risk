import 'dart:convert';
import 'dart:io';

import 'biquote_market_data.dart';

/// Minimal dependency-free BiQuote REST client.
///
/// SignalR is the continuous tick transport. REST OHLC is the canonical
/// startup/reconnect backfill because it exposes `isOpen`, allowing TradeForge
/// to reject unfinished candles before strategy evaluation.
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
