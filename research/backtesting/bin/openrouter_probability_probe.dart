import 'package:tradeforge_backtesting/src/forward/ai_probability_review.dart';
import 'package:tradeforge_backtesting/src/forward/openrouter_probability_client.dart';
import 'package:tradeforge_backtesting/src/forward/tradeforge_env.dart';

Future<void> main() async {
  final client = OpenRouterProbabilityClient.fromEnvironment(
    environment: TradeForgeEnv.load(),
  );
  final request = AiProbabilityReviewRequest(
    signalId: 'PROBE',
    symbol: 'XAUUSD',
    strategy: 'C5',
    side: 'BUY',
    observedAt: DateTime.now().toUtc(),
    entry: 4350,
    stopLoss: 4345,
    takeProfit: 4360,
    rewardRisk: 2,
    marketContext: const <String, Object?>{
      'probe': true,
      'note': 'Connectivity/schema probe only; not a live trade candidate.',
    },
  );
  final review = await client.review(request);
  print(review.toJson());
  if (!review.isAvailable) {
    throw StateError(
      'OpenRouter probability review unavailable: ${review.error}',
    );
  }
}
