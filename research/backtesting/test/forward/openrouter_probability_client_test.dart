import 'dart:async';

import 'package:test/test.dart';

import 'package:tradeforge_backtesting/src/forward/ai_probability_review.dart';
import 'package:tradeforge_backtesting/src/forward/openrouter_probability_client.dart';

final class _FakeTransport implements OpenRouterTransport {
  _FakeTransport(this.response, {this.error});
  final Map<String, dynamic> response;
  final Object? error;
  Map<String, Object?>? lastBody;

  @override
  Future<Map<String, dynamic>> postJson(
    Uri uri, {
    required Map<String, String> headers,
    required Map<String, Object?> body,
    required Duration timeout,
  }) async {
    lastBody = body;
    if (error != null) throw error!;
    return response;
  }
}

AiProbabilityReviewRequest _request() => AiProbabilityReviewRequest(
  signalId: 'C5|2026-09-18T00:30:00Z',
  symbol: 'XAUUSD',
  strategy: 'C5',
  side: 'BUY',
  observedAt: DateTime.utc(2026, 9, 18, 0, 30),
  entry: 4353.404,
  stopLoss: 4348.1513,
  takeProfit: 4363.9093,
  rewardRisk: 2,
  marketContext: const <String, Object?>{
    'h4Regime': 'NEUTRAL',
    'h1Regime': 'BULLISH',
    'm15Regime': 'BEARISH',
  },
);

void main() {
  test(
    'parses probability but calculates expected R deterministically',
    () async {
      final transport = _FakeTransport(<String, dynamic>{
        'model': 'google/gemma-4-31b-it:free',
        'choices': <Object?>[
          <String, Object?>{
            'message': <String, Object?>{
              'content':
                  '{"estimatedWinProbability":0.55,"uncertainty":0.08,"marketRegime":"TRANSITION","summary":"context aligned","riskFlags":["event risk unknown"]}',
            },
          },
        ],
      });
      final client = OpenRouterProbabilityClient(
        apiKey: 'test',
        transport: transport,
      );

      final review = await client.review(_request());

      expect(review.isAvailable, isTrue);
      expect(review.estimatedWinProbability, 0.55);
      expect(review.expectedR, closeTo(0.65, 1e-9));
      expect(review.confidence, AiConfidenceBand.uncalibrated);
      expect(transport.lastBody?['model'], 'google/gemma-4-31b-it:free');
    },
  );

  test('AI outage is fail-open and returns unavailable review', () async {
    final client = OpenRouterProbabilityClient(
      apiKey: 'test',
      transport: _FakeTransport(
        const <String, dynamic>{},
        error: TimeoutException('offline'),
      ),
    );

    final review = await client.review(_request());

    expect(review.availability, AiReviewAvailability.unavailable);
    expect(review.error, contains('offline'));
  });

  test('invalid probability is not promoted into confidence', () async {
    final transport = _FakeTransport(<String, dynamic>{
      'choices': <Object?>[
        <String, Object?>{
          'message': <String, Object?>{
            'content':
                '{"estimatedWinProbability":1.4,"uncertainty":0.1,"marketRegime":"TREND","summary":"x","riskFlags":[]}',
          },
        },
      ],
    });
    final review = await OpenRouterProbabilityClient(
      apiKey: 'test',
      transport: transport,
    ).review(_request());

    expect(review.isAvailable, isTrue);
    expect(review.estimatedWinProbability, isNull);
    expect(review.expectedR, isNull);
    expect(review.confidence, AiConfidenceBand.uncalibrated);
  });
}
