import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/analytics/strategy_performance_analytics.dart';

void main() {
  test('calculates overall professional R metrics', () {
    final result = analyzeStrategyPerformance(const [
      StrategyTradeOutcome(strategy: 'A', side: 'BUY', rMultiple: 2),
      StrategyTradeOutcome(strategy: 'A', side: 'BUY', rMultiple: -1),
      StrategyTradeOutcome(strategy: 'B', side: 'SELL', rMultiple: 1.5),
      StrategyTradeOutcome(strategy: 'B', side: 'SELL', rMultiple: -1),
    ]);

    expect(result.overall.tradeCount, 4);
    expect(result.overall.winRate, closeTo(0.5, 1e-9));
    expect(result.overall.totalR, closeTo(1.5, 1e-9));
    expect(result.overall.expectancyR, closeTo(0.375, 1e-9));
    expect(result.overall.profitFactor, closeTo(1.75, 1e-9));
    expect(result.overall.maxDrawdownR, closeTo(1, 1e-9));
  });

  test('breaks down each strategy and BUY SELL independently', () {
    final result = analyzeStrategyPerformance(const [
      StrategyTradeOutcome(strategy: 'A', side: 'BUY', rMultiple: 2),
      StrategyTradeOutcome(strategy: 'A', side: 'BUY', rMultiple: -1),
      StrategyTradeOutcome(strategy: 'A', side: 'SELL', rMultiple: -1),
      StrategyTradeOutcome(strategy: 'B', side: 'BUY', rMultiple: 3),
    ]);

    expect(result.byStrategy['A']?.tradeCount, 3);
    expect(result.byStrategy['B']?.tradeCount, 1);
    expect(result.byStrategyAndSide['A']?['BUY']?.tradeCount, 2);
    expect(result.byStrategyAndSide['A']?['SELL']?.tradeCount, 1);
  });

  test('maximum drawdown follows the ordered R equity curve', () {
    final result = analyzeStrategyPerformance(const [
      StrategyTradeOutcome(strategy: 'A', side: 'BUY', rMultiple: 3),
      StrategyTradeOutcome(strategy: 'A', side: 'BUY', rMultiple: -1),
      StrategyTradeOutcome(strategy: 'A', side: 'BUY', rMultiple: -2),
      StrategyTradeOutcome(strategy: 'A', side: 'BUY', rMultiple: 1),
    ]);

    expect(result.overall.maxDrawdownR, closeTo(3, 1e-9));
  });

  test('ignores non-finite results instead of corrupting analytics', () {
    final result = analyzeStrategyPerformance(const [
      StrategyTradeOutcome(strategy: 'A', side: 'BUY', rMultiple: 1),
      StrategyTradeOutcome(strategy: 'A', side: 'BUY', rMultiple: double.nan),
    ]);

    expect(result.overall.tradeCount, 1);
    expect(result.overall.totalR, 1);
  });
}
