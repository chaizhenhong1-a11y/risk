import 'dart:io';

import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_forward_path_dataset.dart';

const _files = <MarketTimeframe, String>{
  MarketTimeframe.m5: 'XAUUSD_M5_2024_2026.csv',
  MarketTimeframe.m15: 'XAUUSD_M15_2024_2026.csv',
  MarketTimeframe.h1: 'XAUUSD_H1_2024_2026.csv',
  MarketTimeframe.h4: 'XAUUSD_H4_2024_2026.csv',
};

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_strategy_c_forward_path_dataset.dart '
      '<history-directory>',
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

  final episodes = <StrategyCForwardPathEpisode>[];
  var index = -1;
  var previousC5 = false;
  final stopwatch = Stopwatch()..start();

  for (final observation in feed.observations()) {
    index++;

    if ((index + 1) % 10000 == 0) {
      stdout.writeln(
        'Progress: ${index + 1}/100049 elapsed=${stopwatch.elapsed}',
      );
    }

    final source = evaluator(observation);
    if (!source.wasAnalyzed) {
      previousC5 = false;
      continue;
    }

    final analysis = source.analysis!;
    final regime = classifier.classify(
      h4Structure: analysis.bias.h4Structure,
      h1Structure: analysis.bias.h1Structure,
    );
    final liquidity = source.levelLiquidityAnalysis!;

    final resistanceSweep = liquidity.levelSweeps.any(
      (s) => s.direction == LiquiditySweepDirection.aboveResistance,
    );
    final hasOtherSweep =
        liquidity.levelSweeps.any(
          (s) => s.direction == LiquiditySweepDirection.belowSupport,
        ) ||
        liquidity.poolSweeps.isNotEmpty;

    final c5 =
        regime.regime == MarketRegime.transition &&
        regime.h4Structure == MarketStructure.neutral &&
        regime.h1Structure == MarketStructure.bullish &&
        source.m15Structure == MarketStructure.bearish &&
        resistanceSweep &&
        !hasOtherSweep;

    if (c5 && !previousC5 && index + 48 < m5.length) {
      final path = <StrategyCForwardBar>[
        for (var offset = 1; offset <= 48; offset++)
          StrategyCForwardBar(
            offset: offset,
            open: m5[index + offset].open,
            high: m5[index + offset].high,
            low: m5[index + offset].low,
            close: m5[index + offset].close,
          ),
      ];

      episodes.add(
        StrategyCForwardPathEpisode(
          time: observation.observationTime,
          entryOpen: m5[index].open,
          entryHigh: m5[index].high,
          entryLow: m5[index].low,
          entryClose: m5[index].close,
          forwardBars: path,
        ),
      );
    }

    previousC5 = c5;
  }

  final outputDirectory = Directory(
    '${Directory.current.path}${Platform.pathSeparator}.research_cache'
    '${Platform.pathSeparator}strategy_c',
  )..createSync(recursive: true);

  final output = File(
    '${outputDirectory.path}${Platform.pathSeparator}'
    'xauusd_c5_forward_paths.jsonl',
  );
  output.writeAsStringSync(
    episodes.map((episode) => episode.toJsonLine()).join('\n'),
  );

  stdout.writeln('');
  stdout.writeln('TradeForge V2 — Increment 111 C5 Forward Path Dataset');
  stdout.writeln('Independent C5 paths: ${episodes.length}');
  stdout.writeln('Bars per complete path: 48');
  stdout.writeln('Dataset: ${output.path}');
  stdout.writeln(
    'Research only. C5 context is frozen; A/B and production Strategy C '
    'remain unchanged.',
  );
}
