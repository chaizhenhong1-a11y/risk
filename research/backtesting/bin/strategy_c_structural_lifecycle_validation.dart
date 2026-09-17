import 'dart:io';

import 'package:tradeforge_backtesting/src/dataset/strategy_c_structural_lifecycle_validation.dart';

void main(List<String> args) {
  final cacheDirectory = args.isEmpty
      ? '.research_cache${Platform.pathSeparator}strategy_c'
      : args.first;

  final riskFile = File(
    '$cacheDirectory${Platform.pathSeparator}'
    'xauusd_c5_structural_risk.jsonl',
  );
  final pathFile = File(
    '$cacheDirectory${Platform.pathSeparator}'
    'xauusd_c5_forward_paths.jsonl',
  );

  if (!riskFile.existsSync() || !pathFile.existsSync()) {
    stderr.writeln('Required cache missing.');
    stderr.writeln('Structural risk: ${riskFile.path}');
    stderr.writeln('Forward paths: ${pathFile.path}');
    exitCode = 66;
    return;
  }

  final risks = riskFile
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .map(C5StructuralRisk.fromJsonLine)
      .toList();
  final paths = pathFile
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .map(C5StructuralPath.fromJsonLine)
      .toList();

  const validation = C5StructuralLifecycleValidation();
  final cases = validation.join(risks: risks, paths: paths);

  stdout.writeln(
    'TradeForge V2 — Increment 118 C5 Structural SL Lifecycle Robustness',
  );
  stdout.writeln('Structural risk rows: ${risks.length}');
  stdout.writeln('Forward path rows: ${paths.length}');
  stdout.writeln('Joined C5 episodes: ${cases.length}');
  stdout.writeln(
    'SL = nearest active M15 support lower bound - M15 ATR14 x 0.50.',
  );
  stdout.writeln(
    'Expiry settles at +48 M5 close; same-bar SL+TP is excluded as ambiguous.',
  );
  stdout.writeln(
    'Screen: >=4/5 windows positive expectancy and '
    '>=3/5 windows positive-rate >=50%.',
  );
  stdout.writeln('');

  for (final rewardMultiple in const [2.0, 3.0]) {
    final windows = validation.evaluateFiveWindows(cases, rewardMultiple);
    var positiveExpectancy = 0;
    var positiveRate = 0;

    stdout.writeln('StructuralSL_TP${rewardMultiple.toStringAsFixed(1)}R');
    for (final w in windows) {
      if (w.expectancy > 0) positiveExpectancy++;
      if (w.positiveRate >= .50) positiveRate++;

      String date(DateTime value) => value.toIso8601String().split('T').first;

      stdout.writeln(
        '  W${w.window} ${date(w.start)}..${date(w.end)} '
        'n=${w.samples} target=${w.target} stop=${w.stop} '
        'expiry=${w.expiry} ambiguous=${w.ambiguous} '
        'settled=${w.settled} '
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

  if (cases.length != risks.length || cases.length != paths.length) {
    stdout.writeln(
      'WARNING: cache join is incomplete. Do not interpret lifecycle '
      'results until the timestamp mismatch is resolved.',
    );
  }

  stdout.writeln(
    'Research only. No spread/slippage/commission is included and this '
    'remains internal historical robustness, not unseen-data validation.',
  );
}
