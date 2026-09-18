import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_live_market_snapshot.dart';
import 'package:tradeforge_backtesting/src/forward/frozen_live_a_c5_evaluator.dart';

void main() {
  test('empty/incomplete snapshot cannot invent an opportunity', () {
    final at = DateTime.parse('2026-09-17T12:05:00Z');
    final result = FrozenLiveAC5Evaluator().evaluate(
      BiQuoteLiveMarketSnapshot(
        observedAt: at,
        m5: const [],
        m15: const [],
        h1: const [],
        h4: const [],
      ),
    );

    expect(result.observedAt, at);
    expect(result.a, isNull);
    expect(result.c5, isNull);
    expect(result.opportunities, isEmpty);
  });
}
