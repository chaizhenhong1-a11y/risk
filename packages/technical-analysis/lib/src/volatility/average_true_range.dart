import 'package:market_models/market_models.dart';

/// Deterministic True Range and baseline Average True Range calculations.
///
/// True Range:
/// max(
///   high - low,
///   abs(high - previousClose),
///   abs(low - previousClose),
/// )
///
/// Baseline ATR is the arithmetic mean of the latest [period] True Range
/// values. No trading timeframe, default period, smoothing variant, or stop
/// multiplier is selected here.
final class AverageTrueRange {
  const AverageTrueRange();

  double trueRange({required Candle candle, double? previousClose}) {
    final highLow = candle.high - candle.low;
    if (previousClose == null) return highLow;

    final highPreviousClose = (candle.high - previousClose).abs();
    final lowPreviousClose = (candle.low - previousClose).abs();

    var result = highLow;
    if (highPreviousClose > result) result = highPreviousClose;
    if (lowPreviousClose > result) result = lowPreviousClose;
    return result;
  }

  double calculate({required List<Candle> candles, required int period}) {
    if (period <= 0) {
      throw ArgumentError.value(
        period,
        'period',
        'ATR period must be greater than zero.',
      );
    }

    if (candles.length < period + 1) {
      throw ArgumentError(
        'ATR requires at least period + 1 candles so every averaged '
        'True Range has a real previous close.',
      );
    }

    for (var index = 1; index < candles.length; index++) {
      if (!candles[index].openTime.isAfter(candles[index - 1].openTime)) {
        throw ArgumentError(
          'ATR candles must be in strictly chronological open-time order.',
        );
      }
    }

    final startIndex = candles.length - period;
    var total = 0.0;

    for (var index = startIndex; index < candles.length; index++) {
      total += trueRange(
        candle: candles[index],
        previousClose: candles[index - 1].close,
      );
    }

    return total / period;
  }
}
