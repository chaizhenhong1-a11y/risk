import 'dart:io';

import 'package:tradeforge_backtesting/src/dataset/strategy_c_dataset_feature_analysis.dart';

void main(List<String> args) {
  final path = args.isEmpty
      ? '.research_cache${Platform.pathSeparator}strategy_c'
            '${Platform.pathSeparator}xauusd_transition_samples.jsonl'
      : args.first;
  final file = File(path);

  if (!file.existsSync()) {
    stderr.writeln('Dataset not found: ${file.path}');
    stderr.writeln('Run Increment 105 dataset generation first.');
    exitCode = 66;
    return;
  }

  final rows = file
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .map(StrategyCDatasetRow.fromJsonLine)
      .toList();

  const analyzer = StrategyCDatasetFeatureAnalyzer();
  final groups = analyzer.analyze(rows);

  stdout.writeln('TradeForge V2 — Increment 106 Cached Feature Analysis');
  stdout.writeln('Dataset rows: ${rows.length}');
  stdout.writeln(
    'Showing groups with n >= 100. Percentages are bullish close direction, '
    'not trade win rates.',
  );
  stdout.writeln('');

  for (final g in groups.where((group) => group.samples >= 100)) {
    String pct(int bullish, int resolved) =>
        '${(g.bullishShare(bullish, resolved) * 100).toStringAsFixed(1)}%';

    final p12 = pct(g.bullish12, g.resolved12);
    final p24 = pct(g.bullish24, g.resolved24);
    final p48 = pct(g.bullish48, g.resolved48);

    // Stability is intentionally descriptive only. It flags whether all
    // horizons lean to the same side by at least 55%; it is not a strategy.
    final shares = [
      g.bullishShare(g.bullish12, g.resolved12),
      g.bullishShare(g.bullish24, g.resolved24),
      g.bullishShare(g.bullish48, g.resolved48),
    ];
    final stableBullish = shares.every((value) => value >= 0.55);
    final stableBearish = shares.every((value) => value <= 0.45);
    final flag = stableBullish
        ? 'stable-bullish'
        : stableBearish
        ? 'stable-bearish'
        : 'mixed';

    stdout.writeln(
      'H4=${g.h4} H1=${g.h1} M15=${g.m15} sweep=${g.sweep} '
      'n=${g.samples} '
      'bull12=$p12 bull24=$p24 bull48=$p48 '
      'avgMFE48=${g.avgMfe.toStringAsFixed(3)} '
      'avgMAE48=${g.avgMae.toStringAsFixed(3)} '
      'flag=$flag',
    );
  }

  stdout.writeln('');
  stdout.writeln(
    'Research only. C1/C2/C3 remain rejected. No production Strategy C '
    'rule is created by this analysis.',
  );
}
