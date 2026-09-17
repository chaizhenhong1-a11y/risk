import 'strategy_b_candidate_research_diagnostics.dart';
import 'strategy_b_research_snapshot.dart';

/// Research-only cross-sectional discovery over an already-built Strategy B
/// snapshot. It never changes candidate generation, risk eligibility, or
/// forward labels.
final class StrategyBCandidateFeatureDiscovery {
  const StrategyBCandidateFeatureDiscovery();

  StrategyBFeatureDiscoveryReport analyze(StrategyBResearchSnapshot snapshot) {
    final horizons = snapshot.samplesByHorizon.keys.toList()..sort();
    final sections = <StrategyBFeatureSection>[];
    for (final horizon in horizons) {
      final samples = snapshot.samplesByHorizon[horizon]!;
      sections.add(
        StrategyBFeatureSection(
          horizonM5: horizon,
          all: _summary(samples),
          byDirection: {
            for (final value in StrategyBCandidateDirection.values)
              value: _summary(samples.where((s) => s.direction == value)),
          },
          byVolatility: {
            for (final value in StrategyBVolatilityBucket.values)
              value: _summary(
                samples.where((s) => s.volatilityBucket == value),
              ),
          },
          byRiskReward: {
            for (final value in StrategyBTargetRoomBucket.values)
              value: _summary(
                samples.where((s) => s.targetRoomBucket == value),
              ),
          },
          eligibleOnly: _summary(samples.where((s) => s.riskEligible)),
          eligibleByVolatility: {
            for (final value in StrategyBVolatilityBucket.values)
              value: _summary(
                samples.where(
                  (s) => s.riskEligible && s.volatilityBucket == value,
                ),
              ),
          },
        ),
      );
    }
    return StrategyBFeatureDiscoveryReport(
      candidateCount: snapshot.records.length,
      sections: sections,
    );
  }

  StrategyBFeatureSummary _summary(
    Iterable<StrategyBCandidateResearchSample> values,
  ) {
    var candidates = 0;
    var eligible = 0;
    var continuation = 0;
    var rejection = 0;
    var unresolved = 0;
    for (final sample in values) {
      candidates++;
      if (sample.riskEligible) eligible++;
      switch (sample.outcome) {
        case StrategyBCandidateOutcome.continuation:
          continuation++;
        case StrategyBCandidateOutcome.rejection:
          rejection++;
        case StrategyBCandidateOutcome.unresolved:
          unresolved++;
      }
    }
    return StrategyBFeatureSummary(
      candidates: candidates,
      eligible: eligible,
      continuation: continuation,
      rejection: rejection,
      unresolved: unresolved,
    );
  }
}

final class StrategyBFeatureDiscoveryReport {
  const StrategyBFeatureDiscoveryReport({
    required this.candidateCount,
    required this.sections,
  });

  final int candidateCount;
  final List<StrategyBFeatureSection> sections;
}

final class StrategyBFeatureSection {
  const StrategyBFeatureSection({
    required this.horizonM5,
    required this.all,
    required this.byDirection,
    required this.byVolatility,
    required this.byRiskReward,
    required this.eligibleOnly,
    required this.eligibleByVolatility,
  });

  final int horizonM5;
  final StrategyBFeatureSummary all;
  final Map<StrategyBCandidateDirection, StrategyBFeatureSummary> byDirection;
  final Map<StrategyBVolatilityBucket, StrategyBFeatureSummary> byVolatility;
  final Map<StrategyBTargetRoomBucket, StrategyBFeatureSummary> byRiskReward;
  final StrategyBFeatureSummary eligibleOnly;
  final Map<StrategyBVolatilityBucket, StrategyBFeatureSummary>
  eligibleByVolatility;
}

final class StrategyBFeatureSummary {
  const StrategyBFeatureSummary({
    required this.candidates,
    required this.eligible,
    required this.continuation,
    required this.rejection,
    required this.unresolved,
  });

  final int candidates;
  final int eligible;
  final int continuation;
  final int rejection;
  final int unresolved;

  int get resolved => continuation + rejection;
  double? get continuationRate =>
      resolved == 0 ? null : continuation / resolved;
  double? get eligibilityRate => candidates == 0 ? null : eligible / candidates;
}
