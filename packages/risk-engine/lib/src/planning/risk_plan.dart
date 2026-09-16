import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';

import '../eligibility/minimum_risk_reward.dart';
import '../eligibility/risk_eligibility.dart';
import '../entry/entry_zone.dart';
import '../reward/risk_reward.dart';
import '../stop/atr_stop_buffer.dart';
import '../stop/protective_stop.dart';
import '../stop/structural_stop.dart';
import '../target/target_candidate.dart';

/// Unified output of the Phase 5 risk-planning pipeline.
///
/// Every intermediate artifact is retained so later signal generation,
/// explanations, and backtesting can inspect exactly why a setup passed or
/// failed risk eligibility.
final class RiskPlanAnalysis {
  const RiskPlanAnalysis({
    required this.entryZoneAnalysis,
    required this.structuralStopAnalysis,
    required this.protectiveStopAnalysis,
    required this.targetAnalysis,
    required this.riskRewardAnalysis,
    required this.minimumRiskRewardGateResult,
    required this.eligibility,
  });

  final EntryZoneAnalysis entryZoneAnalysis;
  final StructuralStopAnalysis structuralStopAnalysis;
  final ProtectiveStopAnalysis protectiveStopAnalysis;
  final TargetCandidateAnalysis targetAnalysis;
  final RiskRewardAnalysis riskRewardAnalysis;
  final MinimumRiskRewardGateResult minimumRiskRewardGateResult;
  final RiskEligibility eligibility;

  bool get isEligible => eligibility.isEligible;
}

/// Integrates the existing Phase 5 components without adding new trading rules.
///
/// Entry price policy remains explicit: callers supply [entryPrice]. This
/// orchestrator does not silently choose Entry Zone midpoint/edge or assume an
/// execution fill.
///
/// ATR and its multiplier are also explicit research inputs. Target selection
/// uses the existing nearest opposing active Key Level policy.
final class RiskPlanOrchestrator {
  const RiskPlanOrchestrator({
    this.entryZonePlanner = const EntryZonePlanner(),
    this.structuralStopPlanner = const StructuralStopPlanner(),
    this.atrStopBufferPolicy = const AtrStopBufferPolicy(),
    this.protectiveStopPlanner = const ProtectiveStopPlanner(),
    this.targetCandidatePlanner = const TargetCandidatePlanner(),
    this.riskRewardCalculator = const RiskRewardCalculator(),
    this.minimumRiskRewardGate = const MinimumRiskRewardGate(),
    this.riskEligibilityEvaluator = const RiskEligibilityEvaluator(),
  });

  final EntryZonePlanner entryZonePlanner;
  final StructuralStopPlanner structuralStopPlanner;
  final AtrStopBufferPolicy atrStopBufferPolicy;
  final ProtectiveStopPlanner protectiveStopPlanner;
  final TargetCandidatePlanner targetCandidatePlanner;
  final RiskRewardCalculator riskRewardCalculator;
  final MinimumRiskRewardGate minimumRiskRewardGate;
  final RiskEligibilityEvaluator riskEligibilityEvaluator;

  RiskPlanAnalysis analyze({
    required TradingBias bias,
    required SetupEvidenceSnapshot setupSnapshot,
    required PullbackAnalysis pullback,
    required double entryPrice,
    required double atr,
    required AtrStopBufferMultiplier atrMultiplier,
    required Iterable<KeyLevel> keyLevels,
    required MinimumRiskRewardPolicy minimumRiskRewardPolicy,
  }) {
    final entryZone = entryZonePlanner.plan(
      snapshot: setupSnapshot,
      pullback: pullback,
    );

    final structuralStop = structuralStopPlanner.plan(
      bias: bias,
      entryZoneAnalysis: entryZone,
    );

    final protectiveStop = _planProtectiveStop(
      structuralStop: structuralStop,
      atr: atr,
      atrMultiplier: atrMultiplier,
    );

    final target = targetCandidatePlanner.plan(
      bias: bias,
      referencePrice: entryPrice,
      keyLevels: keyLevels,
    );

    final riskReward = _calculateRiskReward(
      bias: bias,
      entryPrice: entryPrice,
      protectiveStop: protectiveStop,
      target: target,
    );

    final minimumRr = minimumRiskRewardGate.evaluate(
      analysis: riskReward,
      policy: minimumRiskRewardPolicy,
    );

    final eligibility = riskEligibilityEvaluator.evaluate(
      entryZoneAnalysis: entryZone,
      protectiveStopAnalysis: protectiveStop,
      targetAnalysis: target,
      riskRewardAnalysis: riskReward,
      minimumRiskRewardGateResult: minimumRr,
    );

    return RiskPlanAnalysis(
      entryZoneAnalysis: entryZone,
      structuralStopAnalysis: structuralStop,
      protectiveStopAnalysis: protectiveStop,
      targetAnalysis: target,
      riskRewardAnalysis: riskReward,
      minimumRiskRewardGateResult: minimumRr,
      eligibility: eligibility,
    );
  }

  ProtectiveStopAnalysis _planProtectiveStop({
    required StructuralStopAnalysis structuralStop,
    required double atr,
    required AtrStopBufferMultiplier atrMultiplier,
  }) {
    if (!structuralStop.isAvailable) {
      return const ProtectiveStopAnalysis.unavailable(
        ProtectiveStopUnavailableReason.noStructuralStop,
      );
    }

    final buffer = atrStopBufferPolicy.create(
      atr: atr,
      multiplier: atrMultiplier,
    );

    return protectiveStopPlanner.plan(
      structuralStopAnalysis: structuralStop,
      buffer: buffer,
    );
  }

  RiskRewardAnalysis _calculateRiskReward({
    required TradingBias bias,
    required double entryPrice,
    required ProtectiveStopAnalysis protectiveStop,
    required TargetCandidateAnalysis target,
  }) {
    final stop = protectiveStop.stop;
    final targetCandidate = target.target;

    if (!protectiveStop.isAvailable ||
        stop == null ||
        !target.isAvailable ||
        targetCandidate == null) {
      return _invalidRiskReward(bias: bias, entryPrice: entryPrice);
    }

    return riskRewardCalculator.calculate(
      bias: bias,
      entryPrice: entryPrice,
      stopPrice: stop.price,
      targetPrice: targetCandidate.price,
    );
  }

  RiskRewardAnalysis _invalidRiskReward({
    required TradingBias bias,
    required double entryPrice,
  }) {
    // Produce a typed invalid RR result using the calculator's own geometry
    // validation rather than constructing internal result state here.
    return switch (bias) {
      TradingBias.buy => riskRewardCalculator.calculate(
        bias: bias,
        entryPrice: entryPrice,
        stopPrice: entryPrice,
        targetPrice: entryPrice + 1,
      ),
      TradingBias.sell => riskRewardCalculator.calculate(
        bias: bias,
        entryPrice: entryPrice,
        stopPrice: entryPrice,
        targetPrice: entryPrice - 1,
      ),
      TradingBias.noTrade => riskRewardCalculator.calculate(
        bias: bias,
        entryPrice: entryPrice,
        stopPrice: entryPrice,
        targetPrice: entryPrice,
      ),
    };
  }
}
