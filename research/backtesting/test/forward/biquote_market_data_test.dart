import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_feed_guard.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_market_data.dart';

void main() {
  test('REST tick keeps explicit health metadata', () {
    final tick = BiQuoteTick.fromJson({
      'symbol': 'XAUUSD',
      'bid': 4353.208,
      'ask': 4353.390,
      'timestamp': '2026-09-17T12:00:47Z',
      'time': '2026.09.17 12:00:47',
      'source': 'MetaTrader 5 (Broker 1)',
      'marketState': 'open',
      'stale': false,
      'quoteAgeSeconds': 0,
    });

    expect(tick.hasRestHealthMetadata, isTrue);
    expect(const BiQuoteTickGuard().evaluate(tick), BiQuoteTickHealth.healthy);
  });

  test('SignalR tick may omit REST-only health metadata', () {
    final tick = BiQuoteTick.fromJson({
      'symbol': 'XAUUSD',
      'bid': 4353.208,
      'ask': 4353.390,
      'timestamp': '2026-09-17T12:00:47Z',
      'time': '2026.09.17 12:00:47',
      'source': 'MetaTrader 5 (Broker 1)',
      'mid': 4353.299,
    });

    expect(tick.hasRestHealthMetadata, isFalse);
    expect(
      const BiQuoteTickGuard().evaluate(tick),
      BiQuoteTickHealth.missingRestHealth,
    );
    expect(
      const BiQuoteTickGuard().evaluateStream(
        tick,
        receivedAtUtc: DateTime.utc(2026, 9, 17, 12, 0, 48),
        restHealthAllowsStreaming: true,
      ),
      BiQuoteTickHealth.healthy,
    );
  });

  test('SignalR tick is blocked when REST health is not healthy', () {
    final tick = BiQuoteTick.fromJson({
      'symbol': 'XAUUSD',
      'bid': 4353.208,
      'ask': 4353.390,
      'timestamp': '2026-09-17T12:00:47Z',
      'time': '2026.09.17 12:00:47',
      'source': 'MetaTrader 5 (Broker 1)',
    });

    expect(
      const BiQuoteTickGuard().evaluateStream(
        tick,
        receivedAtUtc: DateTime.utc(2026, 9, 17, 12, 0, 48),
        restHealthAllowsStreaming: false,
      ),
      BiQuoteTickHealth.stale,
    );
  });

  test('old SignalR timestamp is rejected', () {
    final tick = BiQuoteTick.fromJson({
      'symbol': 'XAUUSD',
      'bid': 4353.208,
      'ask': 4353.390,
      'timestamp': '2026-09-17T12:00:00Z',
      'time': '2026.09.17 12:00:00',
      'source': 'MetaTrader 5 (Broker 1)',
    });

    expect(
      const BiQuoteTickGuard().evaluateStream(
        tick,
        receivedAtUtc: DateTime.utc(2026, 9, 17, 12, 0, 20),
        restHealthAllowsStreaming: true,
      ),
      BiQuoteTickHealth.invalidAge,
    );
  });
}
