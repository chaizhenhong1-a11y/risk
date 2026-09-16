import 'package:signal_engine/signal_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';

/// Historical observation of a signal plan after it has been TRIGGERED.
///
/// TradeForge still does not infer or manage the user's real position. This
/// reports only what later CLOSED M5 candles did relative to the published
/// signal plan's SL and TP.
final class HistoricalTriggeredSignalObservation {
  const HistoricalTriggeredSignalObservation({
    required this.monitoring,
    required this.observationIndex,
  });

  final TriggeredSignalMonitoring monitoring;
  final int observationIndex;

  bool get isTerminal => monitoring.isTerminal;
}

/// Thin historical adapter over the frozen Phase 6 TriggeredSignalMonitor.
///
/// Same-candle SL + TP contact deliberately remains non-terminal/ambiguous:
/// OHLC data does not reveal intrabar ordering, so backtesting must not invent
/// a win or loss.
final class HistoricalTriggeredSignalMonitor {
  const HistoricalTriggeredSignalMonitor({
    this.monitor = const TriggeredSignalMonitor(),
  });

  final TriggeredSignalMonitor monitor;

  HistoricalTriggeredSignalObservation observeClosedM5Candle({
    required TradingBias bias,
    required double stopPrice,
    required double targetPrice,
    required double candleLow,
    required double candleHigh,
    required int observationIndex,
  }) {
    if (observationIndex < 0) {
      throw ArgumentError.value(
        observationIndex,
        'observationIndex',
        'Observation index must be >= 0.',
      );
    }

    return HistoricalTriggeredSignalObservation(
      observationIndex: observationIndex,
      monitoring: monitor.observe(
        bias: bias,
        stopPrice: stopPrice,
        targetPrice: targetPrice,
        candleLow: candleLow,
        candleHigh: candleHigh,
      ),
    );
  }
}
