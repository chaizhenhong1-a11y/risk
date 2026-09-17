import 'dart:io';

import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_trigger_research_dataset.dart';

const _files = <MarketTimeframe, String>{
  MarketTimeframe.m5: 'XAUUSD_M5_2024_2026.csv',
  MarketTimeframe.m15: 'XAUUSD_M15_2024_2026.csv',
  MarketTimeframe.h1: 'XAUUSD_H1_2024_2026.csv',
  MarketTimeframe.h4: 'XAUUSD_H4_2024_2026.csv',
};

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_strategy_c_trigger_dataset.dart '
      '<history-directory>',
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

  final samples = <StrategyCTriggerResearchSample>[];
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
    if (!source.wasAnalyzed || index < 3) {
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

    // C5 frozen context from Increment 107/108:
    // H4 neutral + H1 bullish + M15 bearish + resistance sweep.
    // Exact sweep state must be "resistance" only, matching Increment 106-108.
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

    // Export one row per independent C5 episode start. This prevents the
    // repeated-observation inflation fixed in Increment 107.
    if (c5 && !previousC5) {
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
          final up = m5[i].high - entry;
          final down = m5[i].low - entry;
          if (up > best) best = up;
          if (down < worst) worst = down;
        }
        mfe48 = best;
        mae48 = worst.abs();
      }

      samples.add(
        StrategyCTriggerResearchSample(
          time: observation.observationTime,
          open: m5[index].open,
          high: m5[index].high,
          low: m5[index].low,
          close: m5[index].close,
          previousClose: m5[index - 1].close,
          previous2Close: m5[index - 2].close,
          previous3Close: m5[index - 3].close,
          h4Structure: regime.h4Structure.name,
          h1Structure: regime.h1Structure.name,
          m15Structure: source.m15Structure!.name,
          resistanceSweep: resistanceSweep,
          return12: forwardReturn(12),
          return24: forwardReturn(24),
          return48: forwardReturn(48),
          mfe48: mfe48,
          mae48: mae48,
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
    'xauusd_c5_trigger_episodes.jsonl',
  );
  output.writeAsStringSync(
    samples.map((sample) => sample.toJsonLine()).join('\n'),
  );

  stdout.writeln('');
  stdout.writeln('TradeForge V2 — Increment 109 C5 Trigger Dataset');
  stdout.writeln('Independent C5 episodes: ${samples.length}');
  stdout.writeln('Dataset: ${output.path}');
  stdout.writeln(
    'Research only. This adds M5 trigger features; it does not modify '
    'production Strategy C, A, or B.',
  );
}
