import 'package:signal_engine/signal_engine.dart';

import '../data/multi_timeframe_backtest_feed.dart';
import 'historical_strategy_replay.dart';
import 'risk_plan_historical_replay.dart';
import 'strategy_setup_historical_replay.dart';

enum SignalCandidateReplayDecision { upstreamUnavailable, built }

/// Historical bridge from the verified Strategy + Risk replay into the frozen
/// Phase 6 SignalCandidateBuilder.
///
/// This increment deliberately stops at candidate construction. READY waiting,
/// expiry/invalidation, Entry Zone triggering, and triggered TP/SL monitoring
/// require state across later M5 observations and are added separately rather
/// than pretending one candle is a complete lifecycle.
final class HistoricalSignalCandidateResult {
  const HistoricalSignalCandidateResult._({
    required this.decision,
    required this.riskResult,
    this.candidate,
  });

  const HistoricalSignalCandidateResult.upstreamUnavailable({
    required HistoricalRiskPlanResult riskResult,
  }) : this._(
         decision: SignalCandidateReplayDecision.upstreamUnavailable,
         riskResult: riskResult,
       );

  const HistoricalSignalCandidateResult.built({
    required HistoricalRiskPlanResult riskResult,
    required SignalCandidate candidate,
  }) : this._(
         decision: SignalCandidateReplayDecision.built,
         riskResult: riskResult,
         candidate: candidate,
       );

  final SignalCandidateReplayDecision decision;
  final HistoricalRiskPlanResult riskResult;
  final SignalCandidate? candidate;

  bool get wasBuilt => decision == SignalCandidateReplayDecision.built;
}

/// Replays the frozen Phase 6 candidate boundary on historical observations.
///
/// No research score threshold is introduced here. Candidate qualification is
/// still decided only by the frozen Signal Engine hard requirements.
final class SignalCandidateHistoricalReplay {
  const SignalCandidateHistoricalReplay({
    this.candidateBuilder = const SignalCandidateBuilder(),
  });

  final SignalCandidateBuilder candidateBuilder;

  HistoricalStrategyReplay<HistoricalSignalCandidateResult> create({
    required MultiTimeframeBacktestFeed feed,
    required RiskPlanHistoricalReplay riskReplay,
    required StrategySetupHistoricalReplay strategyReplay,
    required StrategyReplayResearchParameters strategyParameters,
    required RiskReplayResearchParameters riskParameters,
  }) {
    final riskEvaluator = riskReplay
        .create(
          feed: feed,
          strategyReplay: strategyReplay,
          strategyParameters: strategyParameters,
          riskParameters: riskParameters,
        )
        .evaluator;

    return HistoricalStrategyReplay<HistoricalSignalCandidateResult>(
      feed: feed,
      evaluator: (observation) {
        final riskResult = riskEvaluator(observation);

        if (!riskResult.wasRiskAnalyzed) {
          return HistoricalSignalCandidateResult.upstreamUnavailable(
            riskResult: riskResult,
          );
        }

        final strategyAnalysis = riskResult.strategyResult.analysis!;
        final riskPlan = riskResult.riskPlan!;

        final candidate = candidateBuilder.build(
          bias: strategyAnalysis.bias.bias,
          setupSnapshot: strategyAnalysis.snapshot,
          setupScore: strategyAnalysis.score,
          riskPlan: riskPlan,
        );

        return HistoricalSignalCandidateResult.built(
          riskResult: riskResult,
          candidate: candidate,
        );
      },
    );
  }
}
