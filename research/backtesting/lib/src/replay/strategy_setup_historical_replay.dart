import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';

import '../data/mt5_history_adapter.dart';
import '../data/multi_timeframe_backtest_feed.dart';
import 'historical_strategy_replay.dart';
import 'incremental_market_structure_cache.dart';

/// Explicit research inputs needed to reconstruct Phase 2/3 facts historically.
///
/// These are deliberately required. Phase 7 must not smuggle unvalidated XAUUSD
/// tolerances or zone widths into the backtest as hidden defaults.
final class StrategyReplayResearchParameters {
  const StrategyReplayResearchParameters({
    required this.equalityTolerance,
    required this.zoneHalfWidth,
    required this.levelMergeMaxGap,
    required this.scoreProfile,
  });

  final double equalityTolerance;
  final double zoneHalfWidth;
  final double levelMergeMaxGap;
  final SetupScoreProfile scoreProfile;
}

enum StrategyReplayDecision { skipped, analyzed }

enum StrategyReplaySkipReason { noClosedM15Candle }

/// Result of running the frozen Phase 4 strategy pipeline at one historical
/// M5 close.
///
/// A step is skipped only when no M15 candle has closed yet. H4/H1 can still
/// legitimately classify as UNKNOWN while their histories warm up.
final class StrategySetupReplayResult {
  const StrategySetupReplayResult._({
    required this.decision,
    this.skipReason,
    this.analysis,
    this.levelLiquidityAnalysis,
    this.m15Structure,
  });

  const StrategySetupReplayResult.skipped(StrategyReplaySkipReason reason)
    : this._(decision: StrategyReplayDecision.skipped, skipReason: reason);

  const StrategySetupReplayResult.analyzed({
    required StrategySetupAnalysis analysis,
    required LevelLiquidityAnalysis levelLiquidityAnalysis,
    required MarketStructure m15Structure,
  }) : this._(
         decision: StrategyReplayDecision.analyzed,
         analysis: analysis,
         levelLiquidityAnalysis: levelLiquidityAnalysis,
         m15Structure: m15Structure,
       );

  final StrategyReplayDecision decision;
  final StrategyReplaySkipReason? skipReason;
  final StrategySetupAnalysis? analysis;
  final LevelLiquidityAnalysis? levelLiquidityAnalysis;
  final MarketStructure? m15Structure;

  bool get wasAnalyzed => decision == StrategyReplayDecision.analyzed;
}

/// Connects the anti-look-ahead historical feed to the already-frozen
/// technical-analysis and Phase 4 Strategy Engine.
///
/// At each M5 close:
/// 1. reconstruct H4/H1/M15 market structure from visible CLOSED history;
/// 2. reconstruct M15 levels/liquidity from confirmed M15 swings only;
/// 3. invoke StrategySetupOrchestrator with those historical facts.
///
/// D1 remains unavailable in this increment because the imported V1 dataset
/// currently contains M5/M15/H1/H4 only. Level strength also remains
/// unavailable rather than being fabricated.
final class StrategySetupHistoricalReplay {
  const StrategySetupHistoricalReplay({
    this.marketStructureAnalyzer = const MarketStructureAnalyzer(),
    this.levelLiquidityAnalyzer = const LevelLiquidityAnalyzer(),
    this.strategySetupOrchestrator = const StrategySetupOrchestrator(),
  });

  final MarketStructureAnalyzer marketStructureAnalyzer;
  final LevelLiquidityAnalyzer levelLiquidityAnalyzer;
  final StrategySetupOrchestrator strategySetupOrchestrator;

  HistoricalStrategyReplay<StrategySetupReplayResult> create({
    required MultiTimeframeBacktestFeed feed,
    required StrategyReplayResearchParameters parameters,
  }) {
    _validateParameters(parameters);

    final cache = _StrategyReplayAnalysisCache();

    return HistoricalStrategyReplay<StrategySetupReplayResult>(
      feed: feed,
      evaluator: (observation) => _evaluate(
        observation: observation,
        parameters: parameters,
        cache: cache,
      ),
    );
  }

  StrategySetupReplayResult _evaluate({
    required MultiTimeframeBacktestObservation observation,
    required StrategyReplayResearchParameters parameters,
    required _StrategyReplayAnalysisCache cache,
  }) {
    final m15History = observation.historyFor(MarketTimeframe.m15);
    if (m15History.isEmpty) {
      return const StrategySetupReplayResult.skipped(
        StrategyReplaySkipReason.noClosedM15Candle,
      );
    }

    final h4History = observation.historyFor(MarketTimeframe.h4);
    final h1History = observation.historyFor(MarketTimeframe.h1);

    if (cache.h4HistoryLength != h4History.length) {
      cache
        ..h4HistoryLength = h4History.length
        ..h4Analysis = cache.h4StructureCache.update(
          h4History,
          equalityTolerance: parameters.equalityTolerance,
        );
    }

    if (cache.h1HistoryLength != h1History.length) {
      cache
        ..h1HistoryLength = h1History.length
        ..h1Analysis = cache.h1StructureCache.update(
          h1History,
          equalityTolerance: parameters.equalityTolerance,
        );
    }

    if (cache.m15HistoryLength != m15History.length) {
      final m15Analysis = cache.m15StructureCache.update(
        m15History,
        equalityTolerance: parameters.equalityTolerance,
      );
      final closedM15Candle = m15History.last;
      final levelLiquidity = levelLiquidityAnalyzer.analyze(
        confirmedSwings: m15Analysis.swings,
        closedCandle: closedM15Candle,
        zoneHalfWidth: parameters.zoneHalfWidth,
        levelMergeMaxGap: parameters.levelMergeMaxGap,
        equalityTolerance: parameters.equalityTolerance,
      );

      cache
        ..m15HistoryLength = m15History.length
        ..m15Analysis = m15Analysis
        ..levelLiquidityAnalysis = levelLiquidity;
    }

    final h4 = cache.h4Analysis!;
    final h1 = cache.h1Analysis!;
    final m15 = cache.m15Analysis!;
    final levelLiquidity = cache.levelLiquidityAnalysis!;
    final closedM15Candle = m15History.last;

    final analysis = strategySetupOrchestrator.analyze(
      h4Structure: h4.structure,
      h1Structure: h1.structure,
      m15Structure: m15.structure,
      closedM15Candle: closedM15Candle,
      closedM5Candle: observation.currentM5Candle,
      keyLevels: levelLiquidity.keyLevels,
      scoreProfile: parameters.scoreProfile,
      levelLiquidityAnalysis: levelLiquidity,
    );

    return StrategySetupReplayResult.analyzed(
      analysis: analysis,
      levelLiquidityAnalysis: levelLiquidity,
      m15Structure: m15.structure,
    );
  }

  void _validateParameters(StrategyReplayResearchParameters parameters) {
    _validateNonNegativeFinite(
      parameters.equalityTolerance,
      'equalityTolerance',
    );
    _validateNonNegativeFinite(parameters.zoneHalfWidth, 'zoneHalfWidth');
    _validateNonNegativeFinite(parameters.levelMergeMaxGap, 'levelMergeMaxGap');
  }

  void _validateNonNegativeFinite(double value, String name) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(value, name, 'must be finite and non-negative');
    }
  }
}

final class _StrategyReplayAnalysisCache {
  final h4StructureCache = IncrementalMarketStructureCache();
  final h1StructureCache = IncrementalMarketStructureCache();
  final m15StructureCache = IncrementalMarketStructureCache();

  int h4HistoryLength = -1;
  int h1HistoryLength = -1;
  int m15HistoryLength = -1;

  MarketStructureAnalysis? h4Analysis;
  MarketStructureAnalysis? h1Analysis;
  MarketStructureAnalysis? m15Analysis;
  LevelLiquidityAnalysis? levelLiquidityAnalysis;
}
