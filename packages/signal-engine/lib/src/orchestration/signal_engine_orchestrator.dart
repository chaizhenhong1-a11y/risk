import 'package:risk_engine/risk_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';

import '../candidate/signal_candidate.dart';
import '../monitoring/pending_signal_validity.dart';
import '../monitoring/triggered_signal_monitor.dart';
import '../trigger/entry_zone_trigger.dart';

enum PendingSignalDecision { blocked, waiting, triggered, invalidated, expired }

/// Unified Phase 6 decision for a signal that has not triggered yet.
///
/// Ordering is intentional:
/// 1. upstream Candidate hard requirements
/// 2. pending structural validity / expiry
/// 3. Entry Zone market contact
///
/// An invalidated or expired signal can never become triggered on the same
/// evaluation.
final class PendingSignalDecisionAnalysis {
  const PendingSignalDecisionAnalysis({
    required this.decision,
    required this.candidate,
    required this.validity,
    this.trigger,
  });

  final PendingSignalDecision decision;
  final SignalCandidate candidate;
  final PendingSignalValidity? validity;
  final EntryZoneTriggerAnalysis? trigger;
}

final class SignalEngineOrchestrator {
  const SignalEngineOrchestrator({
    SignalCandidateBuilder candidateBuilder = const SignalCandidateBuilder(),
    PendingSignalValidityEvaluator validityEvaluator =
        const PendingSignalValidityEvaluator(),
    EntryZoneTriggerDetector triggerDetector = const EntryZoneTriggerDetector(),
    TriggeredSignalMonitor triggeredMonitor = const TriggeredSignalMonitor(),
  }) : _candidateBuilder = candidateBuilder,
       _validityEvaluator = validityEvaluator,
       _triggerDetector = triggerDetector,
       _triggeredMonitor = triggeredMonitor;

  final SignalCandidateBuilder _candidateBuilder;
  final PendingSignalValidityEvaluator _validityEvaluator;
  final EntryZoneTriggerDetector _triggerDetector;
  final TriggeredSignalMonitor _triggeredMonitor;

  PendingSignalDecisionAnalysis evaluatePending({
    required TradingBias bias,
    required SetupEvidenceSnapshot setupSnapshot,
    required SetupScoreResult setupScore,
    required RiskPlanAnalysis riskPlan,
    required double structuralBoundary,
    required double candleClose,
    required double candleLow,
    required double candleHigh,
    required int waitingCandles,
    required int maximumWaitingCandles,
  }) {
    final candidate = _candidateBuilder.build(
      bias: bias,
      setupSnapshot: setupSnapshot,
      setupScore: setupScore,
      riskPlan: riskPlan,
    );

    if (!candidate.isQualified) {
      return PendingSignalDecisionAnalysis(
        decision: PendingSignalDecision.blocked,
        candidate: candidate,
        validity: null,
      );
    }

    final validity = _validityEvaluator.evaluate(
      bias: bias,
      structuralBoundary: structuralBoundary,
      candleClose: candleClose,
      waitingCandles: waitingCandles,
      maximumWaitingCandles: maximumWaitingCandles,
    );

    if (validity.state == PendingSignalValidityState.invalidated) {
      return PendingSignalDecisionAnalysis(
        decision: PendingSignalDecision.invalidated,
        candidate: candidate,
        validity: validity,
      );
    }

    if (validity.state == PendingSignalValidityState.expired) {
      return PendingSignalDecisionAnalysis(
        decision: PendingSignalDecision.expired,
        candidate: candidate,
        validity: validity,
      );
    }

    final trigger = _triggerDetector.detect(
      bias: bias,
      entryZoneAnalysis: riskPlan.entryZoneAnalysis,
      candleLow: candleLow,
      candleHigh: candleHigh,
    );

    return PendingSignalDecisionAnalysis(
      decision: trigger.isTriggered
          ? PendingSignalDecision.triggered
          : PendingSignalDecision.waiting,
      candidate: candidate,
      validity: validity,
      trigger: trigger,
    );
  }

  TriggeredSignalMonitoring monitorTriggered({
    required TradingBias bias,
    required double stopPrice,
    required double targetPrice,
    required double candleLow,
    required double candleHigh,
  }) => _triggeredMonitor.observe(
    bias: bias,
    stopPrice: stopPrice,
    targetPrice: targetPrice,
    candleLow: candleLow,
    candleHigh: candleHigh,
  );
}
