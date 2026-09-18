import 'biquote_market_data.dart';
import 'paper_candle.dart';

/// Converts only authoritative CLOSED BiQuote bars into Paper Forward candles.
final class BiQuotePaperCandleAdapter {
  const BiQuotePaperCandleAdapter();

  PaperCandle convert(BiQuoteClosedBar bar) => PaperCandle(
    closeTime: bar.closeTime.toUtc(),
    open: bar.open,
    high: bar.high,
    low: bar.low,
    close: bar.close,
  );

  List<PaperCandle> convertM5(Iterable<BiQuoteClosedBar> bars) {
    final result =
        bars
            .where((bar) => bar.timeframe == BiQuoteTimeframe.m5)
            .map(convert)
            .toList()
          ..sort((a, b) => a.closeTime.compareTo(b.closeTime));
    return result;
  }
}
