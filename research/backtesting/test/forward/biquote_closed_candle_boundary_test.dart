import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_closed_candle_boundary.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_market_data.dart';

void main() {
  test('12:05 crosses only M5 boundary', () {
    final boundary = BiQuoteClosedCandleBoundary();

    expect(boundary.observe(DateTime.parse('2026-09-17T12:04:59Z')), isEmpty);
    expect(boundary.observe(DateTime.parse('2026-09-17T12:05:00Z')), {
      BiQuoteTimeframe.m5,
    });
  });

  test('12:15 crosses M5 and M15 boundaries', () {
    final boundary = BiQuoteClosedCandleBoundary();

    boundary.observe(DateTime.parse('2026-09-17T12:14:59Z'));
    expect(boundary.observe(DateTime.parse('2026-09-17T12:15:00Z')), {
      BiQuoteTimeframe.m5,
      BiQuoteTimeframe.m15,
    });
  });

  test('16:00 crosses every configured timeframe', () {
    final boundary = BiQuoteClosedCandleBoundary();

    boundary.observe(DateTime.parse('2026-09-17T15:59:59Z'));
    expect(
      boundary.observe(DateTime.parse('2026-09-17T16:00:00Z')),
      BiQuoteTimeframe.values.toSet(),
    );
  });

  test('same or older tick does not retrigger boundary', () {
    final boundary = BiQuoteClosedCandleBoundary();

    boundary.observe(DateTime.parse('2026-09-17T12:05:00Z'));
    expect(boundary.observe(DateTime.parse('2026-09-17T12:05:00Z')), isEmpty);
    expect(boundary.observe(DateTime.parse('2026-09-17T12:04:59Z')), isEmpty);
  });
}
