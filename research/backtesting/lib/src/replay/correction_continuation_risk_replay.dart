import 'package:risk_engine/risk_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';

import '../data/mt5_history_adapter.dart';
import '../data/multi_timeframe_backtest_feed.dart';
import 'correction_continuation_historical_replay.dart';
import 'historical_strategy_replay.dart';
import 'strategy_setup_historical_replay.dart';

final class CorrectionContinuationRiskResearchParameters {
  const CorrectionContinuationRiskResearchParameters({
    required this.atrTimeframe,
    required this.atrPeriod,
    required this.atrMultiplier,
    required this.minimumRiskRewardPolicy,
  });

  final MarketTimeframe atrTimeframe;
  final int atrPeriod;
  final AtrStopBufferMultiplier atrMultiplier;
  final MinimumRiskRewardPolicy minimumRiskRewardPolicy;
}

final class CorrectionContinuationRiskReplayResult {
  const CorrectionContinuationRiskReplayResult({
    required this.candidateResult,
    this.atr,
    this.riskPlan,
  });

  final CorrectionContinuationReplayResult? candidateResult;
  final double? atr;
  final RiskPlanAnalysis? riskPlan;

  bool get isCandidate => candidateResult?.isCandidate ?? false;
  bool get wasRiskPlanned => riskPlan != null;
  bool get isRiskEligible => riskPlan?.isEligible ?? false;
}

/// Independent Strategy B risk replay.
///
/// Candidate generation stays frozen in Strategy B. This layer adds the
/// explicit Increment-088 research policy: after M15 realignment, select the
/// nearest active directional M15 level behind current price as a future Entry
/// Zone, then reuse the frozen Phase-5 ATR stop / structure target / RR gate.
final class CorrectionContinuationRiskHistoricalReplay {
  const CorrectionContinuationRiskHistoricalReplay({
    this.averageTrueRange = const AverageTrueRange(),
    this.riskPlanner = const DirectionalLevelRiskPlanOrchestrator(),
  });

  final AverageTrueRange averageTrueRange;
  final DirectionalLevelRiskPlanOrchestrator riskPlanner;

  HistoricalStrategyReplay<CorrectionContinuationRiskReplayResult> create({
    required MultiTimeframeBacktestFeed feed,
    required CorrectionContinuationHistoricalReplay candidateReplay,
    required StrategySetupHistoricalReplay sourceReplay,
    required StrategyReplayResearchParameters sourceParameters,
    required CorrectionContinuationRiskResearchParameters riskParameters,
  }) {
    if (riskParameters.atrPeriod <= 0) {
      throw ArgumentError.value(
        riskParameters.atrPeriod,
        'atrPeriod',
        'ATR period must be greater than zero.',
      );
    }

    final candidateEvaluator = candidateReplay
        .create(
          feed: feed,
          sourceReplay: sourceReplay,
          sourceParameters: sourceParameters,
        )
        .evaluator;

    var cachedAtrHistoryLength = -1;
    double? cachedAtr;

    // Strategy B candidate inputs are H4/H1/M15 facts only. M5-only closes
    // cannot change the correction regime or create a fresh M15 realignment.
    // Avoid replaying the full source analysis on those redundant observations.
    // We still evaluate every observation where any relevant higher timeframe
    // history advances, preserving the exact no-look-ahead candidate semantics.
    var lastH4HistoryLength = -1;
    var lastH1HistoryLength = -1;
    var lastM15HistoryLength = -1;

    return HistoricalStrategyReplay<CorrectionContinuationRiskReplayResult>(
      feed: feed,
      evaluator: (observation) {
        final h4Length = observation.historyFor(MarketTimeframe.h4).length;
        final h1Length = observation.historyFor(MarketTimeframe.h1).length;
        final m15Length = observation.historyFor(MarketTimeframe.m15).length;
        final higherTimeframeAdvanced =
            h4Length != lastH4HistoryLength ||
            h1Length != lastH1HistoryLength ||
            m15Length != lastM15HistoryLength;

        if (!higherTimeframeAdvanced) {
          return const CorrectionContinuationRiskReplayResult(
            candidateResult: null,
          );
        }

        lastH4HistoryLength = h4Length;
        lastH1HistoryLength = h1Length;
        lastM15HistoryLength = m15Length;

        final candidate = candidateEvaluator(observation);
        if (candidate == null || !candidate.isCandidate) {
          return CorrectionContinuationRiskReplayResult(
            candidateResult: candidate,
          );
        }

        final atrHistory = observation.historyFor(riskParameters.atrTimeframe);
        if (atrHistory.length < riskParameters.atrPeriod + 1) {
          return CorrectionContinuationRiskReplayResult(
            candidateResult: candidate,
          );
        }

        if (cachedAtrHistoryLength != atrHistory.length) {
          cachedAtrHistoryLength = atrHistory.length;
          cachedAtr = averageTrueRange.calculate(
            candles: atrHistory.sublist(
              atrHistory.length - riskParameters.atrPeriod - 1,
            ),
            period: riskParameters.atrPeriod,
          );
        }

        final bias = candidate.analysis.bias;
        final riskPlan = riskPlanner.analyze(
          bias: bias,
          referencePrice: observation.currentM5Candle.close,
          atr: cachedAtr!,
          atrMultiplier: riskParameters.atrMultiplier,
          keyLevels: candidate.levelLiquidityAnalysis.keyLevels,
          minimumRiskRewardPolicy: riskParameters.minimumRiskRewardPolicy,
        );

        return CorrectionContinuationRiskReplayResult(
          candidateResult: candidate,
          atr: cachedAtr,
          riskPlan: riskPlan,
        );
      },
    );
  }
}
