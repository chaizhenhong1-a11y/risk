import 'paper_candle.dart';
import 'paper_opportunity_detector.dart';
import 'paper_strategy_opportunity.dart';

typedef FrozenOpportunityEvaluator =
    PaperStrategyOpportunity? Function(List<PaperCandle> closedCandles);

/// Adapter used by paper-forward to call a frozen strategy implementation.
///
/// The strategy-specific evaluator is injected from the existing A/C5
/// production/research boundary. This adapter deliberately contains no
/// substitute setup logic, score threshold, or frequency gate.
final class FrozenStrategyDetector implements PaperOpportunityDetector {
  const FrozenStrategyDetector({
    required this.strategy,
    required this.evaluate,
  });

  @override
  final String strategy;

  final FrozenOpportunityEvaluator evaluate;

  @override
  List<PaperStrategyOpportunity> detect(List<PaperCandle> closedCandles) {
    if (closedCandles.isEmpty) return const [];
    final opportunity = evaluate(closedCandles);
    if (opportunity == null) return const [];
    if (opportunity.strategy != strategy) {
      throw StateError(
        'Frozen $strategy evaluator emitted ${opportunity.strategy}.',
      );
    }
    return [opportunity];
  }
}
