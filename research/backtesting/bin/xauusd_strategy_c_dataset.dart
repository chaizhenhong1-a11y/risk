import 'dart:io';

import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_research_dataset.dart';

const _files = <MarketTimeframe, String>{
  MarketTimeframe.m5: 'XAUUSD_M5_2024_2026.csv',
  MarketTimeframe.m15: 'XAUUSD_M15_2024_2026.csv',
  MarketTimeframe.h1: 'XAUUSD_H1_2024_2026.csv',
  MarketTimeframe.h4: 'XAUUSD_H4_2024_2026.csv',
};

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_strategy_c_dataset.dart <history-directory>',
    );
    exitCode = 64;
    return;
  }

  final historyDirectory = Directory(args.first);
  const adapter = Mt5HistoryAdapter();
  final loaded = <MarketTimeframe, Mt5HistorySeries>{};

  for (final entry in _files.entries) {
    final file = File(
      '${historyDirectory.path}${Platform.pathSeparator}${entry.value}',
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

  final m5 = loaded[MarketTimeframe.m5]!.candles;
  final feed = MultiTimeframeBacktestFeed(
    m5Candles: m5,
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

  final samples = <StrategyCResearchSample>[];
  var index = -1;
  final stopwatch = Stopwatch()..start();

  for (final observation in feed.observations()) {
    index++;
    if ((index + 1) % 10000 == 0) {
      stdout.writeln(
        'Progress: ${index + 1}/100049 elapsed=${stopwatch.elapsed}',
      );
    }

    final source = evaluator(observation);
    if (!source.wasAnalyzed) continue;

    final analysis = source.analysis!;
    final regime = classifier.classify(
      h4Structure: analysis.bias.h4Structure,
      h1Structure: analysis.bias.h1Structure,
    );

    // Increment 105 freezes the broad uncovered research universe to
    // Transition. It does not create or modify production Strategy C.
    if (regime.regime != MarketRegime.transition) continue;

    final liquidity = source.levelLiquidityAnalysis!;
    final levelSweeps = liquidity.levelSweeps;
    final poolSweeps = liquidity.poolSweeps;

    double? forwardReturn(int horizon) {
      final target = index + horizon;
      if (target >= m5.length) return null;
      return m5[target].close - m5[index].close;
    }

    double? mfe48;
    double? mae48;
    if (index + 48 < m5.length) {
      var best = 0.0;
      var worst = 0.0;
      final entry = m5[index].close;
      for (var i = index + 1; i <= index + 48; i++) {
        final highMove = m5[i].high - entry;
        final lowMove = m5[i].low - entry;
        if (highMove > best) best = highMove;
        if (lowMove < worst) worst = lowMove;
      }
      mfe48 = best;
      mae48 = worst.abs();
    }

    samples.add(
      StrategyCResearchSample(
        time: observation.observationTime,
        close: m5[index].close,
        h4Structure: regime.h4Structure.name,
        h1Structure: regime.h1Structure.name,
        m15Structure: source.m15Structure!.name,
        regime: regime.regime.name,
        supportSweep: levelSweeps.any(
          (s) => s.direction == LiquiditySweepDirection.belowSupport,
        ),
        resistanceSweep: levelSweeps.any(
          (s) => s.direction == LiquiditySweepDirection.aboveResistance,
        ),
        equalLowSweep: poolSweeps.any(
          (s) => s.direction == LiquidityPoolSweepDirection.belowEqualLows,
        ),
        equalHighSweep: poolSweeps.any(
          (s) => s.direction == LiquidityPoolSweepDirection.aboveEqualHighs,
        ),
        return12: forwardReturn(12),
        return24: forwardReturn(24),
        return48: forwardReturn(48),
        mfe48: mfe48,
        mae48: mae48,
      ),
    );
  }

  final outputDirectory = Directory(
    '${Directory.current.path}${Platform.pathSeparator}.research_cache'
    '${Platform.pathSeparator}strategy_c',
  )..createSync(recursive: true);

  final datasetFile = File(
    '${outputDirectory.path}${Platform.pathSeparator}'
    'xauusd_transition_samples.jsonl',
  );
  datasetFile.writeAsStringSync(
    samples.map((sample) => sample.toJsonLine()).join('\n'),
  );

  final manifest = StrategyCResearchDatasetManifest(
    schemaVersion: 1,
    symbol: 'XAUUSD',
    sampleCount: samples.length,
    createdAt: DateTime.now(),
    note:
        'Research-only Transition samples. A/B and production Strategy C are '
        'unchanged. C1/C2/C3 from Increment 104 remain rejected.',
  );
  final manifestFile = File(
    '${outputDirectory.path}${Platform.pathSeparator}manifest.json',
  )..writeAsStringSync(manifest.toPrettyJson());

  stdout.writeln('');
  stdout.writeln('TradeForge V2 — Increment 105 Strategy C Dataset');
  stdout.writeln('Transition samples: ${samples.length}');
  stdout.writeln('Dataset: ${datasetFile.path}');
  stdout.writeln('Manifest: ${manifestFile.path}');
  stdout.writeln('');
  stdout.writeln(
    'The generated .research_cache is local research output and must not be '
    'committed. Future feature research can read this dataset without '
    'replaying all 100049 M5 observations.',
  );
}
