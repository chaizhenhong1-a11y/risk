import 'dart:io';

import 'package:tradeforge_backtesting/src/dataset/strategy_c_cost_stress_validation.dart';

void main(List<String> args) {
  final cacheDirectory = args.isEmpty
      ? '.research_cache${Platform.pathSeparator}strategy_c'
      : args.first;

  final riskFile = File(
    '$cacheDirectory${Platform.pathSeparator}xauusd_c5_structural_risk.jsonl',
  );
  final pathFile = File(
    '$cacheDirectory${Platform.pathSeparator}xauusd_c5_forward_paths.jsonl',
  );

  if (!riskFile.existsSync() || !pathFile.existsSync()) {
    stderr.writeln('Required C5 cache missing.');
    exitCode = 66;
    return;
  }

  final risks = riskFile
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .map(C5CostRisk.fromJsonLine)
      .toList();
  final paths = pathFile
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .map(C5CostPath.fromJsonLine)
      .toList();

  const validation = C5CostStressValidation();
  final cases = validation.join(risks: risks, paths: paths);

  // Frozen stress ladder. These are price-equivalent round-trip costs, not a
  // claim about any broker's actual current XAUUSD fee schedule.
  const costs = <double>[0, 0.25, 0.50, 1.00, 1.50, 2.00];

  stdout.writeln('TradeForge V2 — Increment 119 C5 Trading Cost Stress');
  stdout.writeln('Structural risk rows: ${risks.length}');
  stdout.writeln('Forward path rows: ${paths.length}');
  stdout.writeln('Joined C5 episodes: ${cases.length}');
  stdout.writeln(
    'Frozen model: structural M15 support - ATR14 x 0.50 SL, TP=2R.',
  );
  stdout.writeln(
    'Cost is round-trip adverse XAUUSD price-equivalent '
    '(spread + slippage + commission).',
  );
  stdout.writeln(
    'Robustness screen remains >=4/5 positive-expectancy windows and '
    '>=3/5 windows with positive net-R rate >=50%.',
  );
  stdout.writeln('');

  for (final cost in costs) {
    final windows = validation.evaluateFiveWindows(
      cases,
      roundTripCostPrice: cost,
    );
    var positiveExpectancy = 0;
    var positiveRate = 0;

    stdout.writeln('RoundTripCost=${cost.toStringAsFixed(2)}');
    for (final w in windows) {
      if (w.expectancy > 0) positiveExpectancy++;
      if (w.positiveRate >= .50) positiveRate++;

      stdout.writeln(
        '  W${w.window} n=${w.samples} '
        'target=${w.target} stop=${w.stop} expiry=${w.expiry} '
        'ambiguous=${w.ambiguous} '
        'positive=${(w.positiveRate * 100).toStringAsFixed(1)}% '
        'expectancy=${w.expectancy.toStringAsFixed(3)}R',
      );
    }

    final overall = validation.overallExpectancy(
      cases,
      roundTripCostPrice: cost,
    );
    final pass = positiveExpectancy >= 4 && positiveRate >= 3;
    stdout.writeln(
      '  overall=${overall.toStringAsFixed(3)}R '
      'positiveExpectancy=$positiveExpectancy/5 '
      'positiveRate>=50%=$positiveRate/5 '
      'robustness=${pass ? 'PASS' : 'REJECT'}',
    );
    stdout.writeln('');
  }

  final breakEven = validation.breakEvenRoundTripCostPrice(cases);
  stdout.writeln(
    'Estimated overall break-even round-trip cost: '
    '${breakEven.toStringAsFixed(3)} XAUUSD price units',
  );

  if (cases.length != 157) {
    stdout.writeln(
      'WARNING: expected 157 joined C5 episodes. Resolve cache mismatch '
      'before interpreting the result.',
    );
  }

  stdout.writeln(
    'Research only. Stress costs are synthetic and broker-agnostic. '
    'Use actual demo/live execution logs for forward validation.',
  );
}
