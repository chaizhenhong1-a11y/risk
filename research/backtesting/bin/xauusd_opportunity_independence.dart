import 'dart:io';

import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/strategy_library/mainstream_strategy_batch.dart';
import 'package:tradeforge_backtesting/src/strategy_library/opportunity_independence_analysis.dart';
import 'package:tradeforge_backtesting/src/strategy_library/paper_forward_segment_portfolio.dart';

const batch3SegmentPass = <PaperForwardSegmentDefinition>[
  PaperForwardSegmentDefinition(
    strategyId: 'FAILED_BREAKOUT_V2',
    side: ResearchSide.sell,
    regime: 'range',
  ),
  PaperForwardSegmentDefinition(
    strategyId: 'ENGULFING_REVERSAL',
    side: ResearchSide.buy,
    regime: 'trend',
  ),
  PaperForwardSegmentDefinition(
    strategyId: 'SR_RECLAIM_V2',
    side: ResearchSide.sell,
    regime: 'range',
  ),
  PaperForwardSegmentDefinition(
    strategyId: 'EMA_TREND_RECLAIM',
    side: ResearchSide.sell,
    regime: 'range',
  ),
  PaperForwardSegmentDefinition(
    strategyId: 'ENGULFING_REVERSAL',
    side: ResearchSide.sell,
    regime: 'range',
  ),
  PaperForwardSegmentDefinition(
    strategyId: 'NR7_BREAKOUT',
    side: ResearchSide.sell,
    regime: 'range',
  ),
];

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_opportunity_independence.dart '
      '<history-directory>',
    );
    exitCode = 64;
    return;
  }

  final file = File(
    '${args.first}${Platform.pathSeparator}XAUUSD_M5_2024_2026.csv',
  );
  if (!file.existsSync()) {
    stderr.writeln('Missing: ${file.path}');
    exitCode = 66;
    return;
  }

  final candles = const Mt5HistoryAdapter()
      .parse(content: file.readAsStringSync(), timeframe: MarketTimeframe.m5)
      .candles;
  final results = const MainstreamStrategyBatch().run(candles);

  const analyzer = OpportunityIndependenceAnalyzer();
  final reports = analyzer.evaluate(
    results: results,
    baseline: paperForwardSegmentPortfolioV2,
    challengers: batch3SegmentPass,
  );

  stdout.writeln('TradeForge V2 — Opportunity Independence / Attribution');
  stdout.writeln('Loaded ${candles.length} CLOSED M5 candles.');
  stdout.writeln(
    'Baseline: 5 frozen mainstream paper-forward segments from Portfolio V2.',
  );
  stdout.writeln(
    'A and C5 are intentionally NOT approximated here: they run through '
    'separate frozen MTF engines and this M5 batch does not expose equivalent '
    'historical candidate timestamps. Their independence must be joined from '
    'their canonical detector journals, not guessed.',
  );
  stdout.writeln(
    'A challenger cluster is marginal only when no baseline cluster of the '
    'same side exists within ±15 minutes.',
  );
  stdout.writeln(
    'Historical attribution only. This does not promote any challenger.',
  );
  stdout.writeln(
    'segment\traw\tclusters\toverlap\tmarginal\toverlap%\tmarginal%',
  );

  for (final r in reports) {
    stdout.writeln(
      '${r.definition.id}\t'
      '${r.rawCandidates}\t'
      '${r.totalClusters}\t'
      '${r.overlappingClusters}\t'
      '${r.marginalClusters}\t'
      '${(r.overlapRatio * 100).toStringAsFixed(1)}%\t'
      '${(r.marginalRatio * 100).toStringAsFixed(1)}%',
    );
  }

  final ranked = [...reports]
    ..sort((a, b) => b.marginalRatio.compareTo(a.marginalRatio));
  stdout.writeln(
    '\nMarginal-opportunity ordering (diagnostic, not promotion):',
  );
  for (final r in ranked) {
    stdout.writeln(
      '${r.definition.id}: ${r.marginalClusters}/${r.totalClusters} '
      '(${(r.marginalRatio * 100).toStringAsFixed(1)}%)',
    );
  }
}
