import 'package:test/test.dart';

import 'package:tradeforge_backtesting/src/forward/ai_market_context_snapshot.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_live_market_snapshot.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_market_data.dart';

BiQuoteClosedBar _bar(BiQuoteTimeframe timeframe, int i, double close) =>
    BiQuoteClosedBar(
      symbol: 'XAUUSD',
      timeframe: timeframe,
      openTime: DateTime.utc(2026, 9, 18).add(timeframe.duration * i),
      open: close - 1,
      high: close + 2,
      low: close - 2,
      close: close,
      tickVolume: 100 + i,
    );

void main() {
  test('builds deterministic compact context from closed bars only', () {
    List<BiQuoteClosedBar> bars(BiQuoteTimeframe tf) =>
        List.generate(20, (i) => _bar(tf, i, 4300 + i.toDouble()));
    final observedAt = DateTime.utc(2026, 9, 19);
    final snapshot = BiQuoteLiveMarketSnapshot(
      observedAt: observedAt,
      m5: bars(BiQuoteTimeframe.m5),
      m15: bars(BiQuoteTimeframe.m15),
      h1: bars(BiQuoteTimeframe.h1),
      h4: bars(BiQuoteTimeframe.h4),
    );

    final json = AiMarketContextSnapshot.fromLive(snapshot).toJson();
    final frames = json['timeframes'] as Map<String, Map<String, Object?>>;

    expect(frames.keys, containsAll(<String>['M5', 'M15', 'H1', 'H4']));
    expect(frames['M5']?['bars'], 14);
    expect(frames['M5']?['lastClose'], 4319.0);
    expect(json['observedAt'], observedAt.toIso8601String());
  });
}
