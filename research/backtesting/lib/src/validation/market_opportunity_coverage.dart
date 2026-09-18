enum OpportunityMarketState {
  trend,
  correction,
  transition,
  range,
  breakout,
  reversal,
  unknown,
}

enum StrategyEvidenceTier { historicalPass, researchOnly, unassigned }

final class OpportunityCoverageCell {
  const OpportunityCoverageCell({
    required this.state,
    required this.observations,
    required this.candidateObservations,
    required this.strategy,
    required this.evidence,
  });

  final OpportunityMarketState state;
  final int observations;
  final int candidateObservations;
  final String? strategy;
  final StrategyEvidenceTier evidence;

  int get uncoveredObservations =>
      (observations - candidateObservations).clamp(0, observations);

  double get candidateCoverage =>
      observations == 0 ? 0 : candidateObservations / observations;
}

final class MarketOpportunityCoverageReport {
  MarketOpportunityCoverageReport(List<OpportunityCoverageCell> cells)
    : cells = List.unmodifiable(cells);

  final List<OpportunityCoverageCell> cells;

  int get totalObservations =>
      cells.fold(0, (sum, cell) => sum + cell.observations);

  int get totalUncoveredObservations =>
      cells.fold(0, (sum, cell) => sum + cell.uncoveredObservations);

  List<OpportunityCoverageCell> get researchPriority {
    final result = [...cells]
      ..sort((a, b) {
        final uncovered = b.uncoveredObservations.compareTo(
          a.uncoveredObservations,
        );
        if (uncovered != 0) return uncovered;
        return a.state.index.compareTo(b.state.index);
      });
    return result;
  }
}

/// Increment 144 is descriptive only:
/// it measures where opportunity discovery is thin.
/// It MUST NOT be used as an additional per-trade gate.
final class MarketOpportunityCoverageAnalyzer {
  const MarketOpportunityCoverageAnalyzer();

  MarketOpportunityCoverageReport analyze(
    Iterable<OpportunityCoverageCell> cells,
  ) => MarketOpportunityCoverageReport(cells.toList(growable: false));
}
