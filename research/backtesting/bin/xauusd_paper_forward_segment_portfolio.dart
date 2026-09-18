import 'dart:io';

import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/strategy_library/mainstream_strategy_batch.dart';
import 'package:tradeforge_backtesting/src/strategy_library/paper_forward_segment_portfolio.dart';
import 'package:tradeforge_backtesting/src/strategy_library/strategy_edge_segmentation.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_paper_forward_segment_portfolio.dart <history-directory>',
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

  stdout.writeln('Loading MT5 history: ${file.path}');
  final candles = const Mt5HistoryAdapter()
      .parse(content: file.readAsStringSync(), timeframe: MarketTimeframe.m5)
      .candles;
  stdout.writeln('Loaded ${candles.length} CLOSED M5 candles.');

  final batch = const MainstreamStrategyBatch().run(candles);
  final segments = const StrategyEdgeSegmentation().evaluate(batch);
  const portfolio = PaperForwardSegmentPortfolio();
  final problems = portfolio.evidenceProblems(segments);
  if (problems.isNotEmpty) {
    stderr.writeln('Frozen portfolio evidence check failed:');
    for (final problem in problems) {
      stderr.writeln('  $problem');
    }
    exitCode = 2;
    return;
  }

  final selected = portfolio.select(batch);
  final clusters = portfolio.cluster(selected);
  final multiMember = clusters
      .where((cluster) => cluster.members.length > 1)
      .length;

  stdout.writeln('Frozen paper-forward portfolio V1:');
  for (final definition in paperForwardSegmentPortfolioV1) {
    final count = selected
        .where((item) => item.segmentId == definition.id)
        .length;
    stdout.writeln('  ${definition.id}: $count historical candidates');
  }
  stdout.writeln('Raw selected candidates: ${selected.length}');
  stdout.writeln('Deduplicated opportunity clusters: ${clusters.length}');
  stdout.writeln('Multi-strategy clusters: $multiMember');
  stdout.writeln(
    'Research/paper-forward only. This command does not enable live BUY/SELL.',
  );
}
