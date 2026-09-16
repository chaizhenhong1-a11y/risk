import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';

import '../data/multi_timeframe_backtest_feed.dart';
import 'historical_strategy_replay.dart';
import 'strategy_setup_historical_replay.dart';

/// One no-look-ahead Strategy B v1 candidate-replay observation.
///
/// This is intentionally pre-risk. Increment 087 establishes an independent
/// Strategy B candidate stream before Entry/SL/TP/RR are adapted for the new
/// strategy family.
final class CorrectionContinuationReplayResult {
  const CorrectionContinuationReplayResult({
    required this.regimeAnalysis,
    required this.analysis,
    required this.levelLiquidityAnalysis,
  });

  final MarketRegimeAnalysis regimeAnalysis;
  final CorrectionContinuationAnalysis analysis;
  final LevelLiquidityAnalysis levelLiquidityAnalysis;

  bool get isCandidate => analysis.isEligible;
}

/// Independent historical candidate replay for Strategy B.
///
/// It reuses the frozen Strategy-A historical reconstruction only as a source
/// of already-computed H4/H1/M15 structure and M15 Level/Liquidity facts. It
/// does NOT use Strategy A eligibility, score, pullback, risk plan or lifecycle.
final class CorrectionContinuationHistoricalReplay {
  const CorrectionContinuationHistoricalReplay({
    this.regimeClassifier = const MarketRegimeClassifier(),
    this.analyzer = const CorrectionContinuationAnalyzer(),
  });

  final MarketRegimeClassifier regimeClassifier;
  final CorrectionContinuationAnalyzer analyzer;

  HistoricalStrategyReplay<CorrectionContinuationReplayResult?> create({
    required MultiTimeframeBacktestFeed feed,
    required StrategySetupHistoricalReplay sourceReplay,
    required StrategyReplayResearchParameters sourceParameters,
  }) {
    final sourceEvaluator = sourceReplay
        .create(feed: feed, parameters: sourceParameters)
        .evaluator;

    MarketRegime? previousRegime;
    MarketStructure previousM15Structure = MarketStructure.unknown;

    return HistoricalStrategyReplay<CorrectionContinuationReplayResult?>(
      feed: feed,
      evaluator: (observation) {
        final source = sourceEvaluator(observation);
        if (!source.wasAnalyzed) return null;

        final strategyAAnalysis = source.analysis!;
        final m15Structure = source.m15Structure!;
        final regime = regimeClassifier.classify(
          h4Structure: strategyAAnalysis.bias.h4Structure,
          h1Structure: strategyAAnalysis.bias.h1Structure,
        );
        final directionalSweep = _hasDirectionalSweep(
          source.levelLiquidityAnalysis!,
          regime.direction,
        );

        final analysis = analyzer.analyze(
          regimeAnalysis: regime,
          previousRegime: previousRegime,
          previousM15Structure: previousM15Structure,
          currentM15Structure: m15Structure,
          directionalSweepEvidencePresent: directionalSweep,
        );

        previousRegime = regime.regime;
        previousM15Structure = m15Structure;

        return CorrectionContinuationReplayResult(
          regimeAnalysis: regime,
          analysis: analysis,
          levelLiquidityAnalysis: source.levelLiquidityAnalysis!,
        );
      },
    );
  }

  bool _hasDirectionalSweep(
    LevelLiquidityAnalysis analysis,
    MarketRegimeDirection direction,
  ) {
    final levelSweep = analysis.levelSweeps.any(
      (sweep) => switch (direction) {
        MarketRegimeDirection.bullish =>
          sweep.direction == LiquiditySweepDirection.belowSupport,
        MarketRegimeDirection.bearish =>
          sweep.direction == LiquiditySweepDirection.aboveResistance,
        MarketRegimeDirection.none => false,
      },
    );
    final poolSweep = analysis.poolSweeps.any(
      (sweep) => switch (direction) {
        MarketRegimeDirection.bullish =>
          sweep.direction == LiquidityPoolSweepDirection.belowEqualLows,
        MarketRegimeDirection.bearish =>
          sweep.direction == LiquidityPoolSweepDirection.aboveEqualHighs,
        MarketRegimeDirection.none => false,
      },
    );
    return levelSweep || poolSweep;
  }
}
