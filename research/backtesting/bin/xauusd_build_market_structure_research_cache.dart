import 'dart:io';

import 'package:strategy_engine/strategy_engine.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/cache/market_structure_research_cache.dart';

const _files = <MarketTimeframe, String>{
  MarketTimeframe.m5: 'XAUUSD_M5_2024_2026.csv',
  MarketTimeframe.m15: 'XAUUSD_M15_2024_2026.csv',
  MarketTimeframe.h1: 'XAUUSD_H1_2024_2026.csv',
  MarketTimeframe.h4: 'XAUUSD_H4_2024_2026.csv',
};

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_build_market_structure_research_cache.dart '
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

  final m5 = loaded[MarketTimeframe.m5]!.candles;
  final closeByTime = <DateTime, double>{
    for (final candle in m5) candle.closeTime: candle.close,
  };

  final feed = MultiTimeframeBacktestFeed(
    m5Candles: m5,
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
  const classifier = MarketRegimeClassifier();
  final rows = <MarketStructureResearchCacheRow>[];

  var analyzed = 0;
  for (final observation in feed.observations()) {
    final source = evaluator(observation);
    if (!source.wasAnalyzed) continue;

    final close = closeByTime[observation.observationTime];
    if (close == null) continue;

    analyzed++;
    if (analyzed % 10000 == 0) {
      stdout.writeln('Progress: analyzed=$analyzed');
    }

    final analysis = source.analysis!;
    final h4 = analysis.bias.h4Structure;
    final h1 = analysis.bias.h1Structure;
    final m15 = source.m15Structure!;
    final regime = classifier.classify(h4Structure: h4, h1Structure: h1);

    rows.add(
      MarketStructureResearchCacheRow(
        time: observation.observationTime,
        close: close,
        h4: h4,
        h1: h1,
        m15: m15,
        regime: regime.regime,
      ),
    );
  }

  final output = File(
    '.research_cache${Platform.pathSeparator}market_structure'
    '${Platform.pathSeparator}xauusd_market_structure.jsonl',
  );

  const MarketStructureResearchCache().write(output, rows);

  stdout.writeln('');
  stdout.writeln(
    'TradeForge V2 — Increment 131 Market Structure Research Cache',
  );
  stdout.writeln('Cached rows: ${rows.length}');
  stdout.writeln('Output: ${output.path}');
  stdout.writeln(
    'Future structural-gap research can read this cache instead of replaying '
    'the full 100k M5 history.',
  );
}
