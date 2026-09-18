import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/validation/market_opportunity_coverage.dart';

void main() {
  const analyzer = MarketOpportunityCoverageAnalyzer();

  test('prioritizes the largest uncovered market state', () {
    final report = analyzer.analyze(const [
      OpportunityCoverageCell(
        state: OpportunityMarketState.trend,
        observations: 100,
        candidateObservations: 70,
        strategy: 'A',
        evidence: StrategyEvidenceTier.historicalPass,
      ),
      OpportunityCoverageCell(
        state: OpportunityMarketState.range,
        observations: 200,
        candidateObservations: 10,
        strategy: null,
        evidence: StrategyEvidenceTier.unassigned,
      ),
      OpportunityCoverageCell(
        state: OpportunityMarketState.transition,
        observations: 150,
        candidateObservations: 90,
        strategy: 'C5',
        evidence: StrategyEvidenceTier.historicalPass,
      ),
    ]);

    expect(report.researchPriority.first.state, OpportunityMarketState.range);
    expect(report.researchPriority.first.uncoveredObservations, 190);
  });

  test(
    'coverage is descriptive and preserves strategy evidence separately',
    () {
      final report = analyzer.analyze(const [
        OpportunityCoverageCell(
          state: OpportunityMarketState.correction,
          observations: 50,
          candidateObservations: 12,
          strategy: 'B',
          evidence: StrategyEvidenceTier.researchOnly,
        ),
      ]);

      final cell = report.cells.single;
      expect(cell.candidateCoverage, closeTo(0.24, 0.000001));
      expect(cell.evidence, StrategyEvidenceTier.researchOnly);
      expect(cell.uncoveredObservations, 38);
    },
  );

  test('candidate count cannot create negative uncovered observations', () {
    final report = analyzer.analyze(const [
      OpportunityCoverageCell(
        state: OpportunityMarketState.unknown,
        observations: 2,
        candidateObservations: 3,
        strategy: null,
        evidence: StrategyEvidenceTier.unassigned,
      ),
    ]);

    expect(report.totalUncoveredObservations, 0);
  });
}
