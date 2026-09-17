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

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_strategy_c_regime_gap.dart <history-directory>',
    );
    exitCode = 64;
    return;
  }

  final directory = Directory(args.first);
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

  final sourceEvaluator = const StrategySetupHistoricalReplay()
      .create(feed: feed, parameters: parameters)
      .evaluator;
  const regimeClassifier = MarketRegimeClassifier();
  const bAnalyzer = CorrectionContinuationAnalyzer();

  final diagnostics = StrategyCRegimeGapDiagnostics();
  MarketRegime? previousRegime;
  MarketStructure previousM15Structure = MarketStructure.unknown;
  var previousAEligible = false;
  var observations = 0;
  final stopwatch = Stopwatch()..start();

  for (final observation in feed.observations()) {
    if (observations >= 100049) break;
    observations++;

    if (observations % 5000 == 0) {
      stdout.writeln(
        'Progress: $observations/100049 elapsed=${stopwatch.elapsed}',
      );
    }

    final source = sourceEvaluator(observation);
    if (!source.wasAnalyzed) continue;

    final a = source.analysis!;
    final regime = regimeClassifier.classify(
      h4Structure: a.bias.h4Structure,
      h1Structure: a.bias.h1Structure,
    );

    final aEligible = a.evaluation.isEligible;
    final aStarted = aEligible && !previousAEligible;
    previousAEligible = aEligible;

    final b = bAnalyzer.analyze(
      regimeAnalysis: regime,
      previousRegime: previousRegime,
      previousM15Structure: previousM15Structure,
      currentM15Structure: source.m15Structure!,
      directionalSweepEvidencePresent: false,
    );

    previousRegime = regime.regime;
    previousM15Structure = source.m15Structure!;

    diagnostics.observe(
      observedAt: observation.observationTime,
      regime: regime.regime,
      strategyAOpportunityStarted: aStarted,
      strategyBOpportunity: b.isEligible,
    );
  }

  final report = diagnostics.finish();
  stdout.writeln('');
  stdout.writeln('TradeForge V2 — Increment 100 Regime Gap Analysis');
  stdout.writeln('Trading days: ${report.tradingDays}');
  stdout.writeln('A+B zero-opportunity days: ${report.zeroOpportunityDays}');
  stdout.writeln('');
  for (final regime in MarketRegime.values) {
    stdout.writeln(
      '${regime.name}: observations=${report.regimeObservationCounts[regime]} '
      'share=${(report.observationShare(regime) * 100).toStringAsFixed(2)}% '
      'dominantDays=${report.dominantRegimeDayCounts[regime]}',
    );
  }
  stdout.writeln('');
  stdout.writeln(
    'Research only: use this output to define Strategy C responsibility; '
    'do not loosen Strategy A or B.',
  );
}
