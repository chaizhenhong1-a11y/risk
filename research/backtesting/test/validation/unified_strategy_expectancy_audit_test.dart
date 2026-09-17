import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_expectancy_validator.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_validation_standard.dart';
import 'package:tradeforge_backtesting/src/validation/unified_strategy_expectancy_audit.dart';

void main() {
  test('passes only when every frozen validation gate passes', () {
    final trades = <StrategyTradeResult>[
      for (var i = 0; i < 40; i++)
        StrategyTradeResult(
          observedAt: DateTime.utc(2026, 1, 1).add(Duration(hours: i)),
          resolution: i.isEven ? TradeResolution.win : TradeResolution.loss,
          rewardRisk: 2,
        ),
    ];

    final result =
        const UnifiedStrategyExpectancyAudit(
          standard: StrategyValidationStandard(minimumResolvedTrades: 30),
        ).evaluate([
          StrategyAuditInput(
            strategy: AuditedStrategy.strategyA,
            trades: trades,
          ),
        ]).single;

    expect(result.meetsResolvedSampleFloor, isTrue);
    expect(result.hasPositiveExpectancy, isTrue);
    expect(result.hasProfitFactorAboveOne, isTrue);
    expect(result.hasPositiveFirstHalf, isTrue);
    expect(result.hasPositiveSecondHalf, isTrue);
    expect(result.passes, isTrue);
  });

  test('fails chronological stability even with positive total expectancy', () {
    final trades = <StrategyTradeResult>[
      for (var i = 0; i < 20; i++)
        StrategyTradeResult(
          observedAt: DateTime.utc(2026, 1, 1).add(Duration(hours: i)),
          resolution: TradeResolution.loss,
          rewardRisk: 2,
        ),
      for (var i = 20; i < 60; i++)
        StrategyTradeResult(
          observedAt: DateTime.utc(2026, 1, 1).add(Duration(hours: i)),
          resolution: TradeResolution.win,
          rewardRisk: 2,
        ),
    ];

    final result = const UnifiedStrategyExpectancyAudit().evaluate([
      StrategyAuditInput(strategy: AuditedStrategy.strategyB, trades: trades),
    ]).single;

    expect(result.report.netExpectancyR, greaterThan(0));
    expect(result.hasPositiveFirstHalf, isFalse);
    expect(result.passes, isFalse);
  });

  test('sample floor prevents tiny positive C5 sample from passing', () {
    final trades = [
      for (var i = 0; i < 8; i++)
        StrategyTradeResult(
          observedAt: DateTime.utc(2026, 1, 1).add(Duration(hours: i)),
          resolution: i < 5 ? TradeResolution.win : TradeResolution.loss,
          rewardRisk: 2,
        ),
    ];

    final result = const UnifiedStrategyExpectancyAudit().evaluate([
      StrategyAuditInput(strategy: AuditedStrategy.strategyC5, trades: trades),
    ]).single;

    expect(result.report.netExpectancyR, greaterThan(0));
    expect(result.meetsResolvedSampleFloor, isFalse);
    expect(result.passes, isFalse);
  });
}
