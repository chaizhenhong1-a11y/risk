import 'package:risk_engine/risk_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';

import '../data/mt5_history_adapter.dart';
import '../data/multi_timeframe_backtest_feed.dart';
import 'historical_strategy_replay.dart';
import 'strategy_setup_historical_replay.dart';

typedef HistoricalEntryPriceResolver =
    double Function(
      MultiTimeframeBacktestObservation observation,
      StrategySetupAnalysis strategyAnalysis,
    );

/// Explicit Phase 7 research inputs for historical risk planning.
///
/// There are deliberately no defaults for ATR timeframe/period, ATR stop
/// multiplier, minimum RR, or entry-price policy.
final class RiskReplayResearchParameters {
  const RiskReplayResearchParameters({
    required this.atrTimeframe,
    required this.atrPeriod,
    required this.atrMultiplier,
    required this.minimumRiskRewardPolicy,
    required this.entryPriceResolver,
  });

  final MarketTimeframe atrTimeframe;
  final int atrPeriod;
  final AtrStopBufferMultiplier atrMultiplier;
  final MinimumRiskRewardPolicy minimumRiskRewardPolicy;
  final HistoricalEntryPriceResolver entryPriceResolver;
}

enum RiskReplayDecision {
  strategySkipped,
  strategyBlocked,
  insufficientAtrHistory,
  analyzed,
}

final class HistoricalRiskPlanResult {
  const HistoricalRiskPlanResult._({
    required this.decision,
    required this.strategyResult,
    this.atr,
    this.entryPrice,
    this.riskPlan,
  });

  const HistoricalRiskPlanResult.strategySkipped({
    required StrategySetupReplayResult strategyResult,
  }) : this._(
         decision: RiskReplayDecision.strategySkipped,
         strategyResult: strategyResult,
       );

  const HistoricalRiskPlanResult.strategyBlocked({
    required StrategySetupReplayResult strategyResult,
  }) : this._(
         decision: RiskReplayDecision.strategyBlocked,
         strategyResult: strategyResult,
       );

  const HistoricalRiskPlanResult.insufficientAtrHistory({
    required StrategySetupReplayResult strategyResult,
  }) : this._(
         decision: RiskReplayDecision.insufficientAtrHistory,
         strategyResult: strategyResult,
       );

  const HistoricalRiskPlanResult.analyzed({
    required StrategySetupReplayResult strategyResult,
    required double atr,
    required double entryPrice,
    required RiskPlanAnalysis riskPlan,
  }) : this._(
         decision: RiskReplayDecision.analyzed,
         strategyResult: strategyResult,
         atr: atr,
         entryPrice: entryPrice,
         riskPlan: riskPlan,
       );

  final RiskReplayDecision decision;
  final StrategySetupReplayResult strategyResult;
  final double? atr;
  final double? entryPrice;
  final RiskPlanAnalysis? riskPlan;

  bool get wasRiskAnalyzed => decision == RiskReplayDecision.analyzed;
}

/// Extends the historical Strategy replay into the frozen Phase 5 Risk Engine.
///
/// Ordering is intentional:
/// 1. replay the historical strategy setup;
/// 2. stop immediately for skipped/blocked setups;
/// 3. calculate ATR only from history visible at this M5 close;
/// 4. resolve an explicit research entry price;
/// 5. invoke RiskPlanOrchestrator with the exact historical key levels that the
///    Strategy Engine saw.
///
/// This increment creates historical trade plans only. It does not trigger
/// signals, simulate fills, decide TP/SL outcomes, or calculate performance.
final class RiskPlanHistoricalReplay {
  const RiskPlanHistoricalReplay({
    this.averageTrueRange = const AverageTrueRange(),
    this.riskPlanOrchestrator = const RiskPlanOrchestrator(),
  });

  final AverageTrueRange averageTrueRange;
  final RiskPlanOrchestrator riskPlanOrchestrator;

  HistoricalStrategyReplay<HistoricalRiskPlanResult> create({
    required MultiTimeframeBacktestFeed feed,
    required StrategySetupHistoricalReplay strategyReplay,
    required StrategyReplayResearchParameters strategyParameters,
    required RiskReplayResearchParameters riskParameters,
  }) {
    _validateRiskParameters(riskParameters);

    final strategyEvaluator = strategyReplay
        .create(feed: feed, parameters: strategyParameters)
        .evaluator;

    return HistoricalStrategyReplay<HistoricalRiskPlanResult>(
      feed: feed,
      evaluator: (observation) {
        final strategyResult = strategyEvaluator(observation);
        return _evaluate(
          observation: observation,
          strategyResult: strategyResult,
          parameters: riskParameters,
        );
      },
    );
  }

  HistoricalRiskPlanResult _evaluate({
    required MultiTimeframeBacktestObservation observation,
    required StrategySetupReplayResult strategyResult,
    required RiskReplayResearchParameters parameters,
  }) {
    if (!strategyResult.wasAnalyzed) {
      return HistoricalRiskPlanResult.strategySkipped(
        strategyResult: strategyResult,
      );
    }

    final strategyAnalysis = strategyResult.analysis!;
    if (!strategyAnalysis.snapshot.isEligible) {
      return HistoricalRiskPlanResult.strategyBlocked(
        strategyResult: strategyResult,
      );
    }

    final atrHistory = observation.historyFor(parameters.atrTimeframe);
    if (atrHistory.length < parameters.atrPeriod + 1) {
      return HistoricalRiskPlanResult.insufficientAtrHistory(
        strategyResult: strategyResult,
      );
    }

    final atr = averageTrueRange.calculate(
      candles: atrHistory,
      period: parameters.atrPeriod,
    );

    final entryPrice = parameters.entryPriceResolver(
      observation,
      strategyAnalysis,
    );
    if (!entryPrice.isFinite) {
      throw ArgumentError.value(
        entryPrice,
        'entryPrice',
        'Historical entry price must be finite.',
      );
    }

    final levelLiquidity = strategyResult.levelLiquidityAnalysis!;
    final riskPlan = riskPlanOrchestrator.analyze(
      bias: strategyAnalysis.bias.bias,
      setupSnapshot: strategyAnalysis.snapshot,
      pullback: strategyAnalysis.pullback,
      entryPrice: entryPrice,
      atr: atr,
      atrMultiplier: parameters.atrMultiplier,
      keyLevels: levelLiquidity.keyLevels,
      minimumRiskRewardPolicy: parameters.minimumRiskRewardPolicy,
    );

    return HistoricalRiskPlanResult.analyzed(
      strategyResult: strategyResult,
      atr: atr,
      entryPrice: entryPrice,
      riskPlan: riskPlan,
    );
  }

  void _validateRiskParameters(RiskReplayResearchParameters parameters) {
    if (parameters.atrPeriod <= 0) {
      throw ArgumentError.value(
        parameters.atrPeriod,
        'atrPeriod',
        'ATR period must be greater than zero.',
      );
    }
  }
}
