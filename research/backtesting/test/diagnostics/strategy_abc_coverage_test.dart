import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/diagnostics/strategy_abc_coverage.dart';

void main() {
  test('merges same-direction sources and preserves conflicts', () {
    final t1 = DateTime.utc(2026, 1, 1, 10), t2 = DateTime.utc(2026, 1, 1, 11);
    final r = const StrategyAbcCoverageAnalyzer().analyze(
      tradingDates: [DateTime.utc(2026, 1, 1), DateTime.utc(2026, 1, 2)],
      events: [
        CoverageEvent(
          time: t1,
          direction: CoverageDirection.buy,
          source: CoverageSource.strategyA,
        ),
        CoverageEvent(
          time: t1,
          direction: CoverageDirection.buy,
          source: CoverageSource.strategyC5,
        ),
        CoverageEvent(
          time: t2,
          direction: CoverageDirection.buy,
          source: CoverageSource.strategyB,
        ),
        CoverageEvent(
          time: t2,
          direction: CoverageDirection.sell,
          source: CoverageSource.strategyA,
        ),
      ],
    );
    expect(r.uniqueOpportunities, 2);
    expect(r.sameDirectionOverlaps, 1);
    expect(r.oppositeDirectionConflicts, 1);
    expect(r.dailyCounts, [2, 0]);
  });
}
