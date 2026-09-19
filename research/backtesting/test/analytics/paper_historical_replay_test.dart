import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/analytics/paper_historical_replay.dart';
import 'package:tradeforge_backtesting/src/strategy_library/mainstream_strategy_batch.dart';
import 'package:tradeforge_backtesting/src/strategy_library/paper_forward_segment_portfolio.dart';
import 'package:tradeforge_backtesting/src/strategy_library/strategy_registry.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_expectancy_validator.dart';

void main() {
  test('reports all eight frozen Paper Forward segments', () {
    final results = const PaperHistoricalReplay().evaluate(const []);
    expect(results, hasLength(8));
    expect(
      results.map((item) => item.definition.id).toSet(),
      paperForwardSegmentPortfolioV3.map((item) => item.id).toSet(),
    );
  });

  test('filters by exact side and regime segment', () {
    final candidate = ResearchCandidate(
      strategyId: 'ATR_EXPANSION',
      observedAt: DateTime.utc(2025, 1, 2),
      candleIndex: 100,
      side: ResearchSide.buy,
      entry: 2000,
      stop: 1990,
      target: 2020,
      regime: 'trend',
    );
    final trade = StrategyTradeResult(
      observedAt: candidate.observedAt,
      resolution: TradeResolution.win,
      rewardRisk: 2,
    );
    final batch = StrategyBatchResult(
      strategy: const StrategyDefinition(
        id: 'ATR_EXPANSION',
        name: 'ATR Expansion',
        family: StrategyMarketFamily.volatility,
        lifecycle: StrategyLifecycle.researchOnly,
        description: 'Volatility expansion',
      ),
      candidates: 1,
      cases: [StrategyResearchCase(candidate: candidate, trade: trade)],
      trades: [trade],
      report: const StrategyExpectancyValidator().evaluate([trade]),
    );

    final results = const PaperHistoricalReplay().evaluate([batch]);
    final segment = results.firstWhere(
      (item) => item.definition.id == 'ATR_EXPANSION|BUY|TREND',
    );

    expect(segment.discovered, 1);
    expect(segment.report.resolved, 1);
    expect(segment.report.wins, 1);
    expect(segment.totalR, 2);
    expect(segment.yearly[2025]!.report.wins, 1);
  });
}
