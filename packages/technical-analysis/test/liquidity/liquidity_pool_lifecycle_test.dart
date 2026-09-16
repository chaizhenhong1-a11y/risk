import 'package:market_models/market_models.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const lifecycle = LiquidityPoolLifecycle();

  group('LiquidityPoolLifecycle', () {
    test('equal-high pool becomes swept after raid and reclaim', () {
      final state = LiquidityPoolState(pool: _equalHighs());

      final updated = lifecycle.evaluate(
        state: state,
        candle: _candle(low: 3298, high: 3302, close: 3300.3),
      );

      expect(updated.status, LiquidityPoolStatus.swept);
      expect(identical(updated.pool, state.pool), isTrue);
    });

    test('equal-high pool becomes broken after close above pool', () {
      final state = LiquidityPoolState(pool: _equalHighs());

      final updated = lifecycle.evaluate(
        state: state,
        candle: _candle(low: 3299, high: 3302, close: 3301),
      );

      expect(updated.status, LiquidityPoolStatus.broken);
    });

    test('equal-low pool becomes swept after raid and reclaim', () {
      final state = LiquidityPoolState(pool: _equalLows());

      final updated = lifecycle.evaluate(
        state: state,
        candle: _candle(low: 3248, high: 3252, close: 3249.8),
      );

      expect(updated.status, LiquidityPoolStatus.swept);
    });

    test('equal-low pool becomes broken after close below pool', () {
      final state = LiquidityPoolState(pool: _equalLows());

      final updated = lifecycle.evaluate(
        state: state,
        candle: _candle(low: 3248, high: 3251, close: 3249),
      );

      expect(updated.status, LiquidityPoolStatus.broken);
    });

    test('ordinary interaction leaves pool active', () {
      final state = LiquidityPoolState(pool: _equalHighs());

      final updated = lifecycle.evaluate(
        state: state,
        candle: _candle(low: 3298, high: 3300.4, close: 3300.2),
      );

      expect(identical(updated, state), isTrue);
      expect(updated.status, LiquidityPoolStatus.active);
    });

    test('swept pool is terminal in baseline lifecycle', () {
      final state = LiquidityPoolState(
        pool: _equalHighs(),
        status: LiquidityPoolStatus.swept,
      );

      final updated = lifecycle.evaluate(
        state: state,
        candle: _candle(low: 3299, high: 3305, close: 3304),
      );

      expect(identical(updated, state), isTrue);
      expect(updated.status, LiquidityPoolStatus.swept);
    });

    test('broken pool is terminal in baseline lifecycle', () {
      final state = LiquidityPoolState(
        pool: _equalLows(),
        status: LiquidityPoolStatus.broken,
      );

      final updated = lifecycle.evaluate(
        state: state,
        candle: _candle(low: 3240, high: 3252, close: 3250),
      );

      expect(identical(updated, state), isTrue);
      expect(updated.status, LiquidityPoolStatus.broken);
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
