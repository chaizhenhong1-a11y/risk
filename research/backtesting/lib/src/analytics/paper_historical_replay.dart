import '../strategy_library/mainstream_strategy_batch.dart';
import '../strategy_library/paper_forward_segment_portfolio.dart';
import '../validation/strategy_expectancy_validator.dart';

final class PaperHistoricalSegmentResult {
  const PaperHistoricalSegmentResult({
    required this.definition,
    required this.discovered,
    required this.trades,
    required this.report,
    required this.totalR,
    required this.maxDrawdownR,
    required this.yearly,
  });

  final PaperForwardSegmentDefinition definition;
  final int discovered;
  final List<StrategyTradeResult> trades;
  final StrategyExpectancyReport report;
  final double totalR;
  final double maxDrawdownR;
  final Map<int, PaperHistoricalYearResult> yearly;
}

final class PaperHistoricalYearResult {
  const PaperHistoricalYearResult({
    required this.year,
    required this.report,
    required this.totalR,
    required this.maxDrawdownR,
  });

  final int year;
  final StrategyExpectancyReport report;
  final double totalR;
  final double maxDrawdownR;
}

/// Replays the exact frozen Paper Forward segment definitions against the
/// research batch cases. This layer does not change strategy rules, promote
/// strategies, or merge its evidence with forward performance.
final class PaperHistoricalReplay {
  const PaperHistoricalReplay({
    this.portfolio = const PaperForwardSegmentPortfolio(),
    this.validator = const StrategyExpectancyValidator(),
  });

  final PaperForwardSegmentPortfolio portfolio;
  final StrategyExpectancyValidator validator;

  List<PaperHistoricalSegmentResult> evaluate(
    List<StrategyBatchResult> batchResults,
  ) {
    final byStrategy = <String, StrategyBatchResult>{
      for (final result in batchResults) result.strategy.id: result,
    };

    return portfolio.definitions
        .map((definition) {
          final source = byStrategy[definition.strategyId];
          final cases =
              source?.cases
                  .where((item) => definition.matches(item.candidate))
                  .toList(growable: false) ??
              const <StrategyResearchCase>[];

          final trades = cases
              .map((item) => item.trade)
              .toList(growable: false);
          final resolved = trades.where((trade) => trade.isResolved).toList()
            ..sort((a, b) => a.observedAt.compareTo(b.observedAt));

          final yearlyTrades = <int, List<StrategyTradeResult>>{};
          for (final trade in trades) {
            yearlyTrades
                .putIfAbsent(
                  trade.observedAt.year,
                  () => <StrategyTradeResult>[],
                )
                .add(trade);
          }

          final yearly = <int, PaperHistoricalYearResult>{};
          for (final entry in yearlyTrades.entries) {
            final yearResolved =
                entry.value.where((trade) => trade.isResolved).toList()
                  ..sort((a, b) => a.observedAt.compareTo(b.observedAt));
            yearly[entry.key] = PaperHistoricalYearResult(
              year: entry.key,
              report: validator.evaluate(entry.value),
              totalR: _totalR(yearResolved),
              maxDrawdownR: _maxDrawdownR(yearResolved),
            );
          }

          return PaperHistoricalSegmentResult(
            definition: definition,
            discovered: cases.length,
            trades: List.unmodifiable(trades),
            report: validator.evaluate(trades),
            totalR: _totalR(resolved),
            maxDrawdownR: _maxDrawdownR(resolved),
            yearly: Map.unmodifiable(yearly),
          );
        })
        .toList(growable: false);
  }

  static double _totalR(Iterable<StrategyTradeResult> trades) =>
      trades.fold<double>(0, (sum, trade) => sum + (trade.netR ?? 0));

  static double _maxDrawdownR(List<StrategyTradeResult> trades) {
    var equity = 0.0;
    var peak = 0.0;
    var maxDrawdown = 0.0;
    for (final trade in trades) {
      equity += trade.netR ?? 0;
      if (equity > peak) peak = equity;
      final drawdown = peak - equity;
      if (drawdown > maxDrawdown) maxDrawdown = drawdown;
    }
    return maxDrawdown;
  }
}
