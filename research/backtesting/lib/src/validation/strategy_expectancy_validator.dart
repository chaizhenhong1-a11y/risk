enum TradeResolution { win, loss, expired, ambiguous }

final class StrategyTradeResult {
  const StrategyTradeResult({
    required this.observedAt,
    required this.resolution,
    required this.rewardRisk,
    this.costR = 0,
  }) : assert(rewardRisk > 0),
       assert(costR >= 0);

  final DateTime observedAt;
  final TradeResolution resolution;
  final double rewardRisk;
  final double costR;

  bool get isResolved =>
      resolution == TradeResolution.win || resolution == TradeResolution.loss;

  double? get grossR => switch (resolution) {
    TradeResolution.win => rewardRisk,
    TradeResolution.loss => -1,
    TradeResolution.expired || TradeResolution.ambiguous => null,
  };

  double? get netR {
    final gross = grossR;
    return gross == null ? null : gross - costR;
  }
}

final class StrategyExpectancyReport {
  const StrategyExpectancyReport({
    required this.total,
    required this.resolved,
    required this.wins,
    required this.losses,
    required this.expired,
    required this.ambiguous,
    required this.winRate,
    required this.averageWinR,
    required this.averageLossR,
    required this.grossExpectancyR,
    required this.netExpectancyR,
    required this.profitFactor,
    required this.maxLosingStreak,
    required this.firstHalfNetExpectancyR,
    required this.secondHalfNetExpectancyR,
  });

  final int total;
  final int resolved;
  final int wins;
  final int losses;
  final int expired;
  final int ambiguous;
  final double winRate;
  final double averageWinR;
  final double averageLossR;
  final double grossExpectancyR;
  final double netExpectancyR;
  final double profitFactor;
  final int maxLosingStreak;
  final double firstHalfNetExpectancyR;
  final double secondHalfNetExpectancyR;
}

final class StrategyExpectancyValidator {
  const StrategyExpectancyValidator();

  StrategyExpectancyReport evaluate(List<StrategyTradeResult> trades) {
    final ordered = [...trades]
      ..sort((a, b) => a.observedAt.compareTo(b.observedAt));

    final resolved = ordered.where((trade) => trade.isResolved).toList();
    final wins = resolved
        .where((trade) => trade.resolution == TradeResolution.win)
        .toList();
    final losses = resolved
        .where((trade) => trade.resolution == TradeResolution.loss)
        .toList();

    final split = ordered.length ~/ 2;

    return StrategyExpectancyReport(
      total: ordered.length,
      resolved: resolved.length,
      wins: wins.length,
      losses: losses.length,
      expired: ordered
          .where((trade) => trade.resolution == TradeResolution.expired)
          .length,
      ambiguous: ordered
          .where((trade) => trade.resolution == TradeResolution.ambiguous)
          .length,
      winRate: _ratio(wins.length, resolved.length),
      averageWinR: _average(wins.map((trade) => trade.grossR!)),
      averageLossR: _average(losses.map((trade) => trade.grossR!)),
      grossExpectancyR: _average(resolved.map((trade) => trade.grossR!)),
      netExpectancyR: _average(resolved.map((trade) => trade.netR!)),
      profitFactor: _profitFactor(resolved),
      maxLosingStreak: _maxLosingStreak(resolved),
      firstHalfNetExpectancyR: _netExpectancy(ordered.sublist(0, split)),
      secondHalfNetExpectancyR: _netExpectancy(ordered.sublist(split)),
    );
  }

  double _ratio(int numerator, int denominator) =>
      denominator == 0 ? 0 : numerator / denominator;

  double _average(Iterable<double> values) {
    final list = values.toList(growable: false);
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  double _profitFactor(List<StrategyTradeResult> trades) {
    var grossProfit = 0.0;
    var grossLoss = 0.0;
    for (final trade in trades) {
      final net = trade.netR!;
      if (net > 0) {
        grossProfit += net;
      } else if (net < 0) {
        grossLoss += -net;
      }
    }
    if (grossLoss == 0) {
      return grossProfit > 0 ? double.infinity : 0;
    }
    return grossProfit / grossLoss;
  }

  int _maxLosingStreak(List<StrategyTradeResult> trades) {
    var current = 0;
    var maximum = 0;
    for (final trade in trades) {
      if (trade.netR! < 0) {
        current++;
        if (current > maximum) maximum = current;
      } else {
        current = 0;
      }
    }
    return maximum;
  }

  double _netExpectancy(List<StrategyTradeResult> trades) {
    final resolved = trades.where((trade) => trade.isResolved);
    return _average(resolved.map((trade) => trade.netR!));
  }
}
