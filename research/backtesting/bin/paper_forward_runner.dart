import 'dart:io';

import 'package:tradeforge_backtesting/src/forward/paper_candle_csv.dart';
import 'package:tradeforge_backtesting/src/forward/paper_forward_session.dart';

void main(List<String> arguments) {
  if (arguments.isEmpty || arguments.length > 3) {
    stderr.writeln(
      'Usage: dart run bin/paper_forward_runner.dart '
      '<new-m5.csv> [signals.jsonl] [results.jsonl]',
    );
    exitCode = 64;
    return;
  }

  final candles = const PaperCandleCsv().read(File(arguments[0]));
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

  final report = const PaperForwardSession().run(
    signalsFile: signals,
    resultsFile: results,
    newCandles: candles,
  );

  stdout.writeln('TradeForge V2 — Increment 151 Paper Forward Runner');
  stdout.writeln('New M5 candles: ${candles.length}');
  stdout.writeln('Signals: ${report.signals}');
  stdout.writeln('Pending: ${report.pending}');
  stdout.writeln(
    'Resolved: ${report.resolved} '
    '(W=${report.wins} L=${report.losses})',
  );
  stdout.writeln('Ambiguous: ${report.ambiguous}');
  stdout.writeln('Gross R: ${report.grossR.toStringAsFixed(3)}');
  stdout.writeln(
    'Forward expectancy: ${report.expectancyR.toStringAsFixed(3)}R/trade',
  );
  stdout.writeln('');
  stdout.writeln(
    'Paper only. No broker order is sent and no daily signal quota exists.',
  );
}
