import 'dart:io';

import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/diagnostics/neutral_transition_direction_emergence_diagnostics.dart';

const _files = <MarketTimeframe, String>{
  MarketTimeframe.m5: 'XAUUSD_M5_2024_2026.csv',
  MarketTimeframe.m15: 'XAUUSD_M15_2024_2026.csv',
  MarketTimeframe.h1: 'XAUUSD_H1_2024_2026.csv',
  MarketTimeframe.h4: 'XAUUSD_H4_2024_2026.csv',
};

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run '
      'bin/xauusd_neutral_transition_direction_emergence_discovery.dart '
      '<history-directory>',
    );
    exitCode = 64;
    return;
  }

  const adapter = Mt5HistoryAdapter();
  final loaded = <MarketTimeframe, Mt5HistorySeries>{};

  for (final entry in _files.entries) {
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

  final m5Candles = loaded[MarketTimeframe.m5]!.candles;
  final m5CloseByTime = <DateTime, double>{
    for (final candle in m5Candles) candle.closeTime: candle.close,
  };

  final feed = MultiTimeframeBacktestFeed(
    m5Candles: m5Candles,
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

  const replay = StrategySetupHistoricalReplay();
  final evaluator = replay.create(feed: feed, parameters: parameters).evaluator;
  final analyzedRows = <_AnalyzedRow>[];
  var analyzed = 0;

  for (final observation in feed.observations()) {
    final source = evaluator(observation);
    if (!source.wasAnalyzed) continue;

    final close = m5CloseByTime[observation.observationTime];
    if (close == null) continue;

    analyzed++;
    if (analyzed % 10000 == 0) {
      stdout.writeln('Progress: analyzed=$analyzed');
    }

    final analysis = source.analysis!;
    analyzedRows.add(
      _AnalyzedRow(
        time: observation.observationTime,
        close: close,
        h4: analysis.bias.h4Structure,
        h1: analysis.bias.h1Structure,
        m15: source.m15Structure!,
      ),
    );
  }

  final samples = <DirectionEmergenceSample>[];
  var inNeutralEpisode = false;
  DateTime? neutralStartedAt;

  for (var i = 0; i < analyzedRows.length; i++) {
    final row = analyzedRows[i];
    final fullyNeutral =
        row.h4 == MarketStructure.neutral &&
        row.h1 == MarketStructure.neutral &&
        row.m15 == MarketStructure.neutral;

    if (fullyNeutral) {
      if (!inNeutralEpisode) {
        inNeutralEpisode = true;
        neutralStartedAt = row.time;
      }
      continue;
    }

    if (!inNeutralEpisode) continue;

    inNeutralEpisode = false;

    EmergenceDirection? direction;
    if (row.h4 == MarketStructure.neutral &&
        row.h1 == MarketStructure.neutral) {
      if (row.m15 == MarketStructure.bullish) {
        direction = EmergenceDirection.bullish;
      } else if (row.m15 == MarketStructure.bearish) {
        direction = EmergenceDirection.bearish;
      }
    }

    if (direction == null || i + 48 >= analyzedRows.length) {
      neutralStartedAt = null;
      continue;
    }

    final entry = row.close;
    samples.add(
      DirectionEmergenceSample(
        neutralStartedAt: neutralStartedAt!,
        emergedAt: row.time,
        direction: direction,
        return12: analyzedRows[i + 12].close - entry,
        return24: analyzedRows[i + 24].close - entry,
        return48: analyzedRows[i + 48].close - entry,
      ),
    );
    neutralStartedAt = null;
  }

  final summary = const NeutralTransitionDirectionEmergenceDiagnostics()
      .summarize(samples);

  stdout.writeln('');
  stdout.writeln(
    'TradeForge V2 — Increment 130 Neutral Transition Direction Emergence Discovery',
  );
  stdout.writeln('Analyzed observations: $analyzed');
  stdout.writeln(
    'Independent neutral episodes with observable M15 direction emergence: '
    '${summary.samples}',
  );
  stdout.writeln('Emergence days: ${summary.days}');
  stdout.writeln(
    'Bullish=${summary.bullishSamples} Bearish=${summary.bearishSamples}',
  );
  stdout.writeln(
    '12M5=${_pct(summary.continuation12)} '
    '24M5=${_pct(summary.continuation24)} '
    '48M5=${_pct(summary.continuation48)}',
  );
  stdout.writeln(
    'Discovery only: continuation percentages are not trade win rates.',
  );
}

String _pct(double value) => '${(value * 100).toStringAsFixed(2)}%';

final class _AnalyzedRow {
  const _AnalyzedRow({
    required this.time,
    required this.close,
    required this.h4,
    required this.h1,
    required this.m15,
  });

  final DateTime time;
  final double close;
  final MarketStructure h4;
  final MarketStructure h1;
  final MarketStructure m15;
}
