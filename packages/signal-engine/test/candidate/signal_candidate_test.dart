import 'package:risk_engine/risk_engine.dart';
import 'package:signal_engine/signal_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:test/test.dart';

void main() {
  const builder = SignalCandidateBuilder();

  group('SignalCandidateBuilder', () {
    test('qualifies BUY when strategy and risk are both eligible', () {
      final candidate = builder.build(
        bias: TradingBias.buy,
        setupSnapshot: _eligibleSnapshot(),
        setupScore: _score(),
        riskPlan: _riskPlan(eligible: true),
      );

      expect(candidate.isQualified, isTrue);
      expect(candidate.direction, SignalCandidateDirection.buy);
      expect(candidate.blockReason, isNull);
      expect(candidate.setupScore.earnedPoints, 40);
    });

    test('qualifies SELL when strategy and risk are both eligible', () {
      final candidate = builder.build(
        bias: TradingBias.sell,
        setupSnapshot: _eligibleSnapshot(),
        setupScore: _score(),
        riskPlan: _riskPlan(eligible: true),
      );

      expect(candidate.isQualified, isTrue);
      expect(candidate.direction, SignalCandidateDirection.sell);
    });

    test('strategy Gate remains authoritative regardless of score', () {
      final candidate = builder.build(
        bias: TradingBias.buy,
        setupSnapshot: _blockedSnapshot(),
        setupScore: _score(earned: 100),
        riskPlan: _riskPlan(eligible: true),
      );

      expect(candidate.isQualified, isFalse);
      expect(
        candidate.blockReason,
        SignalCandidateBlockReason.strategySetupBlocked,
      );
    });

    test('risk Gate remains authoritative regardless of score', () {
      final candidate = builder.build(
        bias: TradingBias.buy,
        setupSnapshot: _eligibleSnapshot(),
        setupScore: _score(earned: 100),
        riskPlan: _riskPlan(eligible: false),
      );

      expect(candidate.isQualified, isFalse);
      expect(candidate.blockReason, SignalCandidateBlockReason.riskPlanBlocked);
    });

    test('NO TRADE bias cannot become a qualified candidate', () {
      final candidate = builder.build(
        bias: TradingBias.noTrade,
        setupSnapshot: _eligibleSnapshot(),
        setupScore: _score(),
        riskPlan: _riskPlan(eligible: true),
      );

      expect(candidate.isQualified, isFalse);
      expect(candidate.direction, SignalCandidateDirection.noTrade);
      expect(
        candidate.blockReason,
        SignalCandidateBlockReason.noDirectionalBias,
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

SetupScoreResult _score({double earned = 40}) => SetupScoreResult(
  earnedPoints: earned,
  availablePoints: 100,
  contributions: const {},
);

RiskPlanAnalysis _riskPlan({required bool eligible}) {
  const rr = RiskReward(
    entryPrice: 2300,
    stopPrice: 2295,
    targetPrice: 2310,
    riskDistance: 5,
    rewardDistance: 10,
    ratio: 2,
    bias: TradingBias.buy,
  );
  final rrAnalysis = RiskRewardAnalysis.valid(rr);
  final minimumGate = eligible
      ? MinimumRiskRewardGateResult.passed(minimumRatio: 2, actualRatio: 2)
      : MinimumRiskRewardGateResult.blocked(
          minimumRatio: 2,
          actualRatio: 1.5,
          reason: MinimumRiskRewardBlockReason.belowMinimumRatio,
        );

  return RiskPlanAnalysis(
    entryZoneAnalysis: const EntryZoneAnalysis.unavailable(
      EntryZoneUnavailableReason.setupBlocked,
    ),
    structuralStopAnalysis: const StructuralStopAnalysis.unavailable(
      StructuralStopUnavailableReason.noEntryZone,
    ),
    protectiveStopAnalysis: const ProtectiveStopAnalysis.unavailable(
      ProtectiveStopUnavailableReason.noStructuralStop,
    ),
    targetAnalysis: const TargetCandidateAnalysis.unavailable(
      TargetCandidateUnavailableReason.noOpposingActiveLevelAhead,
    ),
    riskRewardAnalysis: rrAnalysis,
    minimumRiskRewardGateResult: minimumGate,
    eligibility: eligible
        ? RiskEligibility.eligible(riskReward: rr, minimumRiskReward: 2)
        : RiskEligibility.blocked(
            RiskEligibilityBlockReason.belowMinimumRiskReward,
            riskReward: rr,
            minimumRiskReward: 2,
          ),
  );
}
