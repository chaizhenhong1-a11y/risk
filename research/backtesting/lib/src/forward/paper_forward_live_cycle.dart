import 'dart:io';

import 'paper_candle.dart';
import 'paper_forward_checkpoint.dart';
import 'paper_forward_coordinator.dart';
import 'paper_forward_start_policy.dart';
import 'paper_opportunity_detector.dart';

final class PaperForwardLiveCycleReport {
  const PaperForwardLiveCycleReport({
    required this.unseenCandles,
    required this.detected,
    required this.recorded,
    required this.duplicates,
    required this.checkpointAdvanced,
  });

  final int unseenCandles;
  final int detected;
  final int recorded;
  final int duplicates;
  final bool checkpointAdvanced;
}

/// Executes unseen CLOSED candles one-by-one.
///
/// A detector receives history only through the candle currently being
/// evaluated. Future candles are never visible during opportunity discovery.
///
/// When [startStateFile] and [requestedStartAt] are supplied together, the
/// immutable start watermark is enforced before the checkpoint. Historical
/// candles at or before that watermark may provide visible context but can
/// never become newly processed paper-forward observations.
final class PaperForwardLiveCycle {
  const PaperForwardLiveCycle({
    this.coordinator = const PaperForwardCoordinator(),
    this.checkpoint = const PaperForwardCheckpoint(),
    this.startPolicy = const PaperForwardStartPolicy(),
  });

  final PaperForwardCoordinator coordinator;
  final PaperForwardCheckpoint checkpoint;
  final PaperForwardStartPolicy startPolicy;

  PaperForwardLiveCycleReport run({
    required List<PaperCandle> allClosedCandles,
    required List<PaperOpportunityDetector> detectors,
    required File signalsFile,
    required File resultsFile,
    required File checkpointFile,
    File? startStateFile,
    DateTime? requestedStartAt,
  }) {
    if ((startStateFile == null) != (requestedStartAt == null)) {
      throw ArgumentError(
        'startStateFile and requestedStartAt must be supplied together.',
      );
    }
    if (allClosedCandles.isEmpty) {
      return const PaperForwardLiveCycleReport(
        unseenCandles: 0,
        detected: 0,
        recorded: 0,
        duplicates: 0,
        checkpointAdvanced: false,
      );
    }

    final ordered = [...allClosedCandles]
      ..sort((a, b) => a.closeTime.compareTo(b.closeTime));

    final startAt = startStateFile == null
        ? null
        : startPolicy.initialize(startStateFile, requestedStartAt!).startAt;
    final lastSeen = checkpoint.read(checkpointFile);

    final unseenIndexes = <int>[];
    for (var index = 0; index < ordered.length; index++) {
      final time = ordered[index].closeTime;
      if (startAt != null && !time.isAfter(startAt)) continue;
      if (lastSeen != null && !time.isAfter(lastSeen)) continue;
      unseenIndexes.add(index);
    }

    var detected = 0;
    var recorded = 0;
    var duplicates = 0;

    for (final index in unseenIndexes) {
      // Prefix by index rather than rescanning/filtering the entire feed.
      // This preserves anti-lookahead while avoiding the previous repeated
      // full-list where() scan for every unseen candle.
      final visible = ordered.sublist(0, index + 1);
      final report = coordinator.run(
        closedCandles: visible,
        detectors: detectors,
        signalsFile: signalsFile,
        resultsFile: resultsFile,
      );
      detected += report.detected;
      recorded += report.recorded;
      duplicates += report.duplicates;

      // Advance only after detection + journal/lifecycle persistence succeeds.
      checkpoint.write(checkpointFile, ordered[index].closeTime);
    }

    return PaperForwardLiveCycleReport(
      unseenCandles: unseenIndexes.length,
      detected: detected,
      recorded: recorded,
      duplicates: duplicates,
      checkpointAdvanced: unseenIndexes.isNotEmpty,
    );
  }
}
