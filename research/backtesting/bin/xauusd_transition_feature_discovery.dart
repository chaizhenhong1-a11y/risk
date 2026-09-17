import 'dart:io';

import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/diagnostics/transition_feature_discovery.dart';

const _files = <MarketTimeframe, String>{
  MarketTimeframe.m5: 'XAUUSD_M5_2024_2026.csv',
  MarketTimeframe.m15: 'XAUUSD_M15_2024_2026.csv',
  MarketTimeframe.h1: 'XAUUSD_H1_2024_2026.csv',
  MarketTimeframe.h4: 'XAUUSD_H4_2024_2026.csv',
};

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_transition_feature_discovery.dart '
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
  final discovery = TransitionFeatureDiscovery();

  var observations = 0;
  final stopwatch = Stopwatch()..start();

  for (final observation in feed.observations()) {
    observations++;
    if (observations % 10000 == 0) {
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
      final liquidity = source.levelLiquidityAnalysis!;
      final levelSweeps = liquidity.levelSweeps;
      final poolSweeps = liquidity.poolSweeps;

      discovery.observeTransition(
        h4: regime.h4Structure,
        h1: regime.h1Structure,
        m15: source.m15Structure!,
        supportSweep: levelSweeps.any(
          (sweep) => sweep.direction == LiquiditySweepDirection.belowSupport,
        ),
        resistanceSweep: levelSweeps.any(
          (sweep) => sweep.direction == LiquiditySweepDirection.aboveResistance,
        ),
        equalLowSweep: poolSweeps.any(
          (sweep) =>
              sweep.direction == LiquidityPoolSweepDirection.belowEqualLows,
        ),
        equalHighSweep: poolSweeps.any(
          (sweep) =>
              sweep.direction == LiquidityPoolSweepDirection.aboveEqualHighs,
        ),
      );
    } else {
      discovery.observeExit(regime.regime.name);
    }
  }

  final report = discovery.finish();

  stdout.writeln('');
  stdout.writeln('TradeForge V2 — Increment 103 Transition Feature Discovery');
  stdout.writeln('Feature states are research episodes, not trades.');
  stdout.writeln('Rows with n >= 3:');
  stdout.writeln('');

  for (final row in report.rows) {
    if (row.samples < 3) continue;
    stdout.writeln(
      'H4=${row.h4.name} H1=${row.h1.name} M15=${row.m15.name} '
      'sweep=${row.sweepLabel} n=${row.samples} '
      'trend=${row.trend} correction=${row.correction} other=${row.other} '
      'trendShare=${(row.trendShare * 100).toStringAsFixed(1)}% '
      'correctionShare=${(row.correctionShare * 100).toStringAsFixed(1)}% '
      'avgWaitM5=${row.averageWaitM5.toStringAsFixed(1)}',
    );
  }

  stdout.writeln('');
  stdout.writeln(
    'One-pass research output. Strategy A/B unchanged; no Strategy C '
    'production promotion.',
  );
}
