import 'dart:io';

import 'paper_candle.dart';
import 'paper_forward_coordinator.dart';
import 'paper_opportunity_detector.dart';

/// Strategy boundary for unseen live CLOSED candles.
///
/// This class deliberately knows nothing about BiQuote transport. It receives
/// an anti-lookahead visible prefix and delegates only to frozen detectors.
final class LiveStrategyCycle {
  const LiveStrategyCycle();

  PaperForwardCoordinatorReport run({
    required List<PaperCandle> visibleClosedM5,
    required List<PaperOpportunityDetector> detectors,
    required PaperForwardCoordinator coordinator,
    required File signalsFile,
    required File resultsFile,
  }) {
    if (visibleClosedM5.isEmpty) {
      throw ArgumentError.value(
        visibleClosedM5,
        'visibleClosedM5',
        'At least one closed M5 candle is required',
      );
    }

    return coordinator.run(
      closedCandles: List<PaperCandle>.unmodifiable(visibleClosedM5),
      detectors: detectors,
      signalsFile: signalsFile,
      resultsFile: resultsFile,
    );
  }
}
