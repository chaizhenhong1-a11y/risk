/// An immutable OHLCV candle used by the TradeForge trading domain.
///
/// [openTime] identifies the start of the candle interval.
/// [closeTime] identifies the end of the candle interval.
/// All prices and volume must be finite and non-negative.
final class Candle {
  Candle({
    required this.openTime,
    required this.closeTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  }) {
    if (!closeTime.isAfter(openTime)) {
      throw ArgumentError.value(
        closeTime,
        'closeTime',
        'must be after openTime',
      );
    }

    final values = <String, double>{
      'open': open,
      'high': high,
      'low': low,
      'close': close,
      'volume': volume,
    };

    for (final entry in values.entries) {
      if (!entry.value.isFinite || entry.value < 0) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'must be finite and non-negative',
        );
      }
    }

    if (high < low) {
      throw ArgumentError.value(
        high,
        'high',
        'must be greater than or equal to low',
      );
    }

    if (open < low || open > high) {
      throw ArgumentError.value(open, 'open', 'must be within [low, high]');
    }

    if (close < low || close > high) {
      throw ArgumentError.value(close, 'close', 'must be within [low, high]');
    }
  }

  final DateTime openTime;
  final DateTime closeTime;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  bool get isBullish => close > open;

  bool get isBearish => close < open;

  bool get isDoji => close == open;

  double get range => high - low;

  double get bodySize => (close - open).abs();
}
