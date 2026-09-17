enum StrategyBCandidateDirection { buy, sell }

enum StrategyBCandidateOutcome { continuation, rejection, unresolved }

enum StrategyBTargetRoomBucket {
  belowOnePointFiveR,
  onePointFiveToTwoR,
  twoToTwoPointFiveR,
  twoPointFiveToThreeR,
  atLeastThreeR,
}

enum StrategyBPullbackDepthBucket {
  shallow,
  moderate,
  deep,
  veryDeep,
  unavailable,
}

enum StrategyBVolatilityBucket { compressed, normal, expanded, unavailable }

final class StrategyBCandidateResearchSample {
  const StrategyBCandidateResearchSample({
    required this.direction,
    required this.rawRiskReward,
    required this.targetRoomAtr,
    required this.pullbackDepthAtr,
    required this.atrRelativeToMedian,
    required this.riskEligible,
    required this.outcome,
  });

  final StrategyBCandidateDirection direction;
  final double? rawRiskReward;
  final double? targetRoomAtr;
  final double? pullbackDepthAtr;
  final double? atrRelativeToMedian;
  final bool riskEligible;
  final StrategyBCandidateOutcome outcome;

  StrategyBTargetRoomBucket? get targetRoomBucket {
    final value = rawRiskReward;
    if (value == null || !value.isFinite || value < 0) return null;
    if (value < 1.5) return StrategyBTargetRoomBucket.belowOnePointFiveR;
    if (value < 2.0) return StrategyBTargetRoomBucket.onePointFiveToTwoR;
    if (value < 2.5) return StrategyBTargetRoomBucket.twoToTwoPointFiveR;
    if (value < 3.0) return StrategyBTargetRoomBucket.twoPointFiveToThreeR;
    return StrategyBTargetRoomBucket.atLeastThreeR;
  }

  StrategyBPullbackDepthBucket get pullbackDepthBucket {
    final value = pullbackDepthAtr;
    if (value == null || !value.isFinite || value < 0) {
      return StrategyBPullbackDepthBucket.unavailable;
    }
    if (value < 0.5) return StrategyBPullbackDepthBucket.shallow;
    if (value < 1.0) return StrategyBPullbackDepthBucket.moderate;
    if (value < 1.5) return StrategyBPullbackDepthBucket.deep;
    return StrategyBPullbackDepthBucket.veryDeep;
  }

  StrategyBVolatilityBucket get volatilityBucket {
    final value = atrRelativeToMedian;
    if (value == null || !value.isFinite || value <= 0) {
      return StrategyBVolatilityBucket.unavailable;
    }
    if (value < 0.8) return StrategyBVolatilityBucket.compressed;
    if (value <= 1.2) return StrategyBVolatilityBucket.normal;
    return StrategyBVolatilityBucket.expanded;
  }
}

final class StrategyBCandidateBucketSummary<T extends Enum> {
  StrategyBCandidateBucketSummary(this.bucket);

  final T bucket;
  int candidates = 0;
  int riskEligible = 0;
  int continuation = 0;
  int rejection = 0;
  int unresolved = 0;
  double targetRoomAtrTotal = 0;
  int targetRoomAtrSamples = 0;

  double? get riskEligibilityRate =>
      candidates == 0 ? null : riskEligible / candidates;
  double? get resolvedContinuationRate {
    final resolved = continuation + rejection;
    return resolved == 0 ? null : continuation / resolved;
  }

  double? get averageTargetRoomAtr => targetRoomAtrSamples == 0
      ? null
      : targetRoomAtrTotal / targetRoomAtrSamples;

  void add(StrategyBCandidateResearchSample sample) {
    candidates++;
    if (sample.riskEligible) riskEligible++;
    switch (sample.outcome) {
      case StrategyBCandidateOutcome.continuation:
        continuation++;
      case StrategyBCandidateOutcome.rejection:
        rejection++;
      case StrategyBCandidateOutcome.unresolved:
        unresolved++;
    }
    final room = sample.targetRoomAtr;
    if (room != null && room.isFinite && room >= 0) {
      targetRoomAtrTotal += room;
      targetRoomAtrSamples++;
    }
  }
}

/// Research-only Strategy B v2 candidate diagnostics.
///
/// This collector never decides whether a live/backtest candidate is allowed.
/// Forward outcomes are labels supplied after the candidate is formed and must
/// never be fed back into candidate generation. This keeps the research path
/// free of look-ahead leakage.
final class StrategyBCandidateResearchDiagnostics {
  final List<StrategyBCandidateResearchSample> _samples = [];

  List<StrategyBCandidateResearchSample> get samples =>
      List.unmodifiable(_samples);

  int get candidateCount => _samples.length;
  int get riskEligibleCount =>
      _samples.where((sample) => sample.riskEligible).length;

  void add(StrategyBCandidateResearchSample sample) => _samples.add(sample);

  Map<
    StrategyBTargetRoomBucket,
    StrategyBCandidateBucketSummary<StrategyBTargetRoomBucket>
  >
  summarizeTargetRoom() => _summarize(
    StrategyBTargetRoomBucket.values,
    (sample) => sample.targetRoomBucket,
  );

  Map<
    StrategyBPullbackDepthBucket,
    StrategyBCandidateBucketSummary<StrategyBPullbackDepthBucket>
  >
  summarizePullbackDepth() => _summarize(
    StrategyBPullbackDepthBucket.values,
    (sample) => sample.pullbackDepthBucket,
  );

  Map<
    StrategyBVolatilityBucket,
    StrategyBCandidateBucketSummary<StrategyBVolatilityBucket>
  >
  summarizeVolatility() => _summarize(
    StrategyBVolatilityBucket.values,
    (sample) => sample.volatilityBucket,
  );

  Map<T, StrategyBCandidateBucketSummary<T>> _summarize<T extends Enum>(
    Iterable<T> buckets,
    T? Function(StrategyBCandidateResearchSample sample) selector,
  ) {
    final result = <T, StrategyBCandidateBucketSummary<T>>{
      for (final bucket in buckets)
        bucket: StrategyBCandidateBucketSummary(bucket),
    };
    for (final sample in _samples) {
      final bucket = selector(sample);
      if (bucket != null) result[bucket]!.add(sample);
    }
    return Map.unmodifiable(result);
  }
}
