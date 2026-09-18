import 'mainstream_strategy_batch.dart';
import 'strategy_edge_segmentation.dart';

/// A frozen research hypothesis admitted to the *paper-forward* portfolio.
///
/// This is deliberately separate from production strategy lifecycle/status.
/// Nothing in this type can emit a live BUY/SELL signal.
final class PaperForwardSegmentDefinition {
  const PaperForwardSegmentDefinition({
    required this.strategyId,
    required this.side,
    required this.regime,
  });

  final String strategyId;
  final ResearchSide side;
  final String regime;

  String get id =>
      '$strategyId|${side.name.toUpperCase()}|${regime.toUpperCase()}';

  bool matches(ResearchCandidate candidate) =>
      candidate.strategyId == strategyId &&
      candidate.side == side &&
      candidate.regime.toLowerCase() == regime.toLowerCase();
}

/// Frozen from Increment 171 evidence. Changing this list is a new research
/// decision and must not happen implicitly because a later backtest changed.
const paperForwardSegmentPortfolioV1 = <PaperForwardSegmentDefinition>[
  PaperForwardSegmentDefinition(
    strategyId: 'ATR_EXPANSION',
    side: ResearchSide.buy,
    regime: 'trend',
  ),
  PaperForwardSegmentDefinition(
    strategyId: 'TREND_PULLBACK',
    side: ResearchSide.sell,
    regime: 'range',
  ),
  PaperForwardSegmentDefinition(
    strategyId: 'LIQ_SWEEP',
    side: ResearchSide.sell,
    regime: 'range',
  ),
  PaperForwardSegmentDefinition(
    strategyId: 'ADX_TREND',
    side: ResearchSide.buy,
    regime: 'trend',
  ),
];

/// Increment 185: V1 plus the Batch-2 segment that passed the historical
/// side × regime segmentation gate. Still research/paper-forward only.
const paperForwardSegmentPortfolioV2 = <PaperForwardSegmentDefinition>[
  ...paperForwardSegmentPortfolioV1,
  PaperForwardSegmentDefinition(
    strategyId: 'EMA_MEAN_REVERT',
    side: ResearchSide.sell,
    regime: 'range',
  ),
];

/// Increment 189: V2 plus the three Batch-3 segments admitted after
/// historical segmentation and marginal-opportunity attribution.
///
/// These remain research/paper-forward only. Inclusion here does not enable
/// production/live-money BUY/SELL.
const paperForwardSegmentPortfolioV3 = <PaperForwardSegmentDefinition>[
  ...paperForwardSegmentPortfolioV2,
  PaperForwardSegmentDefinition(
    strategyId: 'NR7_BREAKOUT',
    side: ResearchSide.sell,
    regime: 'range',
  ),
  PaperForwardSegmentDefinition(
    strategyId: 'ENGULFING_REVERSAL',
    side: ResearchSide.sell,
    regime: 'range',
  ),
  PaperForwardSegmentDefinition(
    strategyId: 'ENGULFING_REVERSAL',
    side: ResearchSide.buy,
    regime: 'trend',
  ),
];

final class PaperForwardPortfolioCandidate {
  const PaperForwardPortfolioCandidate({
    required this.candidate,
    required this.segmentId,
  });

  final ResearchCandidate candidate;
  final String segmentId;
}

final class PaperForwardCandidateCluster {
  const PaperForwardCandidateCluster({
    required this.side,
    required this.anchorTime,
    required this.members,
  });

  final ResearchSide side;
  final DateTime anchorTime;
  final List<PaperForwardPortfolioCandidate> members;

  /// A cluster is one opportunity episode, even when several highly-overlapping
  /// research strategies discover it. The member list preserves all evidence.
  int get opportunityCount => 1;
}

final class PaperForwardSegmentPortfolio {
  const PaperForwardSegmentPortfolio({
    this.definitions = paperForwardSegmentPortfolioV3,
    this.clusterMinutes = 15,
  });

  final List<PaperForwardSegmentDefinition> definitions;
  final int clusterMinutes;

  /// Verifies that the frozen portfolio is still backed by the exact segment
  /// hypotheses that passed the research-only Increment 171 gate.
  ///
  /// This does not re-promote or enable anything; it is a reproducibility guard.
  List<String> evidenceProblems(List<StrategyEdgeSegmentReport> reports) {
    final problems = <String>[];
    for (final definition in definitions) {
      final matches = reports.where(
        (report) =>
            report.strategyId == definition.strategyId &&
            report.side == definition.side &&
            report.regime.toLowerCase() == definition.regime.toLowerCase(),
      );
      if (matches.isEmpty) {
        problems.add('${definition.id}: missing segment evidence');
        continue;
      }
      if (!matches.single.segmentationGate) {
        problems.add('${definition.id}: segment gate no longer passes');
      }
    }
    return problems;
  }

  List<PaperForwardPortfolioCandidate> select(
    List<StrategyBatchResult> results,
  ) {
    final selected = <PaperForwardPortfolioCandidate>[];
    for (final result in results) {
      for (final item in result.cases) {
        for (final definition in definitions) {
          if (definition.matches(item.candidate)) {
            selected.add(
              PaperForwardPortfolioCandidate(
                candidate: item.candidate,
                segmentId: definition.id,
              ),
            );
            break;
          }
        }
      }
    }
    selected.sort(
      (a, b) => a.candidate.observedAt.compareTo(b.candidate.observedAt),
    );
    return selected;
  }

  /// Deterministic same-side episode clustering. This prevents ATR/ADX (and any
  /// other overlapping segment) from being counted as multiple opportunities.
  /// Opposite sides are never merged, so conflicts remain visible downstream.
  List<PaperForwardCandidateCluster> cluster(
    List<PaperForwardPortfolioCandidate> candidates,
  ) {
    if (candidates.isEmpty) {
      return const [];
    }
    final ordered = [
      ...candidates,
    ]..sort((a, b) => a.candidate.observedAt.compareTo(b.candidate.observedAt));
    final clusters = <PaperForwardCandidateCluster>[];

    for (final item in ordered) {
      final time = item.candidate.observedAt;
      var target = -1;
      for (var i = clusters.length - 1; i >= 0; i--) {
        final cluster = clusters[i];
        final delta = time.difference(cluster.anchorTime).inMinutes;
        if (delta > clusterMinutes) {
          break;
        }
        if (cluster.side == item.candidate.side && delta >= 0) {
          target = i;
          break;
        }
      }

      if (target < 0) {
        clusters.add(
          PaperForwardCandidateCluster(
            side: item.candidate.side,
            anchorTime: time,
            members: <PaperForwardPortfolioCandidate>[item],
          ),
        );
      } else {
        final previous = clusters[target];
        clusters[target] = PaperForwardCandidateCluster(
          side: previous.side,
          anchorTime: previous.anchorTime,
          members: [...previous.members, item],
        );
      }
    }
    return clusters;
  }
}
