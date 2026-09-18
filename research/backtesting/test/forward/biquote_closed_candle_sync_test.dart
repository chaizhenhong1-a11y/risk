import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_closed_candle_sync.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_market_data.dart';

BiQuoteTick tick(String timestamp) => BiQuoteTick(
  symbol: 'XAUUSD',
  bid: 4300,
  ask: 4300.2,
  timestamp: DateTime.parse(timestamp),
  nativeTime: DateTime(2026, 9, 17, 12),
  source: 'test',
);

void main() {
  test('refreshes authoritative bars once after crossed boundary', () async {
    final batches = <Set<BiQuoteTimeframe>>[];
    final sync = BiQuoteClosedCandleSync(
      refresh: (timeframes) async => batches.add(timeframes),
    );

    await sync.onTick(tick('2026-09-17T12:04:59Z'));
    await sync.onTick(tick('2026-09-17T12:05:00Z'));
    await sync.onTick(tick('2026-09-17T12:05:00Z'));
    await sync.flush();

    expect(batches, [
      {BiQuoteTimeframe.m5},
    ]);
  });
}
