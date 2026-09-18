import 'dart:io';

import 'package:tradeforge_backtesting/src/forward/paper_signal_journal.dart';

void main(List<String> arguments) {
  final path = arguments.isEmpty
      ? '.research_cache${Platform.pathSeparator}paper_forward'
            '${Platform.pathSeparator}signals.jsonl'
      : arguments.single;

  if (arguments.length > 1) {
    stderr.writeln(
      'Usage: dart run bin/paper_forward_status.dart [signals.jsonl]',
    );
    exitCode = 64;
    return;
  }

  final signals = const PaperSignalJournal().readAll(File(path));
  final byStrategy = <String, int>{};
  for (final signal in signals) {
    byStrategy[signal.strategy] = (byStrategy[signal.strategy] ?? 0) + 1;
  }

  stdout.writeln('TradeForge V2 — Increment 147 Paper Forward Foundation');
  stdout.writeln('Journal: $path');
  stdout.writeln('Recorded paper opportunities: ${signals.length}');
  for (final entry in byStrategy.entries) {
    stdout.writeln('${entry.key}: ${entry.value}');
  }
  stdout.writeln('');
  stdout.writeln(
    'This is paper-only infrastructure. It does not execute broker orders '
    'and does not add a daily quota or strategy-quality gate.',
  );
}
