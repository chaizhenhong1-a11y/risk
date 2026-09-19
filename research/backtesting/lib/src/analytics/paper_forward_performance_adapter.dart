import 'strategy_performance_analytics.dart';

final class PaperForwardResult {
  const PaperForwardResult({
    required this.strategy,
    required this.side,
    required this.observedAt,
    required this.realizedR,
  });

  final String strategy;
  final String side;
  final DateTime observedAt;
  final double realizedR;
}

/// Converts already-resolved paper-forward outcomes into performance analytics.
///
/// This adapter never reconstructs Entry/SL/TP and never changes a result.
/// Callers must supply the actual realized R produced by the paper lifecycle.
final class PaperForwardPerformanceAdapter {
  const PaperForwardPerformanceAdapter();

  StrategyPerformanceBreakdown analyze(Iterable<PaperForwardResult> results) {
    final ordered =
        results
            .where((result) => result.realizedR.isFinite)
            .toList(growable: false)
          ..sort((a, b) => a.observedAt.compareTo(b.observedAt));

    return analyzeStrategyPerformance([
      for (final result in ordered)
        StrategyTradeOutcome(
          strategy: result.strategy,
          side: result.side.toUpperCase(),
          rMultiple: result.realizedR,
        ),
    ]);
  }
}
