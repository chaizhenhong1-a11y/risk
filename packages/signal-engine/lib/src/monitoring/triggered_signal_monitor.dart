import 'package:strategy_engine/strategy_engine.dart';

/// Baseline post-trigger observation for a signal.
///
/// TradeForge does not manage the user's real position. These outcomes describe
/// what happened to the published signal plan after it was triggered.
enum TriggeredSignalOutcome { monitoring, takeProfitReached, stopLossReached }

enum TriggeredSignalMonitoringReason {
  priceBetweenStopAndTarget,
  targetReached,
  stopReached,
  ambiguousSameCandleOutcome,
}

/// Result of observing one closed candle against the signal's SL and TP.
///
/// If a single candle touches both SL and TP, OHLC data cannot prove which was
/// reached first. The baseline therefore stays conservative and reports an
/// ambiguous monitoring result instead of inventing a win or loss.
final class TriggeredSignalMonitoring {
  const TriggeredSignalMonitoring({
    required this.outcome,
    required this.reason,
  });

  final TriggeredSignalOutcome outcome;
  final TriggeredSignalMonitoringReason reason;

  bool get isTerminal =>
      outcome == TriggeredSignalOutcome.takeProfitReached ||
      outcome == TriggeredSignalOutcome.stopLossReached;
}

final class TriggeredSignalMonitor {
  const TriggeredSignalMonitor();

  TriggeredSignalMonitoring observe({
    required TradingBias bias,
    required double stopPrice,
    required double targetPrice,
    required double candleLow,
    required double candleHigh,
  }) {
    _validateFinite(stopPrice, 'stopPrice');
    _validateFinite(targetPrice, 'targetPrice');
    _validateFinite(candleLow, 'candleLow');
    _validateFinite(candleHigh, 'candleHigh');

    if (candleLow > candleHigh) {
      throw ArgumentError('candleLow must be <= candleHigh.');
    }
    if (bias == TradingBias.noTrade) {
      throw ArgumentError('A triggered signal requires BUY or SELL bias.');
    }

    final bool stopTouched;
    final bool targetTouched;

    if (bias == TradingBias.buy) {
      if (stopPrice >= targetPrice) {
        throw ArgumentError('BUY stopPrice must be below targetPrice.');
      }
      stopTouched = candleLow <= stopPrice;
      targetTouched = candleHigh >= targetPrice;
    } else {
      if (targetPrice >= stopPrice) {
        throw ArgumentError('SELL targetPrice must be below stopPrice.');
      }
      stopTouched = candleHigh >= stopPrice;
      targetTouched = candleLow <= targetPrice;
    }

    if (stopTouched && targetTouched) {
      return const TriggeredSignalMonitoring(
        outcome: TriggeredSignalOutcome.monitoring,
        reason: TriggeredSignalMonitoringReason.ambiguousSameCandleOutcome,
      );
    }

    if (targetTouched) {
      return const TriggeredSignalMonitoring(
        outcome: TriggeredSignalOutcome.takeProfitReached,
        reason: TriggeredSignalMonitoringReason.targetReached,
      );
    }

    if (stopTouched) {
      return const TriggeredSignalMonitoring(
        outcome: TriggeredSignalOutcome.stopLossReached,
        reason: TriggeredSignalMonitoringReason.stopReached,
      );
    }

    return const TriggeredSignalMonitoring(
      outcome: TriggeredSignalOutcome.monitoring,
      reason: TriggeredSignalMonitoringReason.priceBetweenStopAndTarget,
    );
  }

  void _validateFinite(double value, String name) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, name, '$name must be finite.');
    }
  }
}
