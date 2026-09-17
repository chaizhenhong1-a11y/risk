import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_expectancy_validator.dart';

void main() {
  test('same expectancy framework supports independently audited sides', () {
    final buy = const StrategyExpectancyValidator().evaluate([
      StrategyTradeResult(
        observedAt: DateTime.utc(2026, 1, 1),
        resolution: TradeResolution.win,
        rewardRisk: 1.5,
      ),
      StrategyTradeResult(
        observedAt: DateTime.utc(2026, 1, 2),
        resolution: TradeResolution.loss,
        rewardRisk: 1.5,
      ),
    ]);

    expect(buy.resolved, 2);
    expect(buy.grossExpectancyR, .25);
    expect(buy.profitFactor, 1.5);
  });
}
