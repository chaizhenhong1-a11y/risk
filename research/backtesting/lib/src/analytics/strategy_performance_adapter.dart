import '../validation/strategy_expectancy_validator.dart';
import '../validation/unified_strategy_expectancy_audit.dart';
import 'strategy_performance_analytics.dart';

final class DirectionalStrategyTradeResult {
  const DirectionalStrategyTradeResult({
    required this.trade,
    required this.side,
  });

  final StrategyTradeResult trade;
  final String side;
}

/// Bridges the existing validated lifecycle trade results into the analytics
/// engine. It never re-simulates entries/exits and never asks AI for metrics.
final class StrategyPerformanceAdapter {
  const StrategyPerformanceAdapter();

  StrategyPerformanceBreakdown fromAuditedTrades(
    Iterable<StrategyAuditInput> inputs, {
    Map<AuditedStrategy, List<DirectionalStrategyTradeResult>>
        directionalTrades =
        const {},
  }) {
    final outcomes = <StrategyTradeOutcome>[];

    for (final input in inputs) {
      final strategy = _strategyName(input.strategy);
      final directional = directionalTrades[input.strategy];

      if (directional != null) {
        for (final item in directional) {
          final netR = item.trade.netR;
          if (netR == null) continue;
          outcomes.add(
            StrategyTradeOutcome(
              strategy: strategy,
              side: item.side.toUpperCase(),
              rMultiple: netR,
            ),
          );
        }
        continue;
      }

      // Existing StrategyTradeResult does not store direction. Preserve the
      // real resolved R result without inventing BUY/SELL.
      for (final trade in input.trades) {
        final netR = trade.netR;
        if (netR == null) continue;
        outcomes.add(
          StrategyTradeOutcome(
            strategy: strategy,
            side: 'UNKNOWN',
            rMultiple: netR,
          ),
        );
      }
    }

    return analyzeStrategyPerformance(outcomes);
  }

  String _strategyName(AuditedStrategy strategy) => switch (strategy) {
    AuditedStrategy.strategyA => 'A',
    AuditedStrategy.strategyB => 'B',
    AuditedStrategy.strategyC5 => 'C5',
  };
}
