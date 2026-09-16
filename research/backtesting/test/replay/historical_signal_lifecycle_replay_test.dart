import 'package:market_models/market_models.dart';
import 'package:risk_engine/risk_engine.dart';
import 'package:signal_engine/signal_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  const replay = HistoricalSignalLifecycleReplay();

  group('HistoricalSignalLifecycleReplay', () {
    test('blocked candidate never starts a historical lifecycle', () {
      expect(
        replay.start(candidate: _blockedCandidate(), observationIndex: 10),
        isNull,
      );
    });

    test('READY can wait, trigger, then reach TP on a later M5 candle', () {
      var state = replay.start(
        candidate: _qualifiedCandidate(),
        observationIndex: 10,
      )!;

      state = replay.observeClosedM5Candle(
        state: state,
        candle: _candle(low: 2304, high: 2306, close: 2305),
        observationIndex: 11,
        structuralBoundary: 2290,
        stopPrice: 2290,
        targetPrice: 2320,
        maximumWaitingCandles: 5,
      );
      expect(state.phase, HistoricalSignalLifecyclePhase.ready);
      expect(state.readyState.waitingCandles, 1);

      state = replay.observeClosedM5Candle(
        state: state,
        candle: _candle(low: 2300, high: 2303, close: 2302),
        observationIndex: 12,
        structuralBoundary: 2290,
        stopPrice: 2290,
        targetPrice: 2320,
        maximumWaitingCandles: 5,
      );
      expect(state.phase, HistoricalSignalLifecyclePhase.triggered);
      expect(state.triggeredAtObservationIndex, 12);
      expect(state.lastTriggeredMonitoring, isNull);

      state = replay.observeClosedM5Candle(
        state: state,
        candle: _candle(low: 2305, high: 2320, close: 2318),
        observationIndex: 13,
        structuralBoundary: 2290,
        stopPrice: 2290,
        targetPrice: 2320,
        maximumWaitingCandles: 5,
      );
      expect(state.phase, HistoricalSignalLifecyclePhase.takeProfitReached);
      expect(state.isTerminal, isTrue);
    });

    test('READY invalidation is terminal and cannot later trigger', () {
      var state = replay.start(
        candidate: _qualifiedCandidate(),
        observationIndex: 10,
      )!;

      state = replay.observeClosedM5Candle(
        state: state,
        candle: _candle(low: 2289, high: 2301, close: 2289),
        observationIndex: 11,
        structuralBoundary: 2290,
        stopPrice: 2290,
        targetPrice: 2320,
        maximumWaitingCandles: 5,
      );
      expect(state.phase, HistoricalSignalLifecyclePhase.invalidated);

      final terminal = replay.observeClosedM5Candle(
        state: state,
        candle: _candle(low: 2299, high: 2302, close: 2301),
        observationIndex: 12,
        structuralBoundary: 2290,
        stopPrice: 2290,
        targetPrice: 2320,
        maximumWaitingCandles: 5,
      );
      expect(terminal, same(state));
    });

    test('READY expiry is terminal', () {
      var state = replay.start(
        candidate: _qualifiedCandidate(),
        observationIndex: 10,
      )!;

      state = replay.observeClosedM5Candle(
        state: state,
        candle: _candle(low: 2304, high: 2306, close: 2305),
        observationIndex: 11,
        structuralBoundary: 2290,
        stopPrice: 2290,
        targetPrice: 2320,
        maximumWaitingCandles: 1,
      );

      expect(state.phase, HistoricalSignalLifecyclePhase.expired);
      expect(state.isTerminal, isTrue);
    });

    test('trigger candle does not guess same-candle TP/SL ordering', () {
      var state = replay.start(
        candidate: _qualifiedCandidate(),
        observationIndex: 10,
      )!;

      state = replay.observeClosedM5Candle(
        state: state,
        candle: _candle(low: 2289, high: 2321, close: 2302),
        observationIndex: 11,
        structuralBoundary: 2280,
        stopPrice: 2290,
        targetPrice: 2320,
        maximumWaitingCandles: 5,
      );

      expect(state.phase, HistoricalSignalLifecyclePhase.triggered);
      expect(state.lastTriggeredMonitoring, isNull);
    });

    test('post-trigger ambiguous candle stays TRIGGERED and non-terminal', () {
      var state = replay.start(
        candidate: _qualifiedCandidate(),
        observationIndex: 10,
      )!;

      state = replay.observeClosedM5Candle(
        state: state,
        candle: _candle(low: 2300, high: 2303, close: 2302),
        observationIndex: 11,
        structuralBoundary: 2290,
        stopPrice: 2290,
        targetPrice: 2320,
        maximumWaitingCandles: 5,
      );
      expect(state.phase, HistoricalSignalLifecyclePhase.triggered);

      state = replay.observeClosedM5Candle(
        state: state,
        candle: _candle(low: 2289, high: 2321, close: 2305),
        observationIndex: 12,
        structuralBoundary: 2290,
        stopPrice: 2290,
        targetPrice: 2320,
        maximumWaitingCandles: 5,
      );

      expect(state.phase, HistoricalSignalLifecyclePhase.triggered);
      expect(state.isTerminal, isFalse);
      expect(
        state.lastTriggeredMonitoring!.monitoring.reason,
        TriggeredSignalMonitoringReason.ambiguousSameCandleOutcome,
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

Candle _candle({
  required double low,
  required double high,
  required double close,
}) {
  return Candle(
    openTime: DateTime.utc(2026, 1, 5, 10),
    closeTime: DateTime.utc(2026, 1, 5, 10, 5),
    open: close,
    high: high,
    low: low,
    close: close,
    volume: 100,
  );
}
