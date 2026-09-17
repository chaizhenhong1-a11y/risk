import 'dart:io';

import 'package:tradeforge_backtesting/src/dataset/strategy_c_expiry_lifecycle_analysis.dart';

void main(List<String> args) {
  final path = args.isEmpty
      ? '.research_cache${Platform.pathSeparator}strategy_c'
            '${Platform.pathSeparator}xauusd_c5_forward_paths.jsonl'
      : args.first;
  final file = File(path);

  if (!file.existsSync()) {
    stderr.writeln('Dataset not found: ${file.path}');
    exitCode = 66;
    return;
  }

  final paths = file
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .map(C5ExpiryPath.fromJsonLine)
      .toList();

  const analysis = C5ExpiryLifecycleAnalysis();
  const stops = <double>[5, 7.5, 10, 12.5, 15, 20];
  const rewards = <double>[1, 1.5, 2, 3];

  stdout.writeln('TradeForge V2 — Increment 114 C5 Expiry Lifecycle');
  stdout.writeln('Independent C5 paths: ${paths.length}');
  stdout.writeln(
    'Unresolved positions settle at the +48 M5 close. '
    'Same-bar SL+TP remains excluded as ambiguous.',
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
        'target=${r.target} stop=${r.stop} expiry=${r.expiry} '
        'ambiguous=${r.ambiguous} settled=${r.settled} '
        'positive=${(r.settledPositiveRate * 100).toStringAsFixed(1)}% '
        'expectancy=${r.expectancyR.toStringAsFixed(3)}R',
      );
    }
  }

  stdout.writeln('');
  stdout.writeln(
    'Research only. No spread/slippage/commission or structural SL/TP '
    'validity is included; production strategies remain unchanged.',
  );
}
