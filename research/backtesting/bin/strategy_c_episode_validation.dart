import 'dart:io';

import 'package:tradeforge_backtesting/src/dataset/strategy_c_episode_validation.dart';

const _candidates = <StrategyCCandidateDefinition>[
  StrategyCCandidateDefinition(
    id: 'C4',
    h4: 'neutral',
    h1: 'neutral',
    m15: 'neutral',
    sweep: 'equalHigh',
    expectedBullish: true,
  ),
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
  StrategyCCandidateDefinition(
    id: 'C7',
    h4: 'neutral',
    h1: 'bearish',
    m15: 'bullish',
    sweep: 'equalHigh',
    expectedBullish: true,
  ),
  StrategyCCandidateDefinition(
    id: 'C8',
    h4: 'bullish',
    h1: 'neutral',
    m15: 'neutral',
    sweep: 'resistance+equalHigh',
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

  const validator = StrategyCEpisodeValidator(discoveryFraction: 0.70);

  stdout.writeln('TradeForge V2 — Increment 107 Episode Validation');
  stdout.writeln('Cached rows: ${rows.length}');
  stdout.writeln(
    'Split: first 70% of each candidate episodes = discovery; '
    'last 30% = holdout.',
  );
  stdout.writeln(
    'Success means expected close direction at horizon, not trade win rate.',
  );
  stdout.writeln('');

  for (final candidate in _candidates) {
    final result = validator.validate(rows, candidate);
    _print(candidate, 'discovery', result.discovery);
    _print(candidate, 'holdout', result.holdout);

    final h = result.holdout;
    final r12 = h.rate(h.success12, h.resolved12);
    final r24 = h.rate(h.success24, h.resolved24);
    final r48 = h.rate(h.success48, h.resolved48);
    final directionStable =
        h.episodes >= 30 && r12 >= .55 && r24 >= .55 && r48 >= .55;
    final excursionPositive = h.excursionCount > 0 && h.avgMfe > h.avgMae;

    stdout.writeln(
      '${candidate.id} holdout screen: '
      '${directionStable && excursionPositive ? 'PASS' : 'REJECT'} '
      '(descriptive research screen only)',
    );
    stdout.writeln('');
  }

  stdout.writeln(
    'C1/C2/C3 remain rejected. C4-C8 are research labels only; '
    'PASS does not create a production Strategy C.',
  );
}

void _print(
  StrategyCCandidateDefinition candidate,
  String split,
  StrategyCEpisodeStats stats,
) {
  String pct(int success, int resolved) => resolved == 0
      ? 'n/a'
      : '${(stats.rate(success, resolved) * 100).toStringAsFixed(1)}%';

  stdout.writeln(
    '${candidate.id} $split '
    'episodes=${stats.episodes} '
    '12=${stats.success12}/${stats.resolved12} '
    '(${pct(stats.success12, stats.resolved12)}) '
    '24=${stats.success24}/${stats.resolved24} '
    '(${pct(stats.success24, stats.resolved24)}) '
    '48=${stats.success48}/${stats.resolved48} '
    '(${pct(stats.success48, stats.resolved48)}) '
    'avgMFE48=${stats.avgMfe.toStringAsFixed(3)} '
    'avgMAE48=${stats.avgMae.toStringAsFixed(3)}',
  );
}
