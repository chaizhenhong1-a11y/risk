import 'package:risk_engine/risk_engine.dart';
import 'package:signal_engine/signal_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const orchestrator = SignalEngineOrchestrator();

  group('SignalEngineOrchestrator Phase 6 integration', () {
    test('qualified valid signal waits before Entry Zone contact', () {
      final fixture = _fixture();
      final result = orchestrator.evaluatePending(
        bias: TradingBias.buy,
        setupSnapshot: fixture.snapshot,
        setupScore: fixture.score,
        riskPlan: fixture.riskPlan,
        structuralBoundary: 2298,
        candleClose: 2305,
        candleLow: 2303,
        candleHigh: 2306,
        waitingCandles: 1,
        maximumWaitingCandles: 5,
      );

      expect(result.decision, PendingSignalDecision.waiting);
      expect(result.candidate.isQualified, isTrue);
      expect(result.validity!.canStillTrigger, isTrue);
      expect(result.trigger!.isTriggered, isFalse);
    });

    test('qualified valid signal triggers on Entry Zone contact', () {
      final fixture = _fixture();
      final result = orchestrator.evaluatePending(
        bias: TradingBias.buy,
        setupSnapshot: fixture.snapshot,
        setupScore: fixture.score,
        riskPlan: fixture.riskPlan,
        structuralBoundary: 2298,
        candleClose: 2301,
        candleLow: 2300,
        candleHigh: 2303,
        waitingCandles: 2,
        maximumWaitingCandles: 5,
      );

      expect(result.decision, PendingSignalDecision.triggered);
      expect(result.trigger!.isTriggered, isTrue);
    });

    test('structural invalidation prevents same-candle trigger', () {
      final fixture = _fixture();
      final result = orchestrator.evaluatePending(
        bias: TradingBias.buy,
        setupSnapshot: fixture.snapshot,
        setupScore: fixture.score,
        riskPlan: fixture.riskPlan,
        structuralBoundary: 2301,
        candleClose: 2300,
        candleLow: 2299,
        candleHigh: 2302,
        waitingCandles: 2,
        maximumWaitingCandles: 5,
      );

      expect(result.decision, PendingSignalDecision.invalidated);
      expect(result.trigger, isNull);
    });

    test('expiry prevents trigger evaluation', () {
      final fixture = _fixture();
      final result = orchestrator.evaluatePending(
        bias: TradingBias.buy,
        setupSnapshot: fixture.snapshot,
        setupScore: fixture.score,
        riskPlan: fixture.riskPlan,
        structuralBoundary: 2298,
        candleClose: 2301,
        candleLow: 2300,
        candleHigh: 2302,
        waitingCandles: 5,
        maximumWaitingCandles: 5,
      );

      expect(result.decision, PendingSignalDecision.expired);
      expect(result.trigger, isNull);
    });

    test('triggered monitoring reaches TP without user-position state', () {
      final result = orchestrator.monitorTriggered(
        bias: TradingBias.buy,
        stopPrice: 2297,
        targetPrice: 2310,
        candleLow: 2302,
        candleHigh: 2310,
      );

      expect(result.outcome, TriggeredSignalOutcome.takeProfitReached);
      expect(result.isTerminal, isTrue);
    });
  });
}

_TestFixture _fixture() {
  final snapshot = SetupEvidenceSnapshot(
    eligibility: SetupEligibility.eligible,
    blockReason: null,
    evidence: const [],
    d1ContextAlignment: D1ContextAlignment.unavailable,
    keyLevelQuality: KeyLevelQuality.unavailable,
  );

  final support = KeyLevel(
    type: KeyLevelType.support,
    source: KeyLevelSource.swingLow,
    status: KeyLevelStatus.active,
    lowerBound: 2300,
    upperBound: 2302,
    createdAtCandleIndex: 10,
  );
  final resistance = KeyLevel(
    type: KeyLevelType.resistance,
    source: KeyLevelSource.swingHigh,
    status: KeyLevelStatus.active,
    lowerBound: 2310,
    upperBound: 2312,
    createdAtCandleIndex: 20,
  );

  final pullback = PullbackAnalysis(
    state: PullbackState.inZone,
    reason: PullbackReason.priceAtSupport,
    matchedLevel: support,
  );

  final riskPlan = const RiskPlanOrchestrator().analyze(
    bias: TradingBias.buy,
    setupSnapshot: snapshot,
    pullback: pullback,
    entryPrice: 2301,
    atr: 2,
    atrMultiplier: AtrStopBufferMultiplier(1),
    keyLevels: [support, resistance],
    minimumRiskRewardPolicy: MinimumRiskRewardPolicy(1),
  );

  return _TestFixture(
    snapshot: snapshot,
    score: SetupScoreResult(
      earnedPoints: 60,
      availablePoints: 100,
      contributions: const {},
    ),
    riskPlan: riskPlan,
  );
}

final class _TestFixture {
  const _TestFixture({
    required this.snapshot,
    required this.score,
    required this.riskPlan,
  });

  final SetupEvidenceSnapshot snapshot;
  final SetupScoreResult score;
  final RiskPlanAnalysis riskPlan;
}
