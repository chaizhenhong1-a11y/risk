import 'dart:math' as math;

final class StrategyTradeOutcome {
  const StrategyTradeOutcome({
    required this.strategy,
    required this.side,
    required this.rMultiple,
  });

  final String strategy;
  final String side;

  /// Realized result in R. Example: +2R winner, -1R loser.
  final double rMultiple;
}

final class StrategyPerformanceMetrics {
  const StrategyPerformanceMetrics({
    required this.tradeCount,
    required this.winCount,
    required this.lossCount,
    required this.breakEvenCount,
    required this.winRate,
    required this.expectancyR,
    required this.averageR,
    required this.profitFactor,
    required this.maxDrawdownR,
    required this.totalR,
  });

  final int tradeCount;
  final int winCount;
  final int lossCount;
  final int breakEvenCount;
  final double? winRate;
  final double? expectancyR;
  final double? averageR;
  final double? profitFactor;
  final double maxDrawdownR;
  final double totalR;
}

final class StrategyPerformanceBreakdown {
  const StrategyPerformanceBreakdown({
    required this.overall,
    required this.byStrategy,
    required this.byStrategyAndSide,
  });

  final StrategyPerformanceMetrics overall;
  final Map<String, StrategyPerformanceMetrics> byStrategy;
  final Map<String, Map<String, StrategyPerformanceMetrics>> byStrategyAndSide;
}

StrategyPerformanceBreakdown analyzeStrategyPerformance(
  Iterable<StrategyTradeOutcome> outcomes,
) {
  final trades = outcomes
      .where((e) => e.rMultiple.isFinite)
      .toList(growable: false);
  final strategies = <String, List<StrategyTradeOutcome>>{};
  final sides = <String, Map<String, List<StrategyTradeOutcome>>>{};

  for (final trade in trades) {
    strategies.putIfAbsent(trade.strategy, () => []).add(trade);
    sides
        .putIfAbsent(trade.strategy, () => {})
        .putIfAbsent(trade.side.toUpperCase(), () => [])
        .add(trade);
  }

  return StrategyPerformanceBreakdown(
    overall: _metrics(trades),
    byStrategy: {
      for (final entry in strategies.entries) entry.key: _metrics(entry.value),
    },
    byStrategyAndSide: {
      for (final strategy in sides.entries)
        strategy.key: {
          for (final side in strategy.value.entries)
            side.key: _metrics(side.value),
        },
    },
  );
}

StrategyPerformanceMetrics _metrics(List<StrategyTradeOutcome> trades) {
  if (trades.isEmpty) {
    return const StrategyPerformanceMetrics(
      tradeCount: 0,
      winCount: 0,
      lossCount: 0,
      breakEvenCount: 0,
      winRate: null,
      expectancyR: null,
      averageR: null,
      profitFactor: null,
      maxDrawdownR: 0,
      totalR: 0,
    );
  }

  var wins = 0;
  var losses = 0;
  var breakEven = 0;
  var grossProfit = 0.0;
  var grossLoss = 0.0;
  var totalR = 0.0;
  var equityR = 0.0;
  var peakR = 0.0;
  var maxDrawdownR = 0.0;

  for (final trade in trades) {
    final r = trade.rMultiple;
    totalR += r;
    if (r > 0) {
      wins++;
      grossProfit += r;
    } else if (r < 0) {
      losses++;
      grossLoss += r.abs();
    } else {
      breakEven++;
    }

    equityR += r;
    peakR = math.max(peakR, equityR);
    maxDrawdownR = math.max(maxDrawdownR, peakR - equityR);
  }

  final decided = wins + losses;
  final averageR = totalR / trades.length;
  final profitFactor = grossLoss == 0
      ? (grossProfit > 0 ? double.infinity : null)
      : grossProfit / grossLoss;

  return StrategyPerformanceMetrics(
    tradeCount: trades.length,
    winCount: wins,
    lossCount: losses,
    breakEvenCount: breakEven,
    winRate: decided == 0 ? null : wins / decided,
    expectancyR: averageR,
    averageR: averageR,
    profitFactor: profitFactor,
    maxDrawdownR: maxDrawdownR,
    totalR: totalR,
  );
}
