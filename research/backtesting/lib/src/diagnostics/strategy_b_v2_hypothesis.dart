/// Frozen Increment 097 research hypothesis for Strategy B v2.
///
/// This is deliberately not a production strategy gate. It records the single
/// falsifiable rule selected from Increment 096 discovery so Increment 098 can
/// validate it on a fresh replay without silently changing the hypothesis.
final class StrategyBV2Hypothesis {
  const StrategyBV2Hypothesis._();

  static const String id = 'strategy-b-v2-hypothesis-097-v1';

  /// Candidate must already satisfy the unchanged Strategy B v1 setup and
  /// risk-plan requirements, including planned RR >= 2.0.
  static const double minimumPlannedRiskReward = 2.0;

  /// Research-only M15 realignment-body band selected before validation.
  static const double minimumRealignmentBodyAtr = 0.50;
  static const double maximumRealignmentBodyAtr = 1.00;

  /// Increment 096 found these potentially informative, but they are not part
  /// of the v2 hypothesis gate. Keeping this explicit prevents accidental
  /// multi-feature tuning during validation.
  static const bool gateOnVolatilityRegime = false;
  static const bool gateOnCorrectionDuration = false;
  static const bool gateOnCorrectionExcursion = false;
  static const bool gateOnDirectionalCloseLocation = false;

  /// The upper bound is exclusive, matching the discovery bucket [0.50, 1.00).
  static bool matchesRealignmentBody(double? bodyAtr) {
    if (bodyAtr == null || !bodyAtr.isFinite) return false;
    return bodyAtr >= minimumRealignmentBodyAtr &&
        bodyAtr < maximumRealignmentBodyAtr;
  }
}

/// Acceptance contract for the fresh Increment 098 validation.
///
/// These values freeze *how* the hypothesis will be judged; they do not claim
/// profitability and are not fed into candidate generation.
final class StrategyBV2ValidationPlan {
  const StrategyBV2ValidationPlan._();

  static const List<int> forwardHorizonsM5 = <int>[12, 24, 48];

  /// Baseline integrity checks from frozen Strategy B v1. A validation run is
  /// invalid if instrumentation changes these pre-hypothesis counts.
  static const int expectedBaselineCandidates = 203;
  static const int expectedBaselineRiskEligible = 12;

  /// Increment 098 must report the hypothesis subset separately from baseline,
  /// including continuation/rejection/unresolved and terminal trade outcomes.
  static const bool requireFreshHistoricalReplay = true;
  static const bool requireBaselineIntegrityCheck = true;
  static const bool requireHypothesisSubsetReport = true;
  static const bool requireTerminalLifecycleReport = true;

  /// Discovery data may be reported for comparison but must not be used to
  /// alter the frozen 097 body band during the same validation run.
  static const bool allowThresholdRetuningDuringValidation = false;
}
