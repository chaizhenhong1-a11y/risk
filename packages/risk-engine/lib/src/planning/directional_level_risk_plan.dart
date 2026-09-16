import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';

import '../eligibility/minimum_risk_reward.dart';
import '../stop/atr_stop_buffer.dart';
import 'risk_plan.dart';

/// Risk-plan adapter for a directional setup that has no pre-existing
/// pullback object.
///
/// Research policy:
/// BUY  -> nearest active support at/below [referencePrice].
/// SELL -> nearest active resistance at/above [referencePrice].
///
/// The selected level becomes the future Entry Zone. The frozen Phase 5
/// structural-stop, ATR-buffer, target, RR and minimum-RR components are then
/// reused unchanged.
final class DirectionalLevelRiskPlanOrchestrator {
  const DirectionalLevelRiskPlanOrchestrator({
    this.riskPlanOrchestrator = const RiskPlanOrchestrator(),
  });

  final RiskPlanOrchestrator riskPlanOrchestrator;

  RiskPlanAnalysis? analyze({
    required TradingBias bias,
    required double referencePrice,
    required double atr,
    required AtrStopBufferMultiplier atrMultiplier,
    required Iterable<KeyLevel> keyLevels,
    required MinimumRiskRewardPolicy minimumRiskRewardPolicy,
  }) {
    if (bias == TradingBias.noTrade) return null;
    if (!referencePrice.isFinite) {
      throw ArgumentError.value(
        referencePrice,
        'referencePrice',
        'Reference price must be finite.',
      );
    }

    final levels = keyLevels.toList(growable: false);
    final entryLevel = _nearestDirectionalLevel(
      bias: bias,
      referencePrice: referencePrice,
      keyLevels: levels,
    );
    if (entryLevel == null) return null;

    final snapshot = SetupEvidenceSnapshot(
      eligibility: SetupEligibility.eligible,
      blockReason: null,
      evidence: const [
        SetupEvidence(type: SetupEvidenceType.directionalBias, present: true),
        SetupEvidence(
          type: SetupEvidenceType.directionalM15Structure,
          present: true,
        ),
      ],
      d1ContextAlignment: D1ContextAlignment.unavailable,
      keyLevelQuality: KeyLevelQuality.unavailable,
    );
    final pullback = PullbackAnalysis(
      state: PullbackState.inZone,
      reason: bias == TradingBias.buy
          ? PullbackReason.priceAtSupport
          : PullbackReason.priceAtResistance,
      matchedLevel: entryLevel,
    );

    return riskPlanOrchestrator.analyze(
      bias: bias,
      setupSnapshot: snapshot,
      pullback: pullback,
      entryPrice: entryLevel.midpoint,
      atr: atr,
      atrMultiplier: atrMultiplier,
      keyLevels: levels,
      minimumRiskRewardPolicy: minimumRiskRewardPolicy,
    );
  }

  KeyLevel? _nearestDirectionalLevel({
    required TradingBias bias,
    required double referencePrice,
    required Iterable<KeyLevel> keyLevels,
  }) {
    final type = bias == TradingBias.buy
        ? KeyLevelType.support
        : KeyLevelType.resistance;

    KeyLevel? nearest;
    for (final level in keyLevels) {
      if (!level.isActive || level.type != type) continue;

      final isBehindOrAtPrice = bias == TradingBias.buy
          ? level.midpoint <= referencePrice
          : level.midpoint >= referencePrice;
      if (!isBehindOrAtPrice) continue;

      if (nearest == null) {
        nearest = level;
        continue;
      }

      final candidateDistance = (referencePrice - level.midpoint).abs();
      final nearestDistance = (referencePrice - nearest.midpoint).abs();
      if (candidateDistance < nearestDistance ||
          (candidateDistance == nearestDistance &&
              level.createdAtCandleIndex > nearest.createdAtCandleIndex)) {
        nearest = level;
      }
    }
    return nearest;
  }
}
