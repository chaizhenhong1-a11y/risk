import 'package:risk_engine/risk_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const orchestrator = RiskPlanOrchestrator();

  group('RiskPlanOrchestrator', () {
    test('integrates an eligible BUY risk plan end to end', () {
      final support = _support(2299, 2301, 10);
      final resistance = _resistance(2310, 2312, 20);

      final result = orchestrator.analyze(
        bias: TradingBias.buy,
        setupSnapshot: _eligibleSnapshot(),
        pullback: _pullback(support),
        entryPrice: 2300,
        atr: 4,
        atrMultiplier: AtrStopBufferMultiplier(0.5),
        keyLevels: [support, resistance],
        minimumRiskRewardPolicy: MinimumRiskRewardPolicy(2),
      );

      expect(result.entryZoneAnalysis.zone!.lowerBound, 2299);
      expect(result.structuralStopAnalysis.stop!.price, 2299);
      expect(result.protectiveStopAnalysis.stop!.price, 2297);
      expect(result.targetAnalysis.target!.price, 2310);
      expect(result.riskRewardAnalysis.riskReward!.riskDistance, 3);
      expect(result.riskRewardAnalysis.riskReward!.rewardDistance, 10);
      expect(
        result.riskRewardAnalysis.riskReward!.ratio,
        closeTo(10 / 3, 1e-12),
      );
      expect(result.minimumRiskRewardGateResult.isPassed, isTrue);
      expect(result.isEligible, isTrue);
    });

    test('integrates an eligible SELL risk plan end to end', () {
      final resistance = _resistance(2299, 2301, 10);
      final support = _support(2288, 2290, 20);

      final result = orchestrator.analyze(
        bias: TradingBias.sell,
        setupSnapshot: _eligibleSnapshot(),
        pullback: _pullback(resistance),
        entryPrice: 2300,
        atr: 4,
        atrMultiplier: AtrStopBufferMultiplier(0.5),
        keyLevels: [resistance, support],
        minimumRiskRewardPolicy: MinimumRiskRewardPolicy(2),
      );

      expect(result.structuralStopAnalysis.stop!.price, 2301);
      expect(result.protectiveStopAnalysis.stop!.price, 2303);
      expect(result.targetAnalysis.target!.price, 2290);
      expect(result.riskRewardAnalysis.riskReward!.riskDistance, 3);
      expect(result.riskRewardAnalysis.riskReward!.rewardDistance, 10);
      expect(result.isEligible, isTrue);
    });

    test('below-minimum RR remains a typed risk block', () {
      final support = _support(2299, 2301, 10);
      final resistance = _resistance(2304, 2306, 20);

      final result = orchestrator.analyze(
        bias: TradingBias.buy,
        setupSnapshot: _eligibleSnapshot(),
        pullback: _pullback(support),
        entryPrice: 2300,
        atr: 4,
        atrMultiplier: AtrStopBufferMultiplier(0.5),
        keyLevels: [support, resistance],
        minimumRiskRewardPolicy: MinimumRiskRewardPolicy(2),
      );

      expect(
        result.riskRewardAnalysis.riskReward!.ratio,
        closeTo(4 / 3, 1e-12),
      );
      expect(result.minimumRiskRewardGateResult.isPassed, isFalse);
      expect(result.isEligible, isFalse);
      expect(
        result.eligibility.blockReason,
        RiskEligibilityBlockReason.belowMinimumRiskReward,
      );
    });

    test(
      'blocked setup preserves upstream failure through risk eligibility',
      () {
        final resistance = _resistance(2310, 2312, 20);

        final result = orchestrator.analyze(
          bias: TradingBias.buy,
          setupSnapshot: _blockedSnapshot(),
          pullback: const PullbackAnalysis(
            state: PullbackState.waiting,
            reason: PullbackReason.priceNotAtDirectionalLevel,
          ),
          entryPrice: 2300,
          atr: 4,
          atrMultiplier: AtrStopBufferMultiplier(0.5),
          keyLevels: [resistance],
          minimumRiskRewardPolicy: MinimumRiskRewardPolicy(2),
        );

        expect(result.entryZoneAnalysis.isAvailable, isFalse);
        expect(result.structuralStopAnalysis.isAvailable, isFalse);
        expect(result.protectiveStopAnalysis.isAvailable, isFalse);
        expect(result.isEligible, isFalse);
        expect(
          result.eligibility.blockReason,
          RiskEligibilityBlockReason.entryZoneUnavailable,
        );
      },
    );

    test('missing forward target is reported without inventing a TP', () {
      final support = _support(2299, 2301, 10);

      final result = orchestrator.analyze(
        bias: TradingBias.buy,
        setupSnapshot: _eligibleSnapshot(),
        pullback: _pullback(support),
        entryPrice: 2300,
        atr: 4,
        atrMultiplier: AtrStopBufferMultiplier(0.5),
        keyLevels: [support],
        minimumRiskRewardPolicy: MinimumRiskRewardPolicy(2),
      );

      expect(result.targetAnalysis.isAvailable, isFalse);
      expect(result.riskRewardAnalysis.isValid, isFalse);
      expect(result.isEligible, isFalse);
      expect(
        result.eligibility.blockReason,
        RiskEligibilityBlockReason.targetUnavailable,
      );
    });
  });
}

SetupEvidenceSnapshot _eligibleSnapshot() => SetupEvidenceSnapshot(
  eligibility: SetupEligibility.eligible,
  blockReason: null,
  evidence: const [],
  d1ContextAlignment: D1ContextAlignment.unavailable,
  keyLevelQuality: KeyLevelQuality.unavailable,
);

SetupEvidenceSnapshot _blockedSnapshot() => SetupEvidenceSnapshot(
  eligibility: SetupEligibility.blocked,
  blockReason: SetupBlockReason.pullbackNotPresent,
  evidence: const [],
  d1ContextAlignment: D1ContextAlignment.unavailable,
  keyLevelQuality: KeyLevelQuality.unavailable,
);

PullbackAnalysis _pullback(KeyLevel level) => PullbackAnalysis(
  state: PullbackState.inZone,
  reason: level.type == KeyLevelType.support
      ? PullbackReason.priceAtSupport
      : PullbackReason.priceAtResistance,
  matchedLevel: level,
);

KeyLevel _support(double lower, double upper, int index) => KeyLevel(
  type: KeyLevelType.support,
  source: KeyLevelSource.swingLow,
  status: KeyLevelStatus.active,
  lowerBound: lower,
  upperBound: upper,
  createdAtCandleIndex: index,
);

KeyLevel _resistance(double lower, double upper, int index) => KeyLevel(
  type: KeyLevelType.resistance,
  source: KeyLevelSource.swingHigh,
  status: KeyLevelStatus.active,
  lowerBound: lower,
  upperBound: upper,
  createdAtCandleIndex: index,
);
