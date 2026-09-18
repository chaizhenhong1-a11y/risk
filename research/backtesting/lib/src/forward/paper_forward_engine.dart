import 'dart:io';

import 'paper_signal.dart';
import 'paper_signal_journal.dart';

final class PaperForwardDecision {
  const PaperForwardDecision({required this.signal, required this.wasRecorded});

  final PaperSignal signal;
  final bool wasRecorded;
}

/// Thin paper-forward boundary.
///
/// Strategy A/C5 discovery remains in their frozen strategy/risk pipelines.
/// This class does not add scoring or quality gates. It only validates the
/// mechanical trade geometry required to record a paper opportunity.
final class PaperForwardEngine {
  const PaperForwardEngine({this.journal = const PaperSignalJournal()});

  final PaperSignalJournal journal;

  PaperForwardDecision record({
    required File journalFile,
    required String symbol,
    required String strategy,
    required PaperSignalSide side,
    required DateTime observedAt,
    required double entry,
    required double stopLoss,
    required double takeProfit,
    required String reason,
    PaperSignalStatus status = PaperSignalStatus.pending,
  }) {
    final risk = side == PaperSignalSide.buy
        ? entry - stopLoss
        : stopLoss - entry;
    final reward = side == PaperSignalSide.buy
        ? takeProfit - entry
        : entry - takeProfit;

    if (risk <= 0 || reward <= 0) {
      throw ArgumentError(
        'Invalid paper geometry: entry=$entry stop=$stopLoss target=$takeProfit',
      );
    }

    final signal = PaperSignal(
      id: PaperSignal.deterministicId(
        symbol: symbol,
        observedAt: observedAt,
        strategy: strategy,
        side: side,
      ),
      symbol: symbol,
      strategy: strategy,
      side: side,
      observedAt: observedAt,
      entry: entry,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      rewardRisk: reward / risk,
      reason: reason,
      status: status,
    );

    return PaperForwardDecision(
      signal: signal,
      wasRecorded: journal.appendIfNew(journalFile, signal),
    );
  }
}
