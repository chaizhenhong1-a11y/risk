import 'dart:io';

import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/strategy_library/mainstream_strategy_batch.dart';
import 'package:tradeforge_backtesting/src/strategy_library/strategy_edge_segmentation.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_strategy_edge_segmentation.dart <history-directory>',
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
  final passCount = batch.where((r) => r.historicalGate).length;
  stdout.writeln(
    'Historical PASS strategies: $passCount. Segmenting SIDE x REGIME...',
  );

  final segments = const StrategyEdgeSegmentation().evaluate(batch);
  stdout.writeln(
    'strategy\tside\tregime\tresolved\twin%\tnetE\tPF\tfirst\tsecond\t'
    'years+\trolling+\toverlap%\tgate',
  );
  for (final segment in segments) {
    final r = segment.report;
    stdout.writeln(
      '${segment.strategyId}\t${segment.side.name.toUpperCase()}\t${segment.regime.toUpperCase()}\t'
      '${r.resolved}\t${(r.winRate * 100).toStringAsFixed(2)}\t'
      '${r.netExpectancyR.toStringAsFixed(3)}\t${r.profitFactor.toStringAsFixed(3)}\t'
      '${r.firstHalfNetExpectancyR.toStringAsFixed(3)}\t'
      '${r.secondHalfNetExpectancyR.toStringAsFixed(3)}\t'
      '${segment.positiveYears}\t'
      '${(segment.rollingPositiveRatio * 100).toStringAsFixed(1)}%\t'
      '${(segment.overlapRatio * 100).toStringAsFixed(1)}%\t'
      '${segment.segmentationGate ? 'SEGMENT_PASS' : 'RESEARCH_CONTINUE'}',
    );
  }

  final passed = segments.where((s) => s.segmentationGate).length;
  stdout.writeln('\nSEGMENT_PASS=$passed/${segments.length}.');
  stdout.writeln(
    'SEGMENT_PASS is research evidence only; it may enter a separate paper-forward experiment, never live BUY/SELL directly.',
  );
}
