import 'dart:io';

import 'package:tradeforge_backtesting/src/dataset/strategy_c_trigger_discovery.dart';

void main(List<String> args) {
  final path = args.isEmpty
      ? '.research_cache${Platform.pathSeparator}strategy_c'
            '${Platform.pathSeparator}xauusd_c5_trigger_episodes.jsonl'
      : args.first;
  final file = File(path);

  if (!file.existsSync()) {
    stderr.writeln('Dataset not found: ${file.path}');
    stderr.writeln('Run Increment 109 first.');
    exitCode = 66;
    return;
  }

  final episodes = file
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .map(C5TriggerEpisode.fromJsonLine)
      .toList();

  const discovery = C5TriggerDiscovery();
  final results =
      c5TriggerDefinitions()
          .map((definition) => discovery.evaluate(episodes, definition))
          .toList()
        ..sort((a, b) => b.samples.compareTo(a.samples));

  stdout.writeln('TradeForge V2 — Increment 110 C5 Trigger Discovery');
  stdout.writeln('Independent C5 episodes: ${episodes.length}');
  stdout.writeln(
    'All trigger rows are compared against the same frozen C5 baseline.',
  );
  stdout.writeln(
    'Bullish percentages are forward close direction, not trade win rates.',
  );
  stdout.writeln('');

  for (final s in results) {
    String pct(int bullish, int resolved) => resolved == 0
        ? 'n/a'
        : '${(s.rate(bullish, resolved) * 100).toStringAsFixed(1)}%';

    final enough = s.samples >= 30;
    final stable =
        enough &&
        s.rate(s.bullish12, s.resolved12) >= .55 &&
        s.rate(s.bullish24, s.resolved24) >= .55 &&
        s.rate(s.bullish48, s.resolved48) >= .55 &&
        s.avgMfe > s.avgMae;

    stdout.writeln(
      '${s.id}: n=${s.samples} '
      '12=${pct(s.bullish12, s.resolved12)} '
      '24=${pct(s.bullish24, s.resolved24)} '
      '48=${pct(s.bullish48, s.resolved48)} '
      'MFE=${s.avgMfe.toStringAsFixed(3)} '
      'MAE=${s.avgMae.toStringAsFixed(3)} '
      'screen=${stable ? 'CANDIDATE' : 'NO'}',
    );
  }

  stdout.writeln('');
  stdout.writeln(
    'Discovery only. A/B are frozen. C5 remains research-only and no '
    'trigger is promoted to production by this increment.',
  );
}
