import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_closed_candle_boundary.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_market_data.dart';

void main() {
  test('M5 boundary is the strategy evaluation clock', () {
    final boundary = BiQuoteClosedCandleBoundary();
    boundary.observe(DateTime.parse('2026-09-17T12:04:59Z'));

    expect(
      boundary.observe(DateTime.parse('2026-09-17T12:05:00Z')),
      contains(BiQuoteTimeframe.m5),
    );
  });
}
