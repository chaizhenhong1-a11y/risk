import 'dart:io';

import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_structural_risk_dataset.dart';

const _files = <MarketTimeframe, String>{
  MarketTimeframe.m5: 'XAUUSD_M5_2024_2026.csv',
  MarketTimeframe.m15: 'XAUUSD_M15_2024_2026.csv',
  MarketTimeframe.h1: 'XAUUSD_H1_2024_2026.csv',
  MarketTimeframe.h4: 'XAUUSD_H4_2024_2026.csv',
};

const _atrPeriod = 14;
const _atrBufferMultiplier = 0.50;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_strategy_c_structural_risk_dataset.dart '
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
  const atr = AverageTrueRange();

  final samples = <StrategyCStructuralRiskSample>[];
  var previousC5 = false;
  var observations = 0;
  var c5EpisodesWithoutAtr = 0;
  var c5EpisodesWithoutSupport = 0;
  final stopwatch = Stopwatch()..start();

  for (final observation in feed.observations()) {
    observations++;
    if (observations % 10000 == 0) {
      stdout.writeln(
        'Progress: $observations/100049 elapsed=${stopwatch.elapsed}',
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

    if (c5 && !previousC5) {
      final m15History = observation.historyFor(MarketTimeframe.m15);
      if (m15History.length < _atrPeriod + 1) {
        c5EpisodesWithoutAtr++;
        previousC5 = c5;
        continue;
      }

      final m15Atr14 = atr.calculate(candles: m15History, period: _atrPeriod);
      final entry = observation.currentM5Candle.close;

      // C5 is a bullish research candidate. The structural invalidation proxy
      // is the nearest ACTIVE M15 support entirely below the entry price.
      // The protective stop is placed below the support zone's lower bound
      // plus the already-established M15 ATR(14) x 0.50 buffer convention.
      final supports =
          liquidity.keyLevels
              .where(
                (level) =>
                    level.isActive &&
                    level.type == KeyLevelType.support &&
                    level.upperBound < entry,
              )
              .toList()
            ..sort((a, b) => b.upperBound.compareTo(a.upperBound));

      final support = supports.isEmpty ? null : supports.first;
      final atrBuffer = m15Atr14 * _atrBufferMultiplier;

      double? structureDistance;
      double? bufferedStopPrice;
      double? bufferedStopDistance;
      if (support != null) {
        structureDistance = entry - support.lowerBound;
        bufferedStopPrice = support.lowerBound - atrBuffer;
        bufferedStopDistance = entry - bufferedStopPrice;
      } else {
        c5EpisodesWithoutSupport++;
      }

      samples.add(
        StrategyCStructuralRiskSample(
          time: observation.observationTime,
          entryClose: entry,
          m15Atr14: m15Atr14,
          supportLowerBound: support?.lowerBound,
          supportUpperBound: support?.upperBound,
          structureDistance: structureDistance,
          atrBuffer: atrBuffer,
          bufferedStopPrice: bufferedStopPrice,
          bufferedStopDistance: bufferedStopDistance,
        ),
      );
    }

    previousC5 = c5;
  }

  stopwatch.stop();

  final outputDirectory = Directory(
    '${Directory.current.path}${Platform.pathSeparator}.research_cache'
    '${Platform.pathSeparator}strategy_c',
  )..createSync(recursive: true);
  final output = File(
    '${outputDirectory.path}${Platform.pathSeparator}'
    'xauusd_c5_structural_risk.jsonl',
  );
  output.writeAsStringSync(
    samples.map((sample) => sample.toJsonLine()).join('\n'),
  );

  final available = samples
      .where((sample) => sample.hasStructuralSupport)
      .length;

  stdout.writeln('');
  stdout.writeln('TradeForge V2 — Increment 117 C5 Structural Risk Dataset');
  stdout.writeln('Observed M5 closes: $observations');
  stdout.writeln('Independent C5 episodes exported: ${samples.length}');
  stdout.writeln('Structural-risk available: $available');
  stdout.writeln('C5 episodes without ATR14: $c5EpisodesWithoutAtr');
  stdout.writeln(
    'C5 episodes without active support: $c5EpisodesWithoutSupport',
  );
  stdout.writeln('ATR: M15/$_atrPeriod');
  stdout.writeln('ATR buffer multiplier: $_atrBufferMultiplier');
  stdout.writeln(
    'Structural boundary: nearest active M15 support below entry, '
    'using support lower bound for invalidation.',
  );
  stdout.writeln('Dataset: ${output.path}');
  stdout.writeln(
    'Research only. This exports structural/ATR context and does not '
    'modify production Strategy A, B, or C.',
  );
}
