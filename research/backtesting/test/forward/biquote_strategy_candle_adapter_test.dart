import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/data/mt5_history_adapter.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_live_market_snapshot.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_market_data.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_strategy_candle_adapter.dart';

BiQuoteClosedBar bar(BiQuoteTimeframe timeframe, String openTime) =>
    BiQuoteClosedBar(
      symbol: 'XAUUSD',
      timeframe: timeframe,
      openTime: DateTime.parse(openTime),
      open: 4340,
      high: 4350,
      low: 4330,
      close: 4345,
      tickVolume: 123,
    );

void main() {
  test('maps canonical UTC closed bars into frozen Candle histories', () {
    final snapshot = BiQuoteLiveMarketSnapshot(
      observedAt: DateTime.parse('2026-09-17T12:05:00Z'),
      m5: [bar(BiQuoteTimeframe.m5, '2026-09-17T12:00:00Z')],
      m15: [bar(BiQuoteTimeframe.m15, '2026-09-17T11:45:00Z')],
      h1: [bar(BiQuoteTimeframe.h1, '2026-09-17T11:00:00Z')],
      h4: [bar(BiQuoteTimeframe.h4, '2026-09-17T08:00:00Z')],
    );

    final histories = const BiQuoteStrategyCandleAdapter().snapshot(snapshot);

    expect(
      histories[MarketTimeframe.m5]!.single.closeTime,
      DateTime.parse('2026-09-17T12:05:00Z'),
    );
    expect(
      histories[MarketTimeframe.m15]!.single.closeTime,
      DateTime.parse('2026-09-17T12:00:00Z'),
    );
    expect(
      histories[MarketTimeframe.h1]!.single.closeTime,
      DateTime.parse('2026-09-17T12:00:00Z'),
    );
    expect(
      histories[MarketTimeframe.h4]!.single.closeTime,
      DateTime.parse('2026-09-17T12:00:00Z'),
    );
    expect(histories[MarketTimeframe.m5]!.single.volume, 123);
  });
}
