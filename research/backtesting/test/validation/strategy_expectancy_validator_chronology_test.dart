import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_expectancy_validator.dart';

void main() {
  test('chronological halves are based on observation order', () {
    final trades = [
      StrategyTradeResult(
        observedAt: DateTime.utc(2026, 1, 4),
        resolution: TradeResolution.win,
        rewardRisk: 2,
      ),
      StrategyTradeResult(
        observedAt: DateTime.utc(2026, 1, 1),
        resolution: TradeResolution.loss,
        rewardRisk: 2,
      ),
      StrategyTradeResult(
        observedAt: DateTime.utc(2026, 1, 3),
        resolution: TradeResolution.win,
        rewardRisk: 2,
      ),
      StrategyTradeResult(
        observedAt: DateTime.utc(2026, 1, 2),
        resolution: TradeResolution.loss,
        rewardRisk: 2,
      ),
    ];

    final report = const StrategyExpectancyValidator().evaluate(trades);

    expect(report.firstHalfNetExpectancyR, -1);
    expect(report.secondHalfNetExpectancyR, 2);
  });
}
