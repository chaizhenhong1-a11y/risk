import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_closed_bar_store.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_live_market_snapshot.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_market_data.dart';

BiQuoteClosedBar bar(BiQuoteTimeframe timeframe, String openTime) =>
    BiQuoteClosedBar(
      symbol: 'XAUUSD',
      timeframe: timeframe,
      openTime: DateTime.parse(openTime),
      open: 1,
      high: 2,
      low: 0.5,
      close: 1.5,
      tickVolume: 1,
    );

void main() {
  test('snapshot never exposes bars closing after observation time', () {
    final store = BiQuoteClosedBarStore()
      ..add(bar(BiQuoteTimeframe.m5, '2026-09-17T12:00:00Z'))
      ..add(bar(BiQuoteTimeframe.m5, '2026-09-17T12:05:00Z'))
      ..add(bar(BiQuoteTimeframe.m15, '2026-09-17T11:45:00Z'))
      ..add(bar(BiQuoteTimeframe.h1, '2026-09-17T11:00:00Z'))
      ..add(bar(BiQuoteTimeframe.h4, '2026-09-17T08:00:00Z'));

    final snapshot = BiQuoteLiveMarketSnapshot.fromStore(
      store,
      observedAt: DateTime.parse('2026-09-17T12:05:00Z'),
    );

    expect(snapshot.m5.length, 1);
    expect(
      snapshot.m5.single.closeTime,
      DateTime.parse('2026-09-17T12:05:00Z'),
    );
    expect(snapshot.hasMinimumTimeframes, isTrue);
  });
}
