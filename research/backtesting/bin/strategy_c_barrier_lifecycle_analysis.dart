import 'dart:io';

import 'package:tradeforge_backtesting/src/dataset/strategy_c_barrier_lifecycle_analysis.dart';

void main(List<String> args) {
  final path = args.isEmpty
      ? '.research_cache${Platform.pathSeparator}strategy_c'
            '${Platform.pathSeparator}xauusd_c5_forward_paths.jsonl'
      : args.first;
  final file = File(path);

  if (!file.existsSync()) {
    stderr.writeln('Dataset not found: ${file.path}');
    stderr.writeln('Run Increment 111 first.');
    exitCode = 66;
    return;
  }

  final paths = file
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .map(C5BarrierPath.fromJsonLine)
      .toList();

  const analysis = C5BarrierLifecycleAnalysis();
  const stops = <double>[5, 7.5, 10, 12.5, 15, 20];
  const rewards = <double>[1, 1.5, 2, 3];

  stdout.writeln('TradeForge V2 — Increment 113 C5 Barrier Lifecycle');
  stdout.writeln('Independent C5 paths: ${paths.length}');
  stdout.writeln('Entry = C5 episode-start close; horizon = 48 M5.');
  stdout.writeln(
    'Same-bar SL+TP touches are AMBIGUOUS because OHLC cannot reveal '
    'intrabar ordering.',
  );
  stdout.writeln('');

  for (final stop in stops) {
    stdout.writeln('SL distance=${stop.toStringAsFixed(1)}');
    for (final reward in rewards) {
      final r = analysis.evaluate(
        paths,
        stopDistance: stop,
        rewardMultiple: reward,
      );
      stdout.writeln(
        '  TP=${reward.toStringAsFixed(1)}R '
        'targetFirst=${r.targetFirst} stopFirst=${r.stopFirst} '
        'ambiguous=${r.ambiguousSameBar} unresolved=${r.unresolved} '
        'resolvedWin=${(r.resolvedWinRate * 100).toStringAsFixed(1)}% '
        'resolvedExpectancy=${r.expectancyR.toStringAsFixed(3)}R',
      );
    }
  }

  stdout.writeln('');
  stdout.writeln(
    'Research screen only. Expectancy excludes ambiguous/unresolved cases, '
    'spread, slippage, commission, and structural SL validity. It must not '
    'be interpreted as production profitability.',
  );
}
