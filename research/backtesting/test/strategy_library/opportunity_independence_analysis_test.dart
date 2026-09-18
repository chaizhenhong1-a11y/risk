import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/strategy_library/mainstream_strategy_batch.dart';
import 'package:tradeforge_backtesting/src/strategy_library/opportunity_independence_analysis.dart';
import 'package:tradeforge_backtesting/src/strategy_library/paper_forward_segment_portfolio.dart';

void main() {
  test('empty evidence produces zero independence counts', () {
    const challenger = PaperForwardSegmentDefinition(
      strategyId: 'NR7_BREAKOUT',
      side: ResearchSide.sell,
      regime: 'range',
    );

    final reports = const OpportunityIndependenceAnalyzer().evaluate(
      results: const <StrategyBatchResult>[],
      baseline: paperForwardSegmentPortfolioV2,
      challengers: const <PaperForwardSegmentDefinition>[challenger],
    );

    expect(reports, hasLength(1));
    expect(reports.single.rawCandidates, 0);
    expect(reports.single.totalClusters, 0);
    expect(reports.single.overlappingClusters, 0);
    expect(reports.single.marginalClusters, 0);
    expect(reports.single.marginalRatio, 0);
  });
}
