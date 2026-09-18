import 'mainstream_strategy_batch.dart';
import 'paper_forward_segment_portfolio.dart';

/// Historical attribution only. It measures whether a candidate segment adds
/// same-side opportunity episodes beyond an already-frozen baseline portfolio.
///
/// It deliberately does not change any strategy, gate, or paper-forward status.
final class SegmentIndependenceReport {
  const SegmentIndependenceReport({
    required this.definition,
    required this.rawCandidates,
    required this.totalClusters,
    required this.overlappingClusters,
    required this.marginalClusters,
  });

  final PaperForwardSegmentDefinition definition;
  final int rawCandidates;
  final int totalClusters;
  final int overlappingClusters;
  final int marginalClusters;

  double get overlapRatio =>
      totalClusters == 0 ? 0 : overlappingClusters / totalClusters;

  double get marginalRatio =>
      totalClusters == 0 ? 0 : marginalClusters / totalClusters;
}

final class OpportunityIndependenceAnalyzer {
  const OpportunityIndependenceAnalyzer({this.clusterMinutes = 15});

  final int clusterMinutes;

  List<SegmentIndependenceReport> evaluate({
    required List<StrategyBatchResult> results,
    required List<PaperForwardSegmentDefinition> baseline,
    required List<PaperForwardSegmentDefinition> challengers,
  }) {
    final baselineItems = _select(results, baseline);
    final baselineClusters = _cluster(baselineItems);

    return challengers
        .map((definition) {
          final items = _select(results, <PaperForwardSegmentDefinition>[
            definition,
          ]);
          final clusters = _cluster(items);
          var overlapping = 0;
          for (final cluster in clusters) {
            if (_hasSameSideNearby(cluster, baselineClusters)) {
              overlapping++;
            }
          }
          return SegmentIndependenceReport(
            definition: definition,
            rawCandidates: items.length,
            totalClusters: clusters.length,
            overlappingClusters: overlapping,
            marginalClusters: clusters.length - overlapping,
          );
        })
        .toList(growable: false);
  }

  List<PaperForwardPortfolioCandidate> _select(
    List<StrategyBatchResult> results,
    List<PaperForwardSegmentDefinition> definitions,
  ) => PaperForwardSegmentPortfolio(definitions: definitions).select(results);

  List<PaperForwardCandidateCluster> _cluster(
    List<PaperForwardPortfolioCandidate> items,
  ) => PaperForwardSegmentPortfolio(
    definitions: const [],
    clusterMinutes: clusterMinutes,
  ).cluster(items);

  bool _hasSameSideNearby(
    PaperForwardCandidateCluster candidate,
    List<PaperForwardCandidateCluster> baseline,
  ) {
    for (final existing in baseline) {
      if (existing.side != candidate.side) {
        continue;
      }
      final delta = candidate.anchorTime
          .difference(existing.anchorTime)
          .inMinutes
          .abs();
      if (delta <= clusterMinutes) {
        return true;
      }
    }
    return false;
  }
}
