import 'dart:io';

import 'package:tradeforge_backtesting/src/dataset/strategy_c_risk_robustness_validation.dart';

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
      .map(C5RiskPath.fromJsonLine)
      .toList();

  const validation = C5RiskRobustnessValidation();

  // Frozen after Increment 114. No further grid expansion in this validation.
  const configs = <C5RiskConfiguration>[
    C5RiskConfiguration(stopDistance: 10, rewardMultiple: 2),
    C5RiskConfiguration(stopDistance: 10, rewardMultiple: 3),
    C5RiskConfiguration(stopDistance: 12.5, rewardMultiple: 2),
    C5RiskConfiguration(stopDistance: 12.5, rewardMultiple: 3),
    C5RiskConfiguration(stopDistance: 15, rewardMultiple: 2),
    C5RiskConfiguration(stopDistance: 15, rewardMultiple: 3),
  ];

  stdout.writeln('TradeForge V2 — Increment 115 C5 Risk Robustness');
  stdout.writeln('Independent C5 paths: ${paths.length}');
  stdout.writeln('Frozen configurations only: SL 10/12.5/15 x TP 2R/3R.');
  stdout.writeln(
    'Window screen: >=4/5 windows positive expectancy and '
    '>=3/5 windows positive-rate >=50%.',
  );
  stdout.writeln('');

  for (final config in configs) {
    final windows = validation.evaluateFiveWindows(paths, config);
    var positiveExpectancyWindows = 0;
    var positiveRateWindows = 0;

    stdout.writeln(config.label);
    for (final w in windows) {
      if (w.expectancy > 0) positiveExpectancyWindows++;
      if (w.positiveRate >= .50) positiveRateWindows++;

      String date(DateTime value) => value.toIso8601String().split('T').first;

      stdout.writeln(
        '  W${w.window} ${date(w.start)}..${date(w.end)} '
        'n=${w.samples} target=${w.target} stop=${w.stop} '
        'expiry=${w.expiry} ambiguous=${w.ambiguous} '
        'positive=${(w.positiveRate * 100).toStringAsFixed(1)}% '
        'expectancy=${w.expectancy.toStringAsFixed(3)}R',
      );
    }

    final pass = positiveExpectancyWindows >= 4 && positiveRateWindows >= 3;
    stdout.writeln(
      '  summary positiveExpectancy=$positiveExpectancyWindows/5 '
      'positiveRate>=50%=$positiveRateWindows/5 '
      'robustness=${pass ? 'PASS' : 'REJECT'}',
    );
    stdout.writeln('');
  }

  stdout.writeln(
    'Research only. This is an internal chronological robustness check, '
    'not independent unseen-data validation. Costs and structural SL/TP '
    'validity are not included.',
  );
}
