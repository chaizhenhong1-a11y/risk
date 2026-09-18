import 'dart:io';

import 'paper_candle.dart';
import 'paper_forward_session.dart';
import 'paper_opportunity_detector.dart';
import 'paper_strategy_recorder.dart';

final class PaperForwardCoordinatorReport {
  const PaperForwardCoordinatorReport({
    required this.detected,
    required this.recorded,
    required this.duplicates,
    required this.session,
  });

  final int detected;
  final int recorded;
  final int duplicates;
  final PaperForwardSessionReport session;
}

final class PaperForwardCoordinator {
  const PaperForwardCoordinator({
    this.recorder = const PaperStrategyRecorder(),
    this.session = const PaperForwardSession(),
  });

  final PaperStrategyRecorder recorder;
  final PaperForwardSession session;

  PaperForwardCoordinatorReport run({
    required List<PaperCandle> closedCandles,
    required List<PaperOpportunityDetector> detectors,
    required File signalsFile,
    required File resultsFile,
  }) {
    var detected = 0;
    var recorded = 0;
    var duplicates = 0;

    for (final detector in detectors) {
      for (final opportunity in detector.detect(closedCandles)) {
        if (opportunity.strategy != detector.strategy) {
          throw StateError(
            'Detector ${detector.strategy} emitted '
            '${opportunity.strategy}.',
          );
        }
        detected++;
        final result = recorder.record(signalsFile, opportunity);
        result.wasRecorded ? recorded++ : duplicates++;
      }
    }

    final sessionReport = session.run(
      signalsFile: signalsFile,
      resultsFile: resultsFile,
      newCandles: closedCandles,
    );

    return PaperForwardCoordinatorReport(
      detected: detected,
      recorded: recorded,
      duplicates: duplicates,
      session: sessionReport,
    );
  }
}
