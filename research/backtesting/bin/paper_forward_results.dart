import 'dart:io';

import 'package:tradeforge_backtesting/src/forward/paper_signal.dart';
import 'package:tradeforge_backtesting/src/forward/paper_trade_result_journal.dart';

void main(List<String> arguments) {
  final path = arguments.isEmpty
      ? '.research_cache${Platform.pathSeparator}paper_forward'
            '${Platform.pathSeparator}results.jsonl'
      : arguments.single;

  final results = const PaperTradeResultJournal().readAll(File(path));
  final resolved = results
      .where(
        (r) =>
            r.status == PaperSignalStatus.targetHit ||
            r.status == PaperSignalStatus.stopHit,
      )
      .toList();
  final wins = resolved
      .where((r) => r.status == PaperSignalStatus.targetHit)
      .length;
  final losses = resolved
      .where((r) => r.status == PaperSignalStatus.stopHit)
      .length;
  final grossR = resolved.fold<double>(
    0,
    (sum, row) => sum + (row.grossR ?? 0),
  );
  final expectancy = resolved.isEmpty ? 0 : grossR / resolved.length;

  stdout.writeln('TradeForge V2 — Increment 149 Paper Forward Results');
  stdout.writeln('Recorded terminal results: ${results.length}');
  stdout.writeln('Resolved: ${resolved.length} | W=$wins L=$losses');
  stdout.writeln('Gross R: ${grossR.toStringAsFixed(3)}');
  stdout.writeln('Expectancy: ${expectancy.toStringAsFixed(3)}R/trade');
  stdout.writeln('Ambiguous outcomes are excluded from resolved expectancy.');
}
