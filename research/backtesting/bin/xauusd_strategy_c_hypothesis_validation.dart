import 'dart:io';

import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/diagnostics/strategy_c_hypothesis_validation.dart';

const _files = <MarketTimeframe, String>{
  MarketTimeframe.m5: 'XAUUSD_M5_2024_2026.csv',
  MarketTimeframe.m15: 'XAUUSD_M15_2024_2026.csv',
  MarketTimeframe.h1: 'XAUUSD_H1_2024_2026.csv',
  MarketTimeframe.h4: 'XAUUSD_H4_2024_2026.csv',
};

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_strategy_c_hypothesis_validation.dart '
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

  final candidates = <StrategyCHypothesisCandidate>[];
  final lastMatch = <StrategyCHypothesisId, bool>{
    for (final id in StrategyCHypothesisId.values) id: false,
  };

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
    if (!source.wasAnalyzed) {
      for (final id in StrategyCHypothesisId.values) {
        lastMatch[id] = false;
      }
      continue;
    }

    final analysis = source.analysis!;
    final regime = classifier.classify(
      h4Structure: analysis.bias.h4Structure,
      h1Structure: analysis.bias.h1Structure,
    );

    if (regime.regime != MarketRegime.transition) {
      for (final id in StrategyCHypothesisId.values) {
        lastMatch[id] = false;
      }
      continue;
    }

    final liquidity = source.levelLiquidityAnalysis!;
    final levelSweeps = liquidity.levelSweeps;
    final poolSweeps = liquidity.poolSweeps;
    final supportSweep = levelSweeps.any(
      (s) => s.direction == LiquiditySweepDirection.belowSupport,
    );
    final resistanceSweep = levelSweeps.any(
      (s) => s.direction == LiquiditySweepDirection.aboveResistance,
    );
    final equalLowSweep = poolSweeps.any(
      (s) => s.direction == LiquidityPoolSweepDirection.belowEqualLows,
    );
    final equalHighSweep = poolSweeps.any(
      (s) => s.direction == LiquidityPoolSweepDirection.aboveEqualHighs,
    );

    for (final id in StrategyCHypothesisId.values) {
      final matched = StrategyCHypothesisValidation.matches(
        id: id,
        h4: regime.h4Structure,
        h1: regime.h1Structure,
        m15: source.m15Structure!,
        supportSweep: supportSweep,
        resistanceSweep: resistanceSweep,
        equalLowSweep: equalLowSweep,
        equalHighSweep: equalHighSweep,
      );

      // Count a contiguous feature state once, not once per M5 close.
      if (matched && !(lastMatch[id] ?? false)) {
        final direction = switch (id) {
          StrategyCHypothesisId.c1BullishTrendRecovery =>
            StrategyCExpectedDirection.bullish,
          StrategyCHypothesisId.c2BearishTrendRecovery =>
            StrategyCExpectedDirection.bearish,
          StrategyCHypothesisId.c3BearishCorrectionContinuation =>
            StrategyCExpectedDirection.bullish,
        };
        candidates.add(
          StrategyCHypothesisCandidate(
            id: id,
            expectedDirection: direction,
            observationIndex: index,
            observationTime: observation.observationTime,
            entryClose: m5[index].close,
          ),
        );
      }
      lastMatch[id] = matched;
    }
  }

  final results = <StrategyCHypothesisResult>[];
  for (final candidate in candidates) {
    double? signedReturn(int horizon) {
      final target = candidate.observationIndex + horizon;
      if (target >= m5.length) return null;
      return m5[target].close - candidate.entryClose;
    }

    final end = candidate.observationIndex + 48;
    double? mfe;
    double? mae;
    if (end < m5.length) {
      var best = 0.0;
      var worst = 0.0;
      for (var i = candidate.observationIndex + 1; i <= end; i++) {
        final candle = m5[i];
        final highMove = candle.high - candidate.entryClose;
        final lowMove = candle.low - candidate.entryClose;
        if (candidate.expectedDirection == StrategyCExpectedDirection.bullish) {
          if (highMove > best) best = highMove;
          if (lowMove < worst) worst = lowMove;
        } else {
          final favorable = candidate.entryClose - candle.low;
          final adverse = candidate.entryClose - candle.high;
          if (favorable > best) best = favorable;
          if (adverse < worst) worst = adverse;
        }
      }
      mfe = best;
      mae = worst.abs();
    }

    results.add(
      StrategyCHypothesisResult(
        candidate: candidate,
        return12: signedReturn(12),
        return24: signedReturn(24),
        return48: signedReturn(48),
        mfe48: mfe,
        mae48: mae,
        resolved12: candidate.observationIndex + 12 < m5.length,
        resolved24: candidate.observationIndex + 24 < m5.length,
        resolved48: candidate.observationIndex + 48 < m5.length,
      ),
    );
  }

  const validation = StrategyCHypothesisValidation();

  stdout.writeln('');
  stdout.writeln('TradeForge V2 — Increment 104 Strategy C Validation');
  stdout.writeln('Frozen hypotheses; candidate episodes are not trades.');
  stdout.writeln('');

  for (final id in StrategyCHypothesisId.values) {
    final s = validation.summarize(id, results);
    stdout.writeln(id.name);
    stdout.writeln('  candidates=${s.candidates}');
    stdout.writeln(
      '  12M5=${s.correct12}/${s.resolved12} '
      '(${(s.share(s.correct12, s.resolved12) * 100).toStringAsFixed(1)}%)',
    );
    stdout.writeln(
      '  24M5=${s.correct24}/${s.resolved24} '
      '(${(s.share(s.correct24, s.resolved24) * 100).toStringAsFixed(1)}%)',
    );
    stdout.writeln(
      '  48M5=${s.correct48}/${s.resolved48} '
      '(${(s.share(s.correct48, s.resolved48) * 100).toStringAsFixed(1)}%)',
    );
    stdout.writeln(
      '  avgMFE48=${s.averageMfe48.toStringAsFixed(3)} '
      'avgMAE48=${s.averageMae48.toStringAsFixed(3)}',
    );
  }

  stdout.writeln('');
  stdout.writeln(
    'Research only. No Entry/SL/TP/RR, costs, or production Strategy C '
    'changes are implied by these results.',
  );
}
