import 'biquote_market_data.dart';

/// Detects newly crossed canonical UTC candle boundaries from live ticks.
///
/// It does not build OHLC from ticks. Crossing a boundary is only a signal to
/// refresh authoritative BiQuote REST OHLC and ingest bars where isOpen=false.
final class BiQuoteClosedCandleBoundary {
  DateTime? _lastTickTimestamp;

  Set<BiQuoteTimeframe> observe(DateTime tickTimestamp) {
    final current = tickTimestamp.toUtc();
    final previous = _lastTickTimestamp;
    _lastTickTimestamp = current;

    if (previous == null || !current.isAfter(previous)) {
      return const {};
    }

    final crossed = <BiQuoteTimeframe>{};
    for (final timeframe in BiQuoteTimeframe.values) {
      if (_bucket(previous, timeframe) != _bucket(current, timeframe)) {
        crossed.add(timeframe);
      }
    }
    return crossed;
  }

  DateTime _bucket(DateTime value, BiQuoteTimeframe timeframe) {
    final utc = value.toUtc();
    final seconds = utc.millisecondsSinceEpoch ~/ 1000;
    final width = timeframe.duration.inSeconds;
    return DateTime.fromMillisecondsSinceEpoch(
      (seconds ~/ width) * width * 1000,
      isUtc: true,
    );
  }
}
