import 'dart:convert';
import 'dart:io';

import 'biquote_live_market_snapshot.dart';
import 'biquote_segment_paper_lifecycle.dart';

final class BiQuotePaperRuntimeSnapshot {
  const BiQuotePaperRuntimeSnapshot({
    required this.closedM5Count,
    required this.lastClosedM5,
    required this.lastPrice,
    required this.segmentCandidates,
    required this.segmentStats,
  });

  final int closedM5Count;
  final DateTime lastClosedM5;
  final double lastPrice;
  final int segmentCandidates;
  final SegmentPaperForwardStats segmentStats;
}

/// Lightweight terminal observability for the unseen paper-forward process.
///
/// This is deliberately read-only: it never changes strategy decisions,
/// checkpoints, entries, SL/TP, or lifecycle outcomes.
final class BiQuotePaperRuntimeObserver {
  BiQuotePaperRuntimeObserver({
    required this.segmentCandidateJournal,
    required this.segmentLifecycle,
    IOSink? output,
  }) : output = output ?? stdout;

  final File segmentCandidateJournal;
  final BiQuoteSegmentPaperLifecycle segmentLifecycle;
  final IOSink output;

  int _closedM5Count = 0;
  int _lastCandidateCount = 0;
  SegmentPaperForwardStats? _lastStats;

  Future<BiQuotePaperRuntimeSnapshot> onClosedM5(
    BiQuoteLiveMarketSnapshot snapshot,
  ) async {
    _closedM5Count++;
    final candidateCount = await _countJsonLines(segmentCandidateJournal);
    final stats = segmentLifecycle.stats;
    final m5 = snapshot.m5.last;

    output.writeln(
      '[LIVE] CLOSED M5 #$_closedM5Count '
      '${m5.closeTime.toUtc().toIso8601String()} '
      'XAUUSD=${m5.close.toStringAsFixed(2)} '
      '| segment candidates=$candidateCount '
      'pending=${stats.pending} W=${stats.wins} L=${stats.losses} '
      'ambiguous=${stats.ambiguous} netR=${stats.netR.toStringAsFixed(2)}',
    );

    if (candidateCount > _lastCandidateCount) {
      output.writeln(
        '[OPPORTUNITY] +${candidateCount - _lastCandidateCount} '
        'new frozen-segment paper candidate(s)',
      );
    }

    final previous = _lastStats;
    if (previous != null) {
      final newWins = stats.wins - previous.wins;
      final newLosses = stats.losses - previous.losses;
      final newAmbiguous = stats.ambiguous - previous.ambiguous;
      if (newWins > 0 || newLosses > 0 || newAmbiguous > 0) {
        output.writeln(
          '[LIFECYCLE] resolved: '
          '+$newWins TP, +$newLosses SL, +$newAmbiguous ambiguous',
        );
      }
    }

    _lastCandidateCount = candidateCount;
    _lastStats = stats;

    return BiQuotePaperRuntimeSnapshot(
      closedM5Count: _closedM5Count,
      lastClosedM5: m5.closeTime.toUtc(),
      lastPrice: m5.close,
      segmentCandidates: candidateCount,
      segmentStats: stats,
    );
  }

  Future<int> _countJsonLines(File file) async {
    if (!file.existsSync()) return 0;
    var count = 0;
    await for (final line
        in file
            .openRead()
            .transform(const SystemEncoding().decoder)
            .transform(const LineSplitter())) {
      if (line.trim().isNotEmpty) count++;
    }
    return count;
  }
}
