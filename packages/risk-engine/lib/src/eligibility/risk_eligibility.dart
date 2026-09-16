import '../entry/entry_zone.dart';
import '../reward/risk_reward.dart';
import '../stop/protective_stop.dart';
import '../target/target_candidate.dart';
import 'minimum_risk_reward.dart';

enum RiskEligibilityStatus { blocked, eligible }

enum RiskEligibilityBlockReason {
  entryZoneUnavailable,
  protectiveStopUnavailable,
  targetUnavailable,
  invalidRiskReward,
  belowMinimumRiskReward,
}

/// Unified Phase 5 risk-eligibility result.
///
/// This object does not create a BUY/SELL signal. It only answers whether an
/// already-eligible strategy setup has enough valid risk geometry to continue
/// toward the future Signal Engine.
final class RiskEligibility {
  const RiskEligibility._({
    required this.status,
    this.blockReason,
    this.riskReward,
    this.minimumRiskReward,
  });

  const RiskEligibility.eligible({
    required RiskReward riskReward,
    required double minimumRiskReward,
  }) : this._(
         status: RiskEligibilityStatus.eligible,
         riskReward: riskReward,
         minimumRiskReward: minimumRiskReward,
       );

  const RiskEligibility.blocked(
    RiskEligibilityBlockReason reason, {
    RiskReward? riskReward,
    double? minimumRiskReward,
  }) : this._(
         status: RiskEligibilityStatus.blocked,
         blockReason: reason,
         riskReward: riskReward,
         minimumRiskReward: minimumRiskReward,
       );

  final RiskEligibilityStatus status;
  final RiskEligibilityBlockReason? blockReason;
  final RiskReward? riskReward;
  final double? minimumRiskReward;

  bool get isEligible => status == RiskEligibilityStatus.eligible;
}

/// Integrates the Phase 5 risk prerequisites into one deterministic decision.
///
/// Order matters: missing upstream price components are reported before RR
/// validation, and RR validity is checked before the configurable minimum-RR
/// hard gate.
final class RiskEligibilityEvaluator {
  const RiskEligibilityEvaluator();

  RiskEligibility evaluate({
    required EntryZoneAnalysis entryZoneAnalysis,
    required ProtectiveStopAnalysis protectiveStopAnalysis,
    required TargetCandidateAnalysis targetAnalysis,
    required RiskRewardAnalysis riskRewardAnalysis,
    required MinimumRiskRewardGateResult minimumRiskRewardGateResult,
  }) {
    if (!entryZoneAnalysis.isAvailable) {
      return const RiskEligibility.blocked(
        RiskEligibilityBlockReason.entryZoneUnavailable,
      );
    }

    if (!protectiveStopAnalysis.isAvailable) {
      return const RiskEligibility.blocked(
        RiskEligibilityBlockReason.protectiveStopUnavailable,
      );
    }

    if (!targetAnalysis.isAvailable) {
      return const RiskEligibility.blocked(
        RiskEligibilityBlockReason.targetUnavailable,
      );
    }

    if (!riskRewardAnalysis.isValid || riskRewardAnalysis.riskReward == null) {
      return const RiskEligibility.blocked(
        RiskEligibilityBlockReason.invalidRiskReward,
      );
    }

    if (!minimumRiskRewardGateResult.isPassed) {
      final reason = switch (minimumRiskRewardGateResult.blockReason) {
        MinimumRiskRewardBlockReason.belowMinimumRatio =>
          RiskEligibilityBlockReason.belowMinimumRiskReward,
        MinimumRiskRewardBlockReason.invalidRiskReward ||
        null => RiskEligibilityBlockReason.invalidRiskReward,
      };

      return RiskEligibility.blocked(
        reason,
        riskReward: riskRewardAnalysis.riskReward,
        minimumRiskReward: minimumRiskRewardGateResult.minimumRatio,
      );
    }

    return RiskEligibility.eligible(
      riskReward: riskRewardAnalysis.riskReward!,
      minimumRiskReward: minimumRiskRewardGateResult.minimumRatio,
    );
  }
}
