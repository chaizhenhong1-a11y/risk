enum PerformanceSampleQuality { insufficient, early, developing, established }

final class PerformanceSampleAssessment {
  const PerformanceSampleAssessment({
    required this.tradeCount,
    required this.quality,
    required this.minimumRequired,
  });

  final int tradeCount;
  final PerformanceSampleQuality quality;
  final int minimumRequired;

  bool get isSufficient => tradeCount >= minimumRequired;

  String get label => switch (quality) {
    PerformanceSampleQuality.insufficient => 'INSUFFICIENT SAMPLE',
    PerformanceSampleQuality.early => 'EARLY SAMPLE',
    PerformanceSampleQuality.developing => 'DEVELOPING SAMPLE',
    PerformanceSampleQuality.established => 'ESTABLISHED SAMPLE',
  };
}

/// Reporting context only. This never approves, rejects, or gates a strategy.
final class PerformanceSampleQualityAssessor {
  const PerformanceSampleQualityAssessor({
    this.minimumRequired = 30,
    this.developingThreshold = 100,
    this.establishedThreshold = 300,
  }) : assert(minimumRequired > 0),
       assert(developingThreshold >= minimumRequired),
       assert(establishedThreshold >= developingThreshold);

  final int minimumRequired;
  final int developingThreshold;
  final int establishedThreshold;

  PerformanceSampleAssessment assess(int tradeCount) {
    final quality = tradeCount < minimumRequired
        ? PerformanceSampleQuality.insufficient
        : tradeCount < developingThreshold
        ? PerformanceSampleQuality.early
        : tradeCount < establishedThreshold
        ? PerformanceSampleQuality.developing
        : PerformanceSampleQuality.established;

    return PerformanceSampleAssessment(
      tradeCount: tradeCount,
      quality: quality,
      minimumRequired: minimumRequired,
    );
  }
}
