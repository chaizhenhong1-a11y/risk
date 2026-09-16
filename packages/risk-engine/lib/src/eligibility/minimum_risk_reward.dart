import '../reward/risk_reward.dart';

/// Explicit minimum RR threshold used by the risk eligibility layer.
///
/// No default threshold is provided. Values such as 1.5, 2.0, or 2.5 are
/// research parameters that must be calibrated with backtesting rather than
/// treated as universal trading rules.
final class MinimumRiskRewardPolicy {
  MinimumRiskRewardPolicy(this.minimumRatio) {
    if (!minimumRatio.isFinite || minimumRatio <= 0) {
      throw ArgumentError.value(
        minimumRatio,
        'minimumRatio',
        'Minimum RR must be finite and greater than zero.',
      );
    }
  }

  final double minimumRatio;
}

enum MinimumRiskRewardGateStatus { blocked, passed }

enum MinimumRiskRewardBlockReason { invalidRiskReward, belowMinimumRatio }

/// Result of applying a configurable minimum-RR hard gate.
///
/// This result does not alter the original [RiskRewardAnalysis]. It only
/// records whether that measurement satisfies the supplied policy.
final class MinimumRiskRewardGateResult {
  const MinimumRiskRewardGateResult._({
    required this.status,
    required this.minimumRatio,
    this.actualRatio,
    this.blockReason,
  });

  const MinimumRiskRewardGateResult.passed({
    required double minimumRatio,
    required double actualRatio,
  }) : this._(
         status: MinimumRiskRewardGateStatus.passed,
         minimumRatio: minimumRatio,
         actualRatio: actualRatio,
       );

  const MinimumRiskRewardGateResult.blocked({
    required double minimumRatio,
    required MinimumRiskRewardBlockReason reason,
    double? actualRatio,
  }) : this._(
         status: MinimumRiskRewardGateStatus.blocked,
         minimumRatio: minimumRatio,
         actualRatio: actualRatio,
         blockReason: reason,
       );

  final MinimumRiskRewardGateStatus status;
  final double minimumRatio;
  final double? actualRatio;
  final MinimumRiskRewardBlockReason? blockReason;

  bool get isPassed => status == MinimumRiskRewardGateStatus.passed;
}

/// Applies minimum RR as an explicit hard risk gate.
///
/// Equality passes: an actual RR of 2.0 satisfies a minimum RR of 2.0.
/// The threshold is never chosen by this evaluator.
final class MinimumRiskRewardGate {
  const MinimumRiskRewardGate();

  MinimumRiskRewardGateResult evaluate({
    required RiskRewardAnalysis analysis,
    required MinimumRiskRewardPolicy policy,
  }) {
    if (!analysis.isValid || analysis.riskReward == null) {
      return MinimumRiskRewardGateResult.blocked(
        minimumRatio: policy.minimumRatio,
        reason: MinimumRiskRewardBlockReason.invalidRiskReward,
      );
    }

    final actualRatio = analysis.riskReward!.ratio;

    if (actualRatio < policy.minimumRatio) {
      return MinimumRiskRewardGateResult.blocked(
        minimumRatio: policy.minimumRatio,
        actualRatio: actualRatio,
        reason: MinimumRiskRewardBlockReason.belowMinimumRatio,
      );
    }

    return MinimumRiskRewardGateResult.passed(
      minimumRatio: policy.minimumRatio,
      actualRatio: actualRatio,
    );
  }
}
