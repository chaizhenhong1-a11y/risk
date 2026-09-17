import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/diagnostics/opportunity_gap_scanner.dart';

void main() {
  const transition = OpportunityGapSignature(
    regime: MarketRegime.transition,
    h4: MarketStructure.neutral,
    h1: MarketStructure.bullish,
    m15: MarketStructure.bearish,
  );
  const trend = OpportunityGapSignature(
    regime: MarketRegime.trendAligned,
    h4: MarketStructure.bullish,
    h1: MarketStructure.bullish,
    m15: MarketStructure.bullish,
  );

  test('reports only days without A+B+C5 opportunity', () {
    final scanner = OpportunityGapScanner()
      ..observe(
        observedAt: DateTime.utc(2026, 1, 1, 1),
        signature: transition,
        hasOpportunity: false,
      )
      ..observe(
        observedAt: DateTime.utc(2026, 1, 1, 2),
        signature: transition,
        hasOpportunity: false,
      )
      ..observe(
        observedAt: DateTime.utc(2026, 1, 2, 1),
        signature: trend,
        hasOpportunity: true,
      );

    final report = scanner.finish();

    expect(report.tradingDays, 2);
    expect(report.zeroOpportunityDays, 1);
    expect(report.zeroDayObservations, 2);
    expect(report.rows.single.signature, transition);
  });

  test('C5 opportunity can remove an otherwise uncovered day', () {
    final scanner = OpportunityGapScanner()
      ..observe(
        observedAt: DateTime.utc(2026, 1, 1, 1),
        signature: transition,
        hasOpportunity: false,
      )
      ..markOpportunity(DateTime.utc(2026, 1, 1, 3));

    expect(scanner.finish().zeroOpportunityDays, 0);
  });
}
