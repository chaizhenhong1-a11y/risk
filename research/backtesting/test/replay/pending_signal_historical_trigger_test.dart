import 'package:risk_engine/risk_engine.dart';
import 'package:signal_engine/signal_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  const controller = HistoricalPendingSignalTriggerController();

  group('HistoricalPendingSignalTriggerController', () {
    test('valid BUY signal triggers when candle reaches Entry Zone', () {
      final result = controller.observeClosedM5Candle(
        state: _readyState(SignalCandidateDirection.buy),
        structuralBoundary: 2290,
        candleClose: 2301,
        candleLow: 2299.5,
        candleHigh: 2302,
        maximumWaitingCandles: 3,
      );

      expect(result.decision, HistoricalPendingTriggerDecision.triggered);
      expect(result.state.waitingCandles, 1);
      expect(result.validity.canStillTrigger, isTrue);
      expect(result.trigger, isNotNull);
      expect(result.trigger!.isTriggered, isTrue);
      expect(
        result.trigger!.reason,
        EntryZoneTriggerReason.candleReachedEntryZone,
      );
    });

    test('inclusive Entry Zone boundary contact counts as trigger', () {
      final result = controller.observeClosedM5Candle(
        state: _readyState(SignalCandidateDirection.buy),
        structuralBoundary: 2290,
        candleClose: 2302,
        candleLow: 2301,
        candleHigh: 2303,
        maximumWaitingCandles: 3,
      );

      expect(result.decision, HistoricalPendingTriggerDecision.triggered);
    });

    test('valid signal keeps waiting when candle misses Entry Zone', () {
      final result = controller.observeClosedM5Candle(
        state: _readyState(SignalCandidateDirection.buy),
        structuralBoundary: 2290,
        candleClose: 2305,
        candleLow: 2304,
        candleHigh: 2306,
        maximumWaitingCandles: 3,
      );

      expect(result.decision, HistoricalPendingTriggerDecision.waiting);
      expect(result.trigger, isNotNull);
      expect(result.trigger!.isTriggered, isFalse);
    });

    test('invalidated signal cannot trigger on the same candle', () {
      final result = controller.observeClosedM5Candle(
        state: _readyState(SignalCandidateDirection.buy),
        structuralBoundary: 2300.5,
        candleClose: 2299,
        candleLow: 2298,
        candleHigh: 2302,
        maximumWaitingCandles: 3,
      );

      expect(result.decision, HistoricalPendingTriggerDecision.invalidated);
      expect(result.trigger, isNull);
      expect(
        result.validity.reason,
        PendingSignalValidityReason.buyStructureInvalidated,
      );
    });

    test('expired signal cannot trigger on the same candle', () {
      final result = controller.observeClosedM5Candle(
        state: _readyState(SignalCandidateDirection.buy, waitingCandles: 1),
        structuralBoundary: 2290,
        candleClose: 2301,
        candleLow: 2299,
        candleHigh: 2302,
        maximumWaitingCandles: 2,
      );

      expect(result.state.waitingCandles, 2);
      expect(result.decision, HistoricalPendingTriggerDecision.expired);
      expect(result.trigger, isNull);
    });

    test('SELL signal uses the same deterministic Entry Zone contact rule', () {
      final result = controller.observeClosedM5Candle(
        state: _readyState(SignalCandidateDirection.sell),
        structuralBoundary: 2310,
        candleClose: 2300,
        candleLow: 2298,
        candleHigh: 2300,
        maximumWaitingCandles: 3,
      );

      expect(result.decision, HistoricalPendingTriggerDecision.triggered);
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

  final sourceLevel = KeyLevel(
    type: KeyLevelType.support,
    source: KeyLevelSource.swingLow,
    status: KeyLevelStatus.active,
    lowerBound: 2299,
    upperBound: 2301,
    createdAtCandleIndex: 1,
  );

  final riskPlan = RiskPlanAnalysis(
    entryZoneAnalysis: EntryZoneAnalysis.available(
      EntryZone(lowerBound: 2299, upperBound: 2301, sourceLevel: sourceLevel),
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
