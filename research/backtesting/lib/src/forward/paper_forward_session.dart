import 'dart:io';

import 'paper_candle.dart';
import 'paper_forward_updater.dart';
import 'paper_signal_journal.dart';
import 'paper_trade_result_journal.dart';

final class PaperForwardSessionReport {
  const PaperForwardSessionReport({
    required this.signals,
    required this.resolved,
    required this.pending,
    required this.wins,
    required this.losses,
    required this.ambiguous,
    required this.grossR,
    required this.expectancyR,
    required this.update,
  });

  final int signals;
  final int resolved;
  final int pending;
  final int wins;
  final int losses;
  final int ambiguous;
  final double grossR;
  final double expectancyR;
  final PaperForwardUpdateReport update;
}

final class PaperForwardSession {
  const PaperForwardSession({
    this.updater = const PaperForwardUpdater(),
    this.signalJournal = const PaperSignalJournal(),
    this.resultJournal = const PaperTradeResultJournal(),
  });

  final PaperForwardUpdater updater;
  final PaperSignalJournal signalJournal;
  final PaperTradeResultJournal resultJournal;

  PaperForwardSessionReport run({
    required File signalsFile,
    required File resultsFile,
    required List<PaperCandle> newCandles,
  }) {
    final update = updater.update(
      signalsFile: signalsFile,
      resultsFile: resultsFile,
      candles: newCandles,
    );

    final signals = signalJournal.readAll(signalsFile);
    final results = resultJournal.readAll(resultsFile);

    final resolved = results.where((row) => row.grossR != null).toList();
    final wins = resolved.where((row) => row.grossR! > 0).length;
    final losses = resolved.where((row) => row.grossR! < 0).length;
    final ambiguous = results.where((row) => row.grossR == null).length;
    final grossR = resolved.fold<double>(0, (sum, row) => sum + row.grossR!);
    final expectancy = resolved.isEmpty ? 0.0 : grossR / resolved.length;

    return PaperForwardSessionReport(
      signals: signals.length,
      resolved: resolved.length,
      pending: update.stillPending,
      wins: wins,
      losses: losses,
      ambiguous: ambiguous,
      grossR: grossR,
      expectancyR: expectancy,
      update: update,
    );
  }
}
