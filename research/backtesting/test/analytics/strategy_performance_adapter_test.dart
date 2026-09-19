import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/analytics/strategy_performance_adapter.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_expectancy_validator.dart';
import 'package:tradeforge_backtesting/src/validation/unified_strategy_expectancy_audit.dart';

void main() {
  test('uses existing resolved net R and excludes unresolved outcomes', () {
    final result = const StrategyPerformanceAdapter().fromAuditedTrades([
      StrategyAuditInput(
        strategy: AuditedStrategy.strategyA,
        trades: [
          StrategyTradeResult(
            observedAt: DateTime.utc(2026, 1, 1),
            resolution: TradeResolution.win,
            rewardRisk: 2,
            costR: .1,
          ),
          StrategyTradeResult(
            observedAt: DateTime.utc(2026, 1, 2),
            resolution: TradeResolution.loss,
            rewardRisk: 2,
            costR: .1,
          ),
          StrategyTradeResult(
            observedAt: DateTime.utc(2026, 1, 3),
            resolution: TradeResolution.expired,
            rewardRisk: 2,
          ),
        ],
      ),
    ]);

    expect(result.overall.tradeCount, 2);
    expect(result.overall.totalR, closeTo(.8, 1e-9));
    expect(result.byStrategy['A']?.tradeCount, 2);
    expect(result.byStrategyAndSide['A']?['UNKNOWN']?.tradeCount, 2);
  });

  test('keeps A B C5 separate without changing lifecycle results', () {
    final result = const StrategyPerformanceAdapter().fromAuditedTrades([
      StrategyAuditInput(
        strategy: AuditedStrategy.strategyA,
        trades: [_win(2)],
      ),
      StrategyAuditInput(
        strategy: AuditedStrategy.strategyB,
        trades: [_loss()],
      ),
      StrategyAuditInput(
        strategy: AuditedStrategy.strategyC5,
        trades: [_win(3)],
      ),
    ]);

    expect(result.overall.tradeCount, 3);
    expect(result.byStrategy.keys, containsAll(['A', 'B', 'C5']));
    expect(result.byStrategy['C5']?.totalR, 3);
  });

  test('uses real side only when directional lifecycle data is supplied', () {
    final aTrade = _win(2);
    final result = const StrategyPerformanceAdapter().fromAuditedTrades(
      [
        StrategyAuditInput(
          strategy: AuditedStrategy.strategyA,
          trades: [aTrade],
        ),
      ],
      directionalTrades: {
        AuditedStrategy.strategyA: [
          DirectionalStrategyTradeResult(trade: aTrade, side: 'BUY'),
        ],
      },
    );

    expect(result.byStrategyAndSide['A']?['BUY']?.tradeCount, 1);
    expect(result.byStrategyAndSide['A']?['UNKNOWN'], isNull);
  });
}

StrategyTradeResult _win(double rr) => StrategyTradeResult(
  observedAt: DateTime.utc(2026, 1, 1),
  resolution: TradeResolution.win,
  rewardRisk: rr,
);

StrategyTradeResult _loss() => StrategyTradeResult(
  observedAt: DateTime.utc(2026, 1, 2),
  resolution: TradeResolution.loss,
  rewardRisk: 2,
);
