import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_expectancy_validator.dart';

void main() {
  test('evaluates positive expectancy despite sub-50 percent win rate', () {
    final trades = [
      StrategyTradeResult(
        observedAt: DateTime.utc(2026, 1, 1),
        resolution: TradeResolution.win,
        rewardRisk: 2,
      ),
      StrategyTradeResult(
        observedAt: DateTime.utc(2026, 1, 2),
        resolution: TradeResolution.loss,
        rewardRisk: 2,
      ),
      StrategyTradeResult(
        observedAt: DateTime.utc(2026, 1, 3),
        resolution: TradeResolution.loss,
        rewardRisk: 2,
      ),
      StrategyTradeResult(
        observedAt: DateTime.utc(2026, 1, 4),
        resolution: TradeResolution.win,
        rewardRisk: 2,
      ),
      StrategyTradeResult(
        observedAt: DateTime.utc(2026, 1, 5),
        resolution: TradeResolution.loss,
        rewardRisk: 2,
      ),
    ];

    final report = const StrategyExpectancyValidator().evaluate(trades);

    expect(report.resolved, 5);
    expect(report.wins, 2);
    expect(report.losses, 3);
    expect(report.winRate, .4);
    expect(report.grossExpectancyR, closeTo(.2, 1e-12));
    expect(report.profitFactor, closeTo(4 / 3, 1e-12));
    expect(report.maxLosingStreak, 2);
  });

  test('applies costs and excludes unresolved outcomes from expectancy', () {
    final trades = [
      StrategyTradeResult(
        observedAt: DateTime.utc(2026, 2, 1),
        resolution: TradeResolution.win,
        rewardRisk: 2,
        costR: .1,
      ),
      StrategyTradeResult(
        observedAt: DateTime.utc(2026, 2, 2),
        resolution: TradeResolution.loss,
        rewardRisk: 2,
        costR: .1,
      ),
      StrategyTradeResult(
        observedAt: DateTime.utc(2026, 2, 3),
        resolution: TradeResolution.expired,
        rewardRisk: 2,
        costR: .1,
      ),
    ];

    final report = const StrategyExpectancyValidator().evaluate(trades);

    expect(report.total, 3);
    expect(report.resolved, 2);
    expect(report.expired, 1);
    expect(report.grossExpectancyR, .5);
    expect(report.netExpectancyR, closeTo(.4, 1e-12));
  });
}
