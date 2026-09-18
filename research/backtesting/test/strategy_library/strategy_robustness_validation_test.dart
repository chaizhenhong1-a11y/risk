import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/strategy_library/mainstream_strategy_batch.dart';
import 'package:tradeforge_backtesting/src/strategy_library/strategy_robustness_validation.dart';
import 'package:tradeforge_backtesting/src/strategy_library/strategy_registry.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_expectancy_validator.dart';

void main() {
  test(
    'robustness slices preserve side, regime, year and rolling evidence',
    () {
      final cases = <StrategyResearchCase>[];
      for (var i = 0; i < 80; i++) {
        final time = DateTime.utc(2024 + (i ~/ 40), 1 + (i % 12), 1);
        final side = i.isEven ? ResearchSide.buy : ResearchSide.sell;
        final candidate = ResearchCandidate(
          strategyId: 'TEST',
          observedAt: time,
          candleIndex: i,
          side: side,
          entry: 100,
          stop: side == ResearchSide.buy ? 99 : 101,
          target: side == ResearchSide.buy ? 102 : 98,
          regime: i % 3 == 0 ? 'trend' : 'transition',
        );
        final trade = StrategyTradeResult(
          observedAt: time,
          resolution: i % 3 == 0 ? TradeResolution.loss : TradeResolution.win,
          rewardRisk: 2,
        );
        cases.add(StrategyResearchCase(candidate: candidate, trade: trade));
      }
      final trades = cases.map((e) => e.trade).toList(growable: false);
      final fake = StrategyBatchResult(
        strategy: const StrategyDefinition(
          id: 'TEST',
          name: 'Test',
          family: StrategyMarketFamily.trend,
          lifecycle: StrategyLifecycle.researchOnly,
          description: 'test',
        ),
        candidates: cases.length,
        cases: cases,
        trades: trades,
        report: const StrategyExpectancyValidator().evaluate(trades),
      );

      final report = const StrategyRobustnessValidator(
        rollingWindows: 4,
      ).evaluate(fake);
      expect(
        report.bySide.map((e) => e.label),
        containsAll(<String>['BUY', 'SELL']),
      );
      expect(report.byYear.length, 2);
      expect(report.rolling.length, 4);
    },
  );
}
