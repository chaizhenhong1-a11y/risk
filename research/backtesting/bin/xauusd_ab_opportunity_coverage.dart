import 'dart:io';

import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

const _files = <MarketTimeframe, String>{
  MarketTimeframe.m5: 'XAUUSD_M5_2024_2026.csv',
  MarketTimeframe.m15: 'XAUUSD_M15_2024_2026.csv',
  MarketTimeframe.h1: 'XAUUSD_H1_2024_2026.csv',
  MarketTimeframe.h4: 'XAUUSD_H4_2024_2026.csv',
};

const _maximumObservations = 100049;
const _progressInterval = 1000;

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_ab_opportunity_coverage.dart '
      '<history-directory>',
    );
    exitCode = 64;
    return;
  }

  final directory = Directory(arguments.first);
  if (!directory.existsSync()) {
    stderr.writeln('History directory not found: ${directory.path}');
    exitCode = 66;
    return;
  }

  const adapter = Mt5HistoryAdapter();
  final loaded = <MarketTimeframe, Mt5HistorySeries>{};

  for (final entry in _files.entries) {
    final file = File(
      '${directory.path}${Platform.pathSeparator}${entry.value}',
    );
    if (!file.existsSync()) {
      stderr.writeln('Missing: ${file.path}');
      exitCode = 66;
      return;
    }
    loaded[entry.key] = adapter.parse(
      content: file.readAsStringSync(),
      timeframe: entry.key,
    );
  }

  final feed = MultiTimeframeBacktestFeed(
    m5Candles: loaded[MarketTimeframe.m5]!.candles,
    m15Candles: loaded[MarketTimeframe.m15]!.candles,
    h1Candles: loaded[MarketTimeframe.h1]!.candles,
    h4Candles: loaded[MarketTimeframe.h4]!.candles,
  );

  final parameters = StrategyReplayResearchParameters(
    equalityTolerance: 0.10,
    zoneHalfWidth: 0.50,
    levelMergeMaxGap: 0.20,
    scoreProfile: SetupScoreProfiles.baselineResearchV1,
  );

  // Performance fix:
  // reconstruct Strategy A's expensive H4/H1/M15 facts exactly once.
  // Strategy B is then evaluated from those already-computed facts instead of
  // creating a second StrategySetupHistoricalReplay.
  final sourceEvaluator = const StrategySetupHistoricalReplay()
      .create(feed: feed, parameters: parameters)
      .evaluator;

  const regimeClassifier = MarketRegimeClassifier();
  const strategyBAnalyzer = CorrectionContinuationAnalyzer();

  MarketRegime? previousRegime;
  MarketStructure previousM15Structure = MarketStructure.unknown;

  final coverage = MultiStrategyOpportunityCoverage();
  final stopwatch = Stopwatch()..start();
  var observations = 0;

  for (final observation in feed.observations()) {
    if (observations >= _maximumObservations) break;
    observations++;

    if (observations % _progressInterval == 0) {
      final elapsedMs = stopwatch.elapsedMilliseconds;
      final rate = elapsedMs == 0 ? 0.0 : observations * 1000.0 / elapsedMs;
      stdout.writeln(
        'Progress: $observations/$_maximumObservations '
        'elapsed=${stopwatch.elapsed} '
        'rate=${rate.toStringAsFixed(1)} obs/s',
      );
    }

    coverage.observeTradingDate(observation.observationTime);

    final source = sourceEvaluator(observation);
    if (!source.wasAnalyzed) {
      coverage.observeStrategyA(
        observedAt: observation.observationTime,
        eligible: false,
        bias: TradingBias.noTrade,
      );
      continue;
    }

    final strategyA = source.analysis!;
    coverage.observeStrategyA(
      observedAt: observation.observationTime,
      eligible: strategyA.evaluation.isEligible,
      bias: strategyA.bias.bias,
    );

    final m15Structure = source.m15Structure!;
    final regime = regimeClassifier.classify(
      h4Structure: strategyA.bias.h4Structure,
      h1Structure: strategyA.bias.h1Structure,
    );

    final directionalSweep = _hasDirectionalSweep(
      source.levelLiquidityAnalysis!,
      regime.direction,
    );

    final strategyB = strategyBAnalyzer.analyze(
      regimeAnalysis: regime,
      previousRegime: previousRegime,
      previousM15Structure: previousM15Structure,
      currentM15Structure: m15Structure,
      directionalSweepEvidencePresent: directionalSweep,
    );

    previousRegime = regime.regime;
    previousM15Structure = m15Structure;

    coverage.observeStrategyB(
      observedAt: observation.observationTime,
      eligible: strategyB.isEligible,
      bias: strategyB.bias,
    );
  }

  stopwatch.stop();
  final r = coverage.finish();

  stdout.writeln('');
  stdout.writeln('TradeForge V2 — Increment 099 A+B Coverage');
  stdout.writeln('Observed M5 closes: $observations');
  stdout.writeln('Observed trading days: ${r.observedTradingDays}');
  stdout.writeln('Strategy A candidate episodes: ${r.strategyACandidates}');
  stdout.writeln('Strategy B candidate events: ${r.strategyBCandidates}');
  stdout.writeln('Same-direction overlaps: ${r.sameDirectionOverlaps}');
  stdout.writeln('Opposite-direction conflicts: ${r.conflicts}');
  stdout.writeln('A+B unique opportunities: ${r.uniqueOpportunities}');
  stdout.writeln(
    'Average opportunities/day: '
    '${r.averageOpportunitiesPerDay.toStringAsFixed(4)}',
  );
  stdout.writeln(
    'Median opportunities/day: '
    '${r.medianOpportunitiesPerDay.toStringAsFixed(2)}',
  );
  stdout.writeln('0-opportunity days: ${r.zeroOpportunityDays}');
  stdout.writeln('1-opportunity days: ${r.oneOpportunityDays}');
  stdout.writeln('2-opportunity days: ${r.twoOpportunityDays}');
  stdout.writeln('3+-opportunity days: ${r.threePlusOpportunityDays}');
  stdout.writeln('Elapsed: ${stopwatch.elapsed}');
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
