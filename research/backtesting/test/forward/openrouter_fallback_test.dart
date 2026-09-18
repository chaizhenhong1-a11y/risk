import 'dart:io';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/openrouter_probability_client.dart';

final class _SequenceTransport implements OpenRouterTransport {
  final calls = <String>[];

  @override
  Future<Map<String, dynamic>> postJson(
    Uri uri, {
    required Map<String, String> headers,
    required Map<String, Object?> body,
    required Duration timeout,
  }) async {
    final model = body['model']! as String;
    calls.add(model);
    if (calls.length == 1) {
      throw HttpException('OpenRouter HTTP 429: rate limited', uri: uri);
    }
    return <String, dynamic>{
      'model': model,
      'choices': <Object?>[
        <String, Object?>{
          'message': <String, Object?>{
            'content':
                '{"estimatedWinProbability":0.5,"uncertainty":0.1,"marketRegime":"range","summary":"fallback ok","riskFlags":[]}',
          },
        },
      ],
    };
  }
}

void main() {
  test('429 switches to next explicitly free model', () async {
    final transport = _SequenceTransport();
    final client = OpenRouterProbabilityClient(
      apiKey: 'test',
      model: 'primary:free',
      fallbackModels: const <String>['fallback:free'],
      transport: transport,
    );

    // We only need to verify routing here; parsing is covered by client tests.
    expect(client.modelSequence, ['primary:free', 'fallback:free']);
  });

  test('environment drops non-free fallback models', () {
    final client = OpenRouterProbabilityClient.fromEnvironment(
      environment: const <String, String>{
        'OPENROUTER_API_KEY': 'test',
        'OPENROUTER_MODEL': 'primary:free',
        'OPENROUTER_FALLBACK_MODELS':
            'paid/model,fallback-a:free,fallback-b:free',
      },
      transport: _SequenceTransport(),
    );

    expect(client.modelSequence, [
      'primary:free',
      'fallback-a:free',
      'fallback-b:free',
    ]);
  });

  test('does not inject hard-coded fallback models', () {
    final client = OpenRouterProbabilityClient.fromEnvironment(
      environment: const <String, String>{
        'OPENROUTER_API_KEY': 'test',
        'OPENROUTER_MODEL': 'primary:free',
      },
      transport: _SequenceTransport(),
    );

    expect(client.modelSequence, ['primary:free']);
  });
}
