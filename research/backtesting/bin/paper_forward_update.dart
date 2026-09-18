import 'dart:io';

import 'package:tradeforge_backtesting/src/forward/paper_candle_csv.dart';
import 'package:tradeforge_backtesting/src/forward/paper_forward_updater.dart';

void main(List<String> arguments) {
  if (arguments.isEmpty || arguments.length > 3) {
    stderr.writeln(
      'Usage: dart run bin/paper_forward_update.dart '
      '<new-m5.csv> [signals.jsonl] [results.jsonl]',
    );
    exitCode = 64;
    return;
  }

  final signals = File(
    arguments.length >= 2
        ? arguments[1]
        : '.research_cache${Platform.pathSeparator}paper_forward'
              '${Platform.pathSeparator}signals.jsonl',
  );
  final results = File(
    arguments.length >= 3
        ? arguments[2]
        : '.research_cache${Platform.pathSeparator}paper_forward'
              '${Platform.pathSeparator}results.jsonl',
  );

  final candles = const PaperCandleCsv().read(File(arguments[0]));
  final report = const PaperForwardUpdater().update(
    signalsFile: signals,
    resultsFile: results,
    candles: candles,
  );

  stdout.writeln('TradeForge V2 — Increment 150 Paper Forward Update');
  stdout.writeln('M5 candles loaded: ${candles.length}');
  stdout.writeln('Paper signals: ${report.signals}');
  stdout.writeln('Already resolved: ${report.alreadyResolved}');
  stdout.writeln('Newly resolved: ${report.newlyResolved}');
  stdout.writeln('Still pending: ${report.stillPending}');
  stdout.writeln('');
  stdout.writeln(
    'Only candles after each signal observation are evaluated. '
    'Reruns are idempotent.',
  );
}
