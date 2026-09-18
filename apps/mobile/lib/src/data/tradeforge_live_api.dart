import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/tradeforge_live_state.dart';

final class TradeForgeLiveApi {
  TradeForgeLiveApi({
    http.Client? client,
    Uri? endpoint,
  })  : _client = client ?? http.Client(),
        endpoint = endpoint ?? Uri.parse('http://127.0.0.1:8787/api/live');

  final http.Client _client;
  final Uri endpoint;

  Future<TradeForgeLiveState> fetch() async {
    final response = await _client.get(endpoint, headers: const {
      'Accept': 'application/json'
    }).timeout(const Duration(seconds: 3));

    if (response.statusCode != 200) {
      throw StateError('Live API returned HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Live API response is not an object');
    }
    return TradeForgeLiveState.fromJson(Map<String, dynamic>.from(decoded));
  }

  void close() => _client.close();
}
