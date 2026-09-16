import 'package:risk_engine/risk_engine.dart';
import 'package:signal_engine/signal_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  const controller = HistoricalPendingSignalValidityController();

  group('HistoricalPendingSignalValidityController', () {
    test('BUY remains waiting when close is exactly structural boundary', () {
      final result = controller.observeClosedM5Candle(
        state: _readyState(SignalCandidateDirection.buy),
        structuralBoundary: 2300,
        candleClose: 2300,
        maximumWaitingCandles: 3,
      );

      expect(result.decision, HistoricalPendingSignalDecision.waiting);
      expect(result.state.waitingCandles, 1);
      expect(result.validity.canStillTrigger, isTrue);
    });

    test('BUY invalidates only when close is below structural boundary', () {
      final result = controller.observeClosedM5Candle(
        state: _readyState(SignalCandidateDirection.buy),
        structuralBoundary: 2300,
        candleClose: 2299.99,
        maximumWaitingCandles: 3,
      );

      expect(result.decision, HistoricalPendingSignalDecision.invalidated);
      expect(
        result.validity.reason,
        PendingSignalValidityReason.buyStructureInvalidated,
      );
    });

    test('SELL invalidates only when close is above structural boundary', () {
      final result = controller.observeClosedM5Candle(
        state: _readyState(SignalCandidateDirection.sell),
        structuralBoundary: 2300,
        candleClose: 2300.01,
        maximumWaitingCandles: 3,
      );

      expect(result.decision, HistoricalPendingSignalDecision.invalidated);
      expect(
        result.validity.reason,
        PendingSignalValidityReason.sellStructureInvalidated,
      );
    });

    test('expires when explicit waiting budget is reached', () {
      final result = controller.observeClosedM5Candle(
        state: _readyState(SignalCandidateDirection.buy, waitingCandles: 1),
        structuralBoundary: 2300,
        candleClose: 2301,
        maximumWaitingCandles: 2,
      );

      expect(result.state.waitingCandles, 2);
      expect(result.decision, HistoricalPendingSignalDecision.expired);
      expect(
        result.validity.reason,
        PendingSignalValidityReason.maximumWaitingCandlesReached,
      );
    });

    test('structure invalidation has priority over expiry on same candle', () {
      final result = controller.observeClosedM5Candle(
        state: _readyState(SignalCandidateDirection.buy, waitingCandles: 1),
        structuralBoundary: 2300,
        candleClose: 2299,
        maximumWaitingCandles: 2,
      );

      expect(result.state.waitingCandles, 2);
      expect(result.decision, HistoricalPendingSignalDecision.invalidated);
      expect(
        result.validity.reason,
        PendingSignalValidityReason.buyStructureInvalidated,
      );
    });

    test('maximum waiting candles remains explicit and validated upstream', () {
      expect(
        () => controller.observeClosedM5Candle(
          state: _readyState(SignalCandidateDirection.buy),
          structuralBoundary: 2300,
          candleClose: 2301,
          maximumWaitingCandles: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}

HistoricalReadySignalState _readyState(
  SignalCandidateDirection direction, {
  int waitingCandles = 0,
}) {
  return HistoricalReadySignalState(
    candidate: _qualifiedCandidate(direction),
    readyAtObservationIndex: 10,
    waitingCandles: waitingCandles,
    lifecycleState: SignalLifecycleState.ready,
  );
}

SignalCandidate _qualifiedCandidate(SignalCandidateDirection direction) {
  final fixture = _fixture();
  return SignalCandidate.qualified(
    direction: direction,
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
