import 'package:market_models/market_models.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const detector = LiquidityPoolSweepDetector();

  group('LiquidityPoolSweepDetector', () {
    test('detects raid above equal highs followed by reclaim', () {
      final sweep = detector.detect(
        candle: _candle(low: 3298, high: 3302, close: 3300.3),
        pool: _equalHighs(),
      );

      expect(sweep, isNotNull);
      expect(sweep!.direction, LiquidityPoolSweepDirection.aboveEqualHighs);
      expect(sweep.extremePrice, 3302);
      expect(sweep.closePrice, 3300.3);
    });

    test('equal-high close exactly at upper bound counts as reclaim', () {
      expect(
        detector.detect(
          candle: _candle(low: 3299, high: 3302, close: 3300.5),
          pool: _equalHighs(),
        ),
        isNotNull,
      );
    });

    test('equal-high raid without reclaim is not a sweep', () {
      expect(
        detector.detect(
          candle: _candle(low: 3299, high: 3302, close: 3301),
          pool: _equalHighs(),
        ),
        isNull,
      );
    });

    test('equal-high boundary touch without raid is not a sweep', () {
      expect(
        detector.detect(
          candle: _candle(low: 3298, high: 3300.5, close: 3300.2),
          pool: _equalHighs(),
        ),
        isNull,
      );
    });

    test('detects raid below equal lows followed by reclaim', () {
      final sweep = detector.detect(
        candle: _candle(low: 3248, high: 3252, close: 3249.8),
        pool: _equalLows(),
      );

      expect(sweep, isNotNull);
      expect(sweep!.direction, LiquidityPoolSweepDirection.belowEqualLows);
      expect(sweep.extremePrice, 3248);
      expect(sweep.closePrice, 3249.8);
    });

    test('equal-low close exactly at lower bound counts as reclaim', () {
      expect(
        detector.detect(
          candle: _candle(low: 3248, high: 3252, close: 3249.5),
          pool: _equalLows(),
        ),
        isNotNull,
      );
    });

    test('equal-low raid without reclaim is not a sweep', () {
      expect(
        detector.detect(
          candle: _candle(low: 3248, high: 3251, close: 3249),
          pool: _equalLows(),
        ),
        isNull,
      );
    });

    test('equal-low boundary touch without raid is not a sweep', () {
      expect(
        detector.detect(
          candle: _candle(low: 3249.5, high: 3252, close: 3250),
          pool: _equalLows(),
        ),
        isNull,
      );
    });
  });
}

LiquidityPool _equalHighs() => const LiquidityPool(
  type: LiquidityPoolType.equalHighs,
  lowerBound: 3300,
  upperBound: 3300.5,
  swingCandleIndexes: [10, 20],
);

LiquidityPool _equalLows() => const LiquidityPool(
  type: LiquidityPoolType.equalLows,
  lowerBound: 3249.5,
  upperBound: 3250,
  swingCandleIndexes: [15, 25],
);

Candle _candle({
  required double low,
  required double high,
  required double close,
}) {
  final openTime = DateTime.utc(2026, 9, 15);
  return Candle(
    openTime: openTime,
    closeTime: openTime.add(const Duration(minutes: 15)),
    open: (low + high) / 2,
    high: high,
    low: low,
    close: close,
    volume: 100,
  );
}
