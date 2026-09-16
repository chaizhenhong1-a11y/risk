import 'package:risk_engine/risk_engine.dart';
import 'package:signal_engine/signal_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  const controller = HistoricalReadySignalController();

  group('HistoricalReadySignalController', () {
    test('qualified candidate reaches READY through the frozen lifecycle', () {
      final candidate = _qualifiedCandidate();

      final state = controller.start(
        candidate: candidate,
        observationIndex: 12,
      );

      expect(state, isNotNull);
      expect(state!.candidate, same(candidate));
      expect(state.readyAtObservationIndex, 12);
      expect(state.waitingCandles, 0);
      expect(state.lifecycleState, SignalLifecycleState.ready);
    });

    test('blocked candidate never creates READY historical state', () {
      final state = controller.start(
        candidate: _blockedCandidate(),
        observationIndex: 12,
      );

      expect(state, isNull);
    });

    test(
      'each later closed M5 observation increments waiting exactly once',
      () {
        final initial = controller.start(
          candidate: _qualifiedCandidate(),
          observationIndex: 12,
        )!;

        final afterOne = controller.observeNextClosedM5Candle(initial);
        final afterTwo = controller.observeNextClosedM5Candle(afterOne);

        expect(initial.waitingCandles, 0);
        expect(afterOne.waitingCandles, 1);
        expect(afterTwo.waitingCandles, 2);
        expect(afterTwo.readyAtObservationIndex, 12);
        expect(afterTwo.lifecycleState, SignalLifecycleState.ready);
        expect(afterTwo.candidate, same(initial.candidate));
      },
    );

    test('waiting does not mutate the prior historical state', () {
      final initial = controller.start(
        candidate: _qualifiedCandidate(),
        observationIndex: 3,
      )!;

      final next = controller.observeNextClosedM5Candle(initial);

      expect(initial.waitingCandles, 0);
      expect(next.waitingCandles, 1);
      expect(next, isNot(same(initial)));
    });

    test('negative historical observation index is rejected', () {
      expect(
        () => controller.start(
          candidate: _qualifiedCandidate(),
          observationIndex: -1,
        ),
        throwsArgumentError,
      );
    });
  });
}

SignalCandidate _qualifiedCandidate() {
  final fixture = _fixture();
  return SignalCandidate.qualified(
    direction: SignalCandidateDirection.buy,
    setupSnapshot: fixture.snapshot,
    setupScore: fixture.score,
    riskPlan: fixture.riskPlan,
  );
}

SignalCandidate _blockedCandidate() {
  final fixture = _fixture();
  return SignalCandidate.blocked(
    direction: SignalCandidateDirection.buy,
    blockReason: SignalCandidateBlockReason.riskPlanBlocked,
    setupSnapshot: fixture.snapshot,
    setupScore: fixture.score,
    riskPlan: fixture.riskPlan,
  );
}

({
  SetupEvidenceSnapshot snapshot,
  SetupScoreResult score,
  RiskPlanAnalysis riskPlan,
})
_fixture() {
  // Reuse public frozen value types only. The exact numeric values are not
  // trading parameters; this fixture tests historical lifecycle state.
  final snapshot = SetupEvidenceSnapshot(
    eligibility: SetupEligibility.eligible,
    blockReason: null,
    evidence: const [],
    d1ContextAlignment: D1ContextAlignment.unavailable,
    keyLevelQuality: KeyLevelQuality.unavailable,
  );

  final score = SetupScoreResult(
    earnedPoints: 0,
    availablePoints: 0,
    contributions: const {},
  );

  final riskPlan = RiskPlanAnalysis(
    entryZoneAnalysis: const EntryZoneAnalysis.unavailable(
      EntryZoneUnavailableReason.noMatchedPullbackLevel,
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
    riskRewardAnalysis: const RiskRewardAnalysis.invalid(
      RiskRewardInvalidReason.invalidBuyStop,
    ),
    minimumRiskRewardGateResult: const MinimumRiskRewardGateResult.blocked(
      minimumRatio: 2,
      reason: MinimumRiskRewardBlockReason.invalidRiskReward,
    ),
    eligibility: const RiskEligibility.blocked(
      RiskEligibilityBlockReason.protectiveStopUnavailable,
    ),
  );

  return (snapshot: snapshot, score: score, riskPlan: riskPlan);
}
