import 'biquote_market_data.dart';

/// In-memory idempotency boundary for live/backfill OHLC ingestion.
///
/// A reconnect/backfill can resend the same closed candle. The strategy layer
/// must see it once only.
final class BiQuoteClosedBarStore {
  final Map<String, BiQuoteClosedBar> _bars = {};

  bool add(BiQuoteClosedBar bar) {
    if (_bars.containsKey(bar.id)) return false;
    _bars[bar.id] = bar;
    return true;
  }

  int addAll(Iterable<BiQuoteClosedBar> bars) {
    var added = 0;
    for (final bar in bars) {
      if (add(bar)) added++;
    }
    return added;
  }

  List<BiQuoteClosedBar> barsFor(BiQuoteTimeframe timeframe) {
    final result =
        _bars.values.where((bar) => bar.timeframe == timeframe).toList()
          ..sort((a, b) => a.openTime.compareTo(b.openTime));
    return result;
  }

  int get length => _bars.length;
}
