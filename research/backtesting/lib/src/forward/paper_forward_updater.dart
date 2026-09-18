import 'dart:io';

import 'paper_candle.dart';
import 'paper_signal.dart';
import 'paper_signal_journal.dart';
import 'paper_trade_lifecycle.dart';
import 'paper_trade_result.dart';
import 'paper_trade_result_journal.dart';

final class PaperForwardUpdateReport {
  const PaperForwardUpdateReport({
    required this.signals,
    required this.alreadyResolved,
    required this.newlyResolved,
    required this.stillPending,
  });

  final int signals;
  final int alreadyResolved;
  final int newlyResolved;
  final int stillPending;
}

final class PaperForwardUpdater {
  const PaperForwardUpdater({
    this.signalJournal = const PaperSignalJournal(),
    this.resultJournal = const PaperTradeResultJournal(),
    this.lifecycle = const PaperTradeLifecycle(),
  });

  final PaperSignalJournal signalJournal;
  final PaperTradeResultJournal resultJournal;
  final PaperTradeLifecycle lifecycle;

  PaperForwardUpdateReport update({
    required File signalsFile,
    required File resultsFile,
    required List<PaperCandle> candles,
  }) {
    final signals = signalJournal.readAll(signalsFile);
    final existing = {
      for (final result in resultJournal.readAll(resultsFile))
        result.signalId: result,
    };

    var alreadyResolved = 0;
    var newlyResolved = 0;
    var stillPending = 0;

    for (final signal in signals) {
      if (existing.containsKey(signal.id)) {
        alreadyResolved++;
        continue;
      }

      final outcome = lifecycle.evaluate(signal: signal, candles: candles);
      if (outcome.status == PaperSignalStatus.pending ||
          outcome.status == PaperSignalStatus.triggered) {
        stillPending++;
        continue;
      }

      final result = PaperTradeResult(
        signalId: signal.id,
        strategy: signal.strategy,
        status: outcome.status,
        resolvedAt: outcome.resolvedAt,
        grossR: outcome.grossR,
      );

      if (resultJournal.appendIfNew(resultsFile, result)) {
        newlyResolved++;
      }
    }

    return PaperForwardUpdateReport(
      signals: signals.length,
      alreadyResolved: alreadyResolved,
      newlyResolved: newlyResolved,
      stillPending: stillPending,
    );
  }
}
