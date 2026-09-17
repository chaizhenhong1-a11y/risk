import 'dart:io';

import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/diagnostics/transition_regime_research_diagnostics.dart';

const _expectedFiles = <MarketTimeframe, String>{
  MarketTimeframe.m5: 'XAUUSD_M5_2024_2026.csv',
  MarketTimeframe.m15: 'XAUUSD_M15_2024_2026.csv',
  MarketTimeframe.h1: 'XAUUSD_H1_2024_2026.csv',
  MarketTimeframe.h4: 'XAUUSD_H4_2024_2026.csv',
};

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_transition_regime_research.dart '
      '<history-directory>',
    );
    exitCode = 64;
    return;
  }

  final directory = Directory(args.first);
  const adapter = Mt5HistoryAdapter();
  final loaded = <MarketTimeframe, Mt5HistorySeries>{};

  for (final entry in _expectedFiles.entries) {
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

  final evaluator = const StrategySetupHistoricalReplay()
      .create(feed: feed, parameters: parameters)
      .evaluator;
  const classifier = MarketRegimeClassifier();
  final diagnostics = TransitionRegimeResearchDiagnostics();

  MarketRegime? previousRegime;
  var observations = 0;
  final stopwatch = Stopwatch()..start();

  for (final observation in feed.observations()) {
    observations++;
    if (observations % 5000 == 0) {
      stdout.writeln(
        'Progress: $observations/100049 elapsed=${stopwatch.elapsed}',
      );
    }

    final source = evaluator(observation);
    if (!source.wasAnalyzed) continue;

    final analysis = source.analysis!;
    final regime = classifier.classify(
      h4Structure: analysis.bias.h4Structure,
      h1Structure: analysis.bias.h1Structure,
    );

    if (regime.regime == MarketRegime.transition) {
      diagnostics.observeTransition(
        h4: regime.h4Structure,
        h1: regime.h1Structure,
        m15: source.m15Structure!,
      );
    } else if (previousRegime == MarketRegime.transition) {
      diagnostics.observeExit(regime.regime.name);
    }

    previousRegime = regime.regime;
  }

  diagnostics.finishOpenEpisode();
  final report = diagnostics.report();

  stdout.writeln('');
  stdout.writeln('TradeForge V2 — Increment 101 Transition Research');
  stdout.writeln('Transition observations: ${report.totalObservations}');
  stdout.writeln('Transition episodes: ${report.episodeLengths.length}');
  stdout.writeln(
    'Average episode length (M5 observations): '
    '${report.averageEpisodeLength.toStringAsFixed(2)}',
  );
  stdout.writeln(
    'Median episode length (M5 observations): '
    '${report.medianEpisodeLength.toStringAsFixed(2)}',
  );
  stdout.writeln('');

  for (final pair in TransitionStructurePair.values) {
    final count = report.observations[pair] ?? 0;
    stdout.writeln(
      '${pair.name}: $count '
      '(${(report.share(pair) * 100).toStringAsFixed(2)}%)',
    );
    final m15 = report.m15Structures[pair]!;
    stdout.writeln(
      '  M15 bullish=${m15[MarketStructure.bullish]} '
      'bearish=${m15[MarketStructure.bearish]} '
      'neutral=${m15[MarketStructure.neutral]} '
      'unknown=${m15[MarketStructure.unknown]}',
    );
  }

  stdout.writeln('');
  stdout.writeln('Transition exits:');
  final exits = report.exits.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final exit in exits) {
    stdout.writeln('  ${exit.key}: ${exit.value}');
  }

  stdout.writeln('');
  stdout.writeln(
    'Research only. Do not modify Strategy A/B or define Strategy C '
    'profitability rules from this dataset.',
  );
}
