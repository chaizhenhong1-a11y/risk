import 'dart:io';

import 'package:tradeforge_backtesting/src/dataset/strategy_c_adaptive_risk_validation.dart';

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
      .map(C5AdaptivePath.fromJsonLine)
      .toList();

  const validation = C5AdaptiveRiskValidation();

  stdout.writeln('TradeForge V2 — Increment 116 C5 Adaptive Risk');
  stdout.writeln('Independent C5 paths: ${paths.length}');
  stdout.writeln(
    'Adaptive proxy = C5 episode-start M5 candle range. '
    'This increment does NOT claim it is the final structural SL.',
  );
  stdout.writeln(
    'Screen: >=4/5 windows positive expectancy and '
    '>=3/5 windows positive-rate >=50%.',
  );
  stdout.writeln('');

  for (final config in c5AdaptiveConfigs()) {
    final windows = validation.evaluateFiveWindows(paths, config);
    var positiveExpectancy = 0;
    var positiveRate = 0;

    stdout.writeln(config.label);
    for (final w in windows) {
      if (w.expectancy > 0) positiveExpectancy++;
      if (w.positiveRate >= .50) positiveRate++;

      String date(DateTime value) => value.toIso8601String().split('T').first;

      stdout.writeln(
        '  W${w.window} ${date(w.start)}..${date(w.end)} '
        'n=${w.samples} target=${w.target} stop=${w.stop} '
        'expiry=${w.expiry} ambiguous=${w.ambiguous} '
        'invalidRisk=${w.invalidRisk} '
        'positive=${(w.positiveRate * 100).toStringAsFixed(1)}% '
        'expectancy=${w.expectancy.toStringAsFixed(3)}R',
      );
    }

    final pass = positiveExpectancy >= 4 && positiveRate >= 3;
    stdout.writeln(
      '  summary positiveExpectancy=$positiveExpectancy/5 '
      'positiveRate>=50%=$positiveRate/5 '
      'robustness=${pass ? 'PASS' : 'REJECT'}',
    );
    stdout.writeln('');
  }

  stdout.writeln(
    'Research only. This tests whether a volatility-responsive local '
    'price-range proxy preserves C5 edge. M15 ATR and true structural '
    'invalidation require additional cached context before production use.',
  );
}
