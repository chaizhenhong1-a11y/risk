import 'dart:async';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_live_market_snapshot.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_unseen_paper_forward_runner.dart';

void main() {
  test('serial observer never overlaps CLOSED-M5 callbacks', () async {
    var active = 0;
    var maxActive = 0;
    final order = <DateTime>[];

    final observer = SerialBiQuoteClosedM5Observer(
      observer: (snapshot) async {
        active++;
        if (active > maxActive) maxActive = active;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        order.add(snapshot.observedAt);
        active--;
      },
    );

    final first = _snapshot(DateTime.utc(2026, 9, 18, 2, 5));
    final second = _snapshot(DateTime.utc(2026, 9, 18, 2, 10));
    await Future.wait(<Future<void>>[
      observer.add(first),
      observer.add(second),
    ]);

    expect(maxActive, 1);
    expect(order, <DateTime>[first.observedAt, second.observedAt]);
  });

  test('serial observer continues after a failed callback', () async {
    var calls = 0;
    final errors = <Object>[];
    final observer = SerialBiQuoteClosedM5Observer(
      observer: (_) async {
        calls++;
        if (calls == 1) throw StateError('expected');
      },
      onError: (error, _) => errors.add(error),
    );

    await expectLater(
      observer.add(_snapshot(DateTime.utc(2026, 9, 18, 2, 5))),
      throwsStateError,
    );
    await observer.add(_snapshot(DateTime.utc(2026, 9, 18, 2, 10)));

    expect(calls, 2);
    expect(errors, hasLength(1));
  });
}

BiQuoteLiveMarketSnapshot _snapshot(DateTime observedAt) {
  return BiQuoteLiveMarketSnapshot(
    observedAt: observedAt,
    m5: const [],
    m15: const [],
    h1: const [],
    h4: const [],
  );
}
