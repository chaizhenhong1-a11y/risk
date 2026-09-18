import 'paper_candle.dart';
import 'paper_signal.dart';

final class PaperTradeLifecycleResult {
  const PaperTradeLifecycleResult({
    required this.status,
    required this.resolvedAt,
    required this.grossR,
  });

  final PaperSignalStatus status;
  final DateTime resolvedAt;
  final double? grossR;
}

final class PaperTradeLifecycle {
  const PaperTradeLifecycle();

  PaperTradeLifecycleResult evaluate({
    required PaperSignal signal,
    required Iterable<PaperCandle> candles,
  }) {
    var elapsedClosedM5 = 0;
    for (final candle in candles) {
      if (!candle.closeTime.isAfter(signal.observedAt)) continue;
      elapsedClosedM5++;

      final stopHit = switch (signal.side) {
        PaperSignalSide.buy => candle.low <= signal.stopLoss,
        PaperSignalSide.sell => candle.high >= signal.stopLoss,
      };
      final targetHit = switch (signal.side) {
        PaperSignalSide.buy => candle.high >= signal.takeProfit,
        PaperSignalSide.sell => candle.low <= signal.takeProfit,
      };

      if (stopHit && targetHit) {
        return PaperTradeLifecycleResult(
          status: PaperSignalStatus.ambiguous,
          resolvedAt: candle.closeTime,
          grossR: null,
        );
      }
      if (stopHit) {
        return PaperTradeLifecycleResult(
          status: PaperSignalStatus.stopHit,
          resolvedAt: candle.closeTime,
          grossR: -1,
        );
      }
      if (targetHit) {
        return PaperTradeLifecycleResult(
          status: PaperSignalStatus.targetHit,
          resolvedAt: candle.closeTime,
          grossR: signal.rewardRisk,
        );
      }
      if (elapsedClosedM5 >= 48) {
        return PaperTradeLifecycleResult(
          status: PaperSignalStatus.expired,
          resolvedAt: candle.closeTime,
          grossR: null,
        );
      }
    }

    return PaperTradeLifecycleResult(
      status: signal.status,
      resolvedAt: signal.observedAt,
      grossR: null,
    );
  }
}
