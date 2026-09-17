import 'dart:convert';
import 'dart:io';

import 'package:strategy_engine/strategy_engine.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/diagnostics/strategy_abc_coverage.dart';

const files = <MarketTimeframe, String>{
  MarketTimeframe.m5: 'XAUUSD_M5_2024_2026.csv',
  MarketTimeframe.m15: 'XAUUSD_M15_2024_2026.csv',
  MarketTimeframe.h1: 'XAUUSD_H1_2024_2026.csv',
  MarketTimeframe.h4: 'XAUUSD_H4_2024_2026.csv',
};

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_strategy_abc_coverage.dart '
      '<history-directory>',
    );
    exitCode = 64;
    return;
  }

  const adapter = Mt5HistoryAdapter();
  final loaded = <MarketTimeframe, Mt5HistorySeries>{};

  for (final entry in files.entries) {
    final file = File('${args.first}${Platform.pathSeparator}${entry.value}');
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
    equalityTolerance: .10,
    zoneHalfWidth: .50,
    levelMergeMaxGap: .20,
    scoreProfile: SetupScoreProfiles.baselineResearchV1,
  );

  const sourceReplay = StrategySetupHistoricalReplay();

  final aEvaluator = sourceReplay
      .create(feed: feed, parameters: parameters)
      .evaluator;

  final bEvaluator = const CorrectionContinuationHistoricalReplay()
      .create(
        feed: feed,
        sourceReplay: sourceReplay,
        sourceParameters: parameters,
      )
      .evaluator;

  final events = <CoverageEvent>[];
  final dates = <DateTime>{};
  var previousA = false;
  var observations = 0;
  final stopwatch = Stopwatch()..start();

  for (final observation in feed.observations()) {
    observations++;
    dates.add(
      DateTime.utc(
        observation.observationTime.year,
        observation.observationTime.month,
        observation.observationTime.day,
      ),
    );

    if (observations % 10000 == 0) {
      stdout.writeln(
        'Progress: $observations/100049 elapsed=${stopwatch.elapsed}',
      );
    }

    final a = aEvaluator(observation);
    final aQualified = a.wasAnalyzed && a.analysis!.evaluation.isEligible;

    if (aQualified && !previousA) {
      final bias = a.analysis!.bias.bias;
      if (bias != TradingBias.noTrade) {
        events.add(
          CoverageEvent(
            time: observation.observationTime,
            direction: _direction(bias),
            source: CoverageSource.strategyA,
          ),
        );
      }
    }
    previousA = aQualified;

    final b = bEvaluator(observation);
    if (b != null && b.isCandidate) {
      final bias = b.analysis.bias;
      if (bias != TradingBias.noTrade) {
        events.add(
          CoverageEvent(
            time: observation.observationTime,
            direction: _direction(bias),
            source: CoverageSource.strategyB,
          ),
        );
      }
    }
  }

  final c5File = File(
    '.research_cache${Platform.pathSeparator}strategy_c'
    '${Platform.pathSeparator}xauusd_c5_structural_risk.jsonl',
  );

  if (!c5File.existsSync()) {
    stderr.writeln(
      'Missing C5 cache: ${c5File.path}. Run Increment 117 first.',
    );
    exitCode = 66;
    return;
  }

  for (final line in c5File.readAsLinesSync()) {
    if (line.trim().isEmpty) {
      continue;
    }

    final json = jsonDecode(line) as Map<String, dynamic>;
    events.add(
      CoverageEvent(
        time: DateTime.parse(json['time'] as String),
        direction: CoverageDirection.buy,
        source: CoverageSource.strategyC5,
      ),
    );
  }

  final result = const StrategyAbcCoverageAnalyzer().analyze(
    tradingDates: dates,
    events: events,
  );

  final counts = [...result.dailyCounts]..sort();
  final median = counts.isEmpty
      ? 0.0
      : counts.length.isOdd
      ? counts[counts.length ~/ 2].toDouble()
      : (counts[counts.length ~/ 2 - 1] + counts[counts.length ~/ 2]) / 2;

  int daysWith(int count) =>
      result.dailyCounts.where((value) => value == count).length;

  stopwatch.stop();

  stdout.writeln('');
  stdout.writeln('TradeForge V2 — Increment 120 A+B+C5 Coverage');
  stdout.writeln('Observed M5 closes: $observations');
  stdout.writeln('Trading days: ${result.dailyCounts.length}');
  stdout.writeln(
    'Strategy A candidate episodes: '
    '${result.sourceCounts[CoverageSource.strategyA]}',
  );
  stdout.writeln(
    'Strategy B candidate events: '
    '${result.sourceCounts[CoverageSource.strategyB]}',
  );
  stdout.writeln(
    'Strategy C5 candidate episodes: '
    '${result.sourceCounts[CoverageSource.strategyC5]}',
  );
  stdout.writeln('Same-direction overlaps: ${result.sameDirectionOverlaps}');
  stdout.writeln(
    'Opposite-direction conflicts: ${result.oppositeDirectionConflicts}',
  );
  stdout.writeln('A+B+C5 unique opportunities: ${result.uniqueOpportunities}');
  stdout.writeln(
    'Average opportunities/day: '
    '${result.averagePerDay.toStringAsFixed(4)}',
  );
  stdout.writeln('Median opportunities/day: ${median.toStringAsFixed(2)}');
  stdout.writeln('0-opportunity days: ${daysWith(0)}');
  stdout.writeln('1-opportunity days: ${daysWith(1)}');
  stdout.writeln('2-opportunity days: ${daysWith(2)}');
  stdout.writeln(
    '3+-opportunity days: '
    '${result.dailyCounts.where((value) => value >= 3).length}',
  );
  stdout.writeln(
    'Pre-Final-Review coverage only. Opportunities are not trades.',
  );
}

CoverageDirection _direction(TradingBias bias) {
  return bias == TradingBias.buy
      ? CoverageDirection.buy
      : CoverageDirection.sell;
}
