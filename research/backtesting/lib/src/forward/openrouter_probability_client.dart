import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ai_probability_review.dart';

abstract interface class OpenRouterTransport {
  Future<Map<String, dynamic>> postJson(
    Uri uri, {
    required Map<String, String> headers,
    required Map<String, Object?> body,
    required Duration timeout,
  });
}

final class IoOpenRouterTransport implements OpenRouterTransport {
  IoOpenRouterTransport({HttpClient? client})
    : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<Map<String, dynamic>> postJson(
    Uri uri, {
    required Map<String, String> headers,
    required Map<String, Object?> body,
    required Duration timeout,
  }) async {
    final request = await _client.postUrl(uri).timeout(timeout);
    headers.forEach(request.headers.set);
    request.write(jsonEncode(body));
    final response = await request.close().timeout(timeout);
    final text = await utf8.decoder.bind(response).join().timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'OpenRouter HTTP ${response.statusCode}: $text',
        uri: uri,
      );
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('OpenRouter response is not an object.');
    }
    return Map<String, dynamic>.from(decoded);
  }
}

final class OpenRouterProbabilityClient {
  OpenRouterProbabilityClient({
    required this.apiKey,
    this.model = 'google/gemma-4-31b-it:free',
    this.fallbackModels = const <String>[],
    Uri? endpoint,
    OpenRouterTransport? transport,
    this.timeout = const Duration(seconds: 35),
  }) : endpoint =
           endpoint ??
           Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
       _transport = transport ?? IoOpenRouterTransport();

  factory OpenRouterProbabilityClient.fromEnvironment({
    Map<String, String>? environment,
    OpenRouterTransport? transport,
  }) {
    final env = environment ?? Platform.environment;
    final key = env['OPENROUTER_API_KEY']?.trim() ?? '';
    if (key.isEmpty) {
      throw StateError('OPENROUTER_API_KEY is missing.');
    }

    final primary = env['OPENROUTER_MODEL']?.trim().isNotEmpty == true
        ? env['OPENROUTER_MODEL']!.trim()
        : 'google/gemma-4-31b-it:free';
    final fallbacks = (env['OPENROUTER_FALLBACK_MODELS'] ?? '')
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .where((value) => value.endsWith(':free'))
        .where((value) => value != primary)
        .toList(growable: false);
    final timeoutMs =
        int.tryParse(env['OPENROUTER_TIMEOUT_MS']?.trim() ?? '') ?? 35000;

    return OpenRouterProbabilityClient(
      apiKey: key,
      model: primary,
      fallbackModels: fallbacks,
      timeout: Duration(milliseconds: timeoutMs),
      transport: transport,
    );
  }

  final String apiKey;
  final String model;
  final List<String> fallbackModels;
  final Uri endpoint;
  final Duration timeout;
  final OpenRouterTransport _transport;

  List<String> get modelSequence => <String>[
    model,
    ...fallbackModels.where((candidate) => candidate.endsWith(':free')),
  ];

  Future<AiProbabilityReview> review(AiProbabilityReviewRequest request) async {
    Object? lastError;
    for (final candidateModel in modelSequence) {
      try {
        final response = await _transport.postJson(
          endpoint,
          headers: <String, String>{
            HttpHeaders.authorizationHeader: 'Bearer $apiKey',
            HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
            'X-Title': 'TradeForge V2',
          },
          body: <String, Object?>{
            'model': candidateModel,
            'temperature': 0.1,
            'max_tokens': 500,
            'response_format': <String, Object?>{'type': 'json_object'},
            'messages': <Map<String, String>>[
              <String, String>{
                'role': 'system',
                'content':
                    'Return strict JSON. You are a probability estimator, not a trade gate.',
              },
              <String, String>{
                'role': 'user',
                'content': buildAiProbabilityPrompt(request),
              },
            ],
          },
          timeout: timeout,
        );
        return _parseReview(response, request, candidateModel);
      } on HttpException catch (error) {
        lastError = error;
        final status = _httpStatus(error.message);
        if (status == null || !_isRetryableProviderStatus(status)) {
          break;
        }
      } catch (error) {
        lastError = error;
        break;
      }
    }

    // AI failure is deliberately fail-open: the strategy candidate survives.
    return AiProbabilityReview.unavailable(
      model,
      lastError ?? 'No free model available.',
    );
  }

  AiProbabilityReview _parseReview(
    Map<String, dynamic> response,
    AiProbabilityReviewRequest request,
    String requestedModel,
  ) {
    final choices = response['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw const FormatException('OpenRouter response has no choice.');
    }
    final first = Map<String, dynamic>.from(choices.first as Map);
    final message = first['message'];
    if (message is! Map) {
      throw const FormatException('OpenRouter choice has no message.');
    }
    final content = Map<String, dynamic>.from(message)['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const FormatException('OpenRouter message has no content.');
    }
    final decoded = jsonDecode(_stripFence(content));
    if (decoded is! Map) {
      throw const FormatException('AI review JSON is not an object.');
    }
    return AiProbabilityReview.fromModelJson(
      model: response['model']?.toString() ?? requestedModel,
      json: Map<String, dynamic>.from(decoded),
      rewardRisk: request.rewardRisk,
    );
  }

  bool _isRetryableProviderStatus(int statusCode) =>
      statusCode == 404 ||
      statusCode == 408 ||
      statusCode == 429 ||
      statusCode >= 500;

  int? _httpStatus(String message) {
    final match = RegExp(r'OpenRouter HTTP (\d{3})').firstMatch(message);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  String _stripFence(String value) {
    var text = value.trim();
    if (text.startsWith('```')) {
      final firstNewline = text.indexOf('\n');
      if (firstNewline >= 0) {
        text = text.substring(firstNewline + 1);
      }
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3);
      }
    }
    return text.trim();
  }
}
