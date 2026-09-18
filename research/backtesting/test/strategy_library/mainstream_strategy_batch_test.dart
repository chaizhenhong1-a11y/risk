import 'package:market_models/market_models.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/strategy_library/mainstream_strategy_batch.dart';

void main() {
  test(
    'batch evaluates every research strategy without promoting production',
    () {
      final start = DateTime(2026, 1, 1);
      final candles = <Candle>[];
      for (var i = 0; i < 180; i++) {
        final open = 2000 + i * .5;
        candles.add(
          Candle(
            openTime: start.add(Duration(minutes: i * 5)),
            closeTime: start.add(Duration(minutes: (i + 1) * 5)),
            open: open,
            high: open + 1,
            low: open - .5,
            close: open + .7,
            volume: 100,
          ),
        );
      }
      final results = const MainstreamStrategyBatch().run(candles);
      expect(results.length, 34);
      expect(
        results.every((r) => r.strategy.id != 'A' && r.strategy.id != 'C5'),
        isTrue,
      );
    },
  );
  test('historical gate requires sufficient stable positive expectancy', () {
    final start = DateTime(2026, 1, 1);
    final candles = <Candle>[];
    for (var i = 0; i < 70; i++) {
      candles.add(
        Candle(
          openTime: start.add(Duration(minutes: i * 5)),
          closeTime: start.add(Duration(minutes: (i + 1) * 5)),
          open: 2000,
          high: 2001,
          low: 1999,
          close: 2000,
          volume: 1,
        ),
      );
    }
    final results = const MainstreamStrategyBatch().run(candles);
    expect(results.every((r) => !r.historicalGate), isTrue);
  });
}
