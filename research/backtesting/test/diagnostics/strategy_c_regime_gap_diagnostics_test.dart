import 'package:strategy_engine/strategy_engine.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  test('reports regimes only for zero-opportunity days', () {
    final diagnostics = StrategyCRegimeGapDiagnostics();

    diagnostics.observe(
      observedAt: DateTime(2026, 9, 1, 8),
      regime: MarketRegime.range,
      strategyAOpportunityStarted: false,
      strategyBOpportunity: false,
    );
    diagnostics.observe(
      observedAt: DateTime(2026, 9, 1, 9),
      regime: MarketRegime.range,
      strategyAOpportunityStarted: false,
      strategyBOpportunity: false,
    );
    diagnostics.observe(
      observedAt: DateTime(2026, 9, 2, 8),
      regime: MarketRegime.trendAligned,
      strategyAOpportunityStarted: true,
      strategyBOpportunity: false,
    );

    final report = diagnostics.finish();

    expect(report.tradingDays, 2);
    expect(report.zeroOpportunityDays, 1);
    expect(report.regimeObservationCounts[MarketRegime.range], 2);
    expect(report.regimeObservationCounts[MarketRegime.trendAligned], 0);
    expect(report.dominantRegimeDayCounts[MarketRegime.range], 1);
  });
}
