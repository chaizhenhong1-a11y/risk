import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/strategy_library/mainstream_strategy_batch.dart';
import 'package:tradeforge_backtesting/src/strategy_library/strategy_edge_segmentation.dart';
import 'package:tradeforge_backtesting/src/strategy_library/strategy_registry.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_expectancy_validator.dart';

void main() {
  test('segments historical-pass evidence by side and regime', () {
    final cases = <StrategyResearchCase>[];
    for (var i = 0; i < 240; i++) {
      final time = DateTime.utc(
        2025 + (i ~/ 120),
        1 + ((i ~/ 20) % 12),
        1,
        i % 24,
      );
      final side = i.isEven ? ResearchSide.buy : ResearchSide.sell;
      final candidate = ResearchCandidate(
        strategyId: 'TEST',
        observedAt: time,
        candleIndex: i,
        side: side,
        entry: 100,
        stop: side == ResearchSide.buy ? 99 : 101,
        target: side == ResearchSide.buy ? 102 : 98,
        regime: i % 4 < 2 ? 'trend' : 'range',
      );
      final trade = StrategyTradeResult(
        observedAt: time,
        resolution: i % 3 == 0 ? TradeResolution.loss : TradeResolution.win,
        rewardRisk: 2,
      );
      cases.add(StrategyResearchCase(candidate: candidate, trade: trade));
    }

    final trades = cases.map((e) => e.trade).toList(growable: false);
    final result = StrategyBatchResult(
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

    final segments = const StrategyEdgeSegmentation(
      rollingWindows: 4,
    ).evaluate([result]);
    expect(segments, hasLength(4));
    expect(segments.map((s) => s.side), containsAll(ResearchSide.values));
    expect(
      segments.map((s) => s.regime),
      containsAll(<String>['trend', 'range']),
    );
  });

  test(
    'overlap ratio detects another strategy on the same side near in time',
    () {
      StrategyBatchResult makeResult(String id, int minuteOffset) {
        final cases = <StrategyResearchCase>[];
        for (var i = 0; i < 120; i++) {
          final time = DateTime.utc(
            2025,
            1,
            1,
          ).add(Duration(minutes: i * 30 + minuteOffset));
          final candidate = ResearchCandidate(
            strategyId: id,
            observedAt: time,
            candleIndex: i,
            side: ResearchSide.buy,
            entry: 100,
            stop: 99,
            target: 102,
            regime: 'trend',
          );
          final trade = StrategyTradeResult(
            observedAt: time,
            resolution: i % 3 == 0 ? TradeResolution.loss : TradeResolution.win,
            rewardRisk: 2,
          );
          cases.add(StrategyResearchCase(candidate: candidate, trade: trade));
        }
        final trades = cases.map((e) => e.trade).toList(growable: false);
        return StrategyBatchResult(
          strategy: StrategyDefinition(
            id: id,
            name: id,
            family: StrategyMarketFamily.trend,
            lifecycle: StrategyLifecycle.researchOnly,
            description: 'test',
          ),
          candidates: cases.length,
          cases: cases,
          trades: trades,
          report: const StrategyExpectancyValidator().evaluate(trades),
        );
      }

      final reports = const StrategyEdgeSegmentation(
        rollingWindows: 4,
      ).evaluate([makeResult('ONE', 0), makeResult('TWO', 5)]);
      expect(reports, isNotEmpty);
      expect(reports.every((r) => r.overlapRatio > .9), isTrue);
    },
  );
}
