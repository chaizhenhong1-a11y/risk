import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_market_data.dart';

void main() {
  test('parses the documented BiQuote timestamp pair', () {
    final tick = BiQuoteTick.fromJson({
      'symbol': 'XAUUSD',
      'bid': 3600.0,
      'ask': 3600.2,
      'timestamp': '2026-09-17T03:10:38Z',
      'time': '2026.09.17 11:10:38',
      'source': 'MetaTrader 5 (Broker 1)',
      'marketState': 'open',
      'stale': false,
      'quoteAgeSeconds': 0,
    });

    expect(tick.timestamp.isUtc, isTrue);
    expect(tick.nativeTime.isUtc, isFalse);
  });
}
