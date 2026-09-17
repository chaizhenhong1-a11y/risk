import 'dart:io';

import 'package:tradeforge_backtesting/src/dataset/strategy_c_episode_validation.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_robustness_validation.dart';

const _candidates = <StrategyCCandidateDefinition>[
  StrategyCCandidateDefinition(
    id: 'C5',
    h4: 'neutral',
    h1: 'bullish',
    m15: 'bearish',
    sweep: 'resistance',
    expectedBullish: true,
  ),
  StrategyCCandidateDefinition(
    id: 'C6',
    h4: 'bearish',
    h1: 'neutral',
    m15: 'bearish',
    sweep: 'none',
    expectedBullish: false,
  ),
];

void main(List<String> args) {
  final path = args.isEmpty
      ? '.research_cache${Platform.pathSeparator}strategy_c'
            '${Platform.pathSeparator}xauusd_transition_samples.jsonl'
      : args.first;
  final file = File(path);

  if (!file.existsSync()) {
    stderr.writeln('Dataset not found: ${file.path}');
    stderr.writeln('Run Increment 105 first.');
    exitCode = 66;
    return;
  }

  final rows =
      file
          .readAsLinesSync()
          .where((line) => line.trim().isNotEmpty)
          .map(StrategyCEpisodeSample.fromJsonLine)
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));

  const validator = StrategyCRobustnessValidator(windowCount: 5);

  stdout.writeln('TradeForge V2 — Increment 108 C5/C6 Robustness');
  stdout.writeln('Cached rows: ${rows.length}');
  stdout.writeln(
    'Each candidate is deduplicated into independent episodes, then split '
    'chronologically into 5 equal-count windows.',
  );
  stdout.writeln(
    'Success = expected close direction at horizon; not trade win rate.',
  );
  stdout.writeln('');

  for (final candidate in _candidates) {
    final result = validator.validate(rows, candidate);
    stdout.writeln(
      '${candidate.id} expected=${candidate.expectedBullish ? 'BULLISH' : 'BEARISH'}',
    );

    for (final window in result.windows) {
      final s = window.stats;
      String pct(int success, int resolved) => resolved == 0
          ? 'n/a'
          : '${(s.rate(success, resolved) * 100).toStringAsFixed(1)}%';

      stdout.writeln(
        ' W${window.window} '
        '${_date(window.start)}..${_date(window.end)} '
        'episodes=${s.episodes} '
        '12=${pct(s.success12, s.resolved12)} '
        '24=${pct(s.success24, s.resolved24)} '
        '48=${pct(s.success48, s.resolved48)} '
        'MFE=${s.avgMfe.toStringAsFixed(3)} '
        'MAE=${s.avgMae.toStringAsFixed(3)}',
      );
    }

    stdout.writeln(
      ' summary: sized=${result.sufficientlySizedWindows}/${result.windows.length} '
      'directionStable=${result.directionallyStableWindows}/'
      '${result.sufficientlySizedWindows} '
      'MFE>MAE=${result.favorableExcursionWindows}/'
      '${result.sufficientlySizedWindows}',
    );

    // This is intentionally conservative and predeclared. It is a research
    // robustness screen, not production approval.
    final pass =
        result.sufficientlySizedWindows >= 4 &&
        result.directionallyStableWindows >= 3 &&
        result.favorableExcursionWindows >= 3;
    stdout.writeln(' robustness screen: ${pass ? 'PASS' : 'REJECT'}');
    stdout.writeln('');
  }

  stdout.writeln(
    'Research only. A/B remain frozen. C1-C4/C7/C8 remain rejected; '
    'C5/C6 are not production strategies even if this screen passes.',
  );
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
