import 'package:market_models/market_models.dart';

import '../data/mt5_history_adapter.dart';
import 'biquote_live_market_snapshot.dart';
import 'biquote_market_data.dart';

/// Converts canonical-UTC BiQuote CLOSED bars to the frozen research Candle.
///
/// Historical MT5 wall-clock semantics remain untouched; this adapter is only
/// for the realtime BiQuote path.
final class BiQuoteStrategyCandleAdapter {
  const BiQuoteStrategyCandleAdapter();

  Candle convert(BiQuoteClosedBar bar) => Candle(
    openTime: bar.openTime.toUtc(),
    closeTime: bar.closeTime.toUtc(),
    open: bar.open,
    high: bar.high,
    low: bar.low,
    close: bar.close,
    volume: bar.tickVolume.toDouble(),
  );

  List<Candle> convertAll(Iterable<BiQuoteClosedBar> bars) =>
      List<Candle>.unmodifiable(bars.map(convert));

  Map<MarketTimeframe, List<Candle>> snapshot(
    BiQuoteLiveMarketSnapshot source,
  ) => <MarketTimeframe, List<Candle>>{
    MarketTimeframe.m5: convertAll(source.m5),
    MarketTimeframe.m15: convertAll(source.m15),
    MarketTimeframe.h1: convertAll(source.h1),
    MarketTimeframe.h4: convertAll(source.h4),
  };
}
