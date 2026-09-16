import 'package:risk_engine/risk_engine.dart';
import 'package:signal_engine/signal_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  const builder = HistoricalSignalRecordBuilder();

  group('HistoricalSignalRecordBuilder', () {
    test('READY is not emitted as a terminal record', () {
      expect(
        builder.build(
          state: _state(HistoricalSignalLifecyclePhase.ready),
          terminalAtObservationIndex: 20,
          entryPrice: 2300,
          stopPrice: 2290,
          targetPrice: 2320,
          riskRewardRatio: 2,
        ),
        isNull,
      );
    });

    test('TRIGGERED monitoring state is not emitted as terminal record', () {
      expect(
        builder.build(
          state: _state(
            HistoricalSignalLifecyclePhase.triggered,
            triggeredAtObservationIndex: 15,
          ),
          terminalAtObservationIndex: 20,
          entryPrice: 2300,
          stopPrice: 2290,
          targetPrice: 2320,
          riskRewardRatio: 2,
        ),
        isNull,
      );
    });

    test(
      'pre-trigger INVALIDATED record preserves waiting and score facts',
      () {
        final record = builder.build(
          state: _state(
            HistoricalSignalLifecyclePhase.invalidated,
            waitingCandles: 2,
          ),
          terminalAtObservationIndex: 14,
          entryPrice: 2300,
          stopPrice: 2290,
          targetPrice: 2320,
          riskRewardRatio: 2,
        )!;

        expect(record.outcome, HistoricalSignalRecordOutcome.invalidated);
        expect(record.wasTriggered, isFalse);
        expect(record.readyAtObservationIndex, 10);
        expect(record.terminalAtObservationIndex, 14);
        expect(record.waitingCandles, 2);
        expect(record.setupScoreEarnedPoints, 35);
        expect(record.setupScoreAvailablePoints, 100);
      },
    );

    test('pre-trigger EXPIRED record is retained separately from losses', () {
      final record = builder.build(
        state: _state(
          HistoricalSignalLifecyclePhase.expired,
          waitingCandles: 3,
        ),
        terminalAtObservationIndex: 15,
        entryPrice: 2300,
        stopPrice: 2290,
        targetPrice: 2320,
        riskRewardRatio: 2,
      )!;

      expect(record.outcome, HistoricalSignalRecordOutcome.expired);
      expect(record.wasTriggered, isFalse);
      expect(record.isTakeProfit, isFalse);
      expect(record.isStopLoss, isFalse);
    });

    test('triggered TP record preserves explicit plan values', () {
      final record = builder.build(
        state: _state(
          HistoricalSignalLifecyclePhase.takeProfitReached,
          triggeredAtObservationIndex: 13,
          waitingCandles: 2,
        ),
        terminalAtObservationIndex: 18,
        entryPrice: 2300,
        stopPrice: 2290,
        targetPrice: 2320,
        riskRewardRatio: 2,
      )!;

      expect(record.direction, SignalCandidateDirection.buy);
      expect(record.wasTriggered, isTrue);
      expect(record.triggeredAtObservationIndex, 13);
      expect(record.outcome, HistoricalSignalRecordOutcome.takeProfitReached);
      expect(record.isTakeProfit, isTrue);
      expect(record.entryPrice, 2300);
      expect(record.stopPrice, 2290);
      expect(record.targetPrice, 2320);
      expect(record.riskRewardRatio, 2);
    });

    test('triggered SL record remains distinct from TP', () {
      final record = builder.build(
        state: _state(
          HistoricalSignalLifecyclePhase.stopLossReached,
          triggeredAtObservationIndex: 13,
        ),
        terminalAtObservationIndex: 16,
        entryPrice: 2300,
        stopPrice: 2290,
        targetPrice: 2320,
        riskRewardRatio: 2,
      )!;

      expect(record.outcome, HistoricalSignalRecordOutcome.stopLossReached);
      expect(record.isStopLoss, isTrue);
      expect(record.isTakeProfit, isFalse);
    });

    test('negative terminal observation index is rejected', () {
      expect(
        () => builder.build(
          state: _state(HistoricalSignalLifecyclePhase.expired),
          terminalAtObservationIndex: -1,
          entryPrice: 2300,
          stopPrice: 2290,
          targetPrice: 2320,
          riskRewardRatio: 2,
        ),
        throwsArgumentError,
      );
    });
  });
}

HistoricalSignalLifecycleState _state(
  HistoricalSignalLifecyclePhase phase, {
  int? triggeredAtObservationIndex,
  int waitingCandles = 0,
}) {
  return HistoricalSignalLifecycleState(
    phase: phase,
    readyState: HistoricalReadySignalState(
      candidate: _candidate(),
      readyAtObservationIndex: 10,
      waitingCandles: waitingCandles,
      lifecycleState: SignalLifecycleState.ready,
    ),
    triggeredAtObservationIndex: triggeredAtObservationIndex,
  );
}

SignalCandidate _candidate() {
  final snapshot = SetupEvidenceSnapshot(
    eligibility: SetupEligibility.eligible,
    blockReason: null,
    evidence: const [],
    d1ContextAlignment: D1ContextAlignment.unavailable,
    keyLevelQuality: KeyLevelQuality.unavailable,
  );

  final score = SetupScoreResult(
    earnedPoints: 35,
    availablePoints: 100,
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

  return SignalCandidate.qualified(
    direction: SignalCandidateDirection.buy,
    setupSnapshot: snapshot,
    setupScore: score,
    riskPlan: riskPlan,
  );
}
