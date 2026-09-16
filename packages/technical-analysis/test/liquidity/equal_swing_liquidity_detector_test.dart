import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const detector = EqualSwingLiquidityDetector();

  group('EqualSwingLiquidityDetector', () {
    test('detects equal-high liquidity pool', () {
      final pools = detector.detect([
        _high(10, 3300),
        _high(20, 3300.4),
      ], equalityTolerance: 0.5);

      expect(pools, hasLength(1));
      expect(pools.single.type, LiquidityPoolType.equalHighs);
      expect(pools.single.lowerBound, 3300);
      expect(pools.single.upperBound, 3300.4);
      expect(pools.single.swingCandleIndexes, [10, 20]);
      expect(pools.single.swingCount, 2);
    });

    test('detects equal-low liquidity pool', () {
      final pools = detector.detect([
        _low(5, 3250),
        _low(15, 3249.7),
        _low(25, 3250.1),
      ], equalityTolerance: 0.5);

      expect(pools, hasLength(1));
      expect(pools.single.type, LiquidityPoolType.equalLows);
      expect(pools.single.swingCount, 3);
      expect(pools.single.lowerBound, 3249.7);
      expect(pools.single.upperBound, 3250.1);
    });

    test('does not create pool when prices exceed tolerance', () {
      final pools = detector.detect([
        _high(10, 3300),
        _high(20, 3300.6),
      ], equalityTolerance: 0.5);

      expect(pools, isEmpty);
    });

    test('tolerance boundary is inclusive', () {
      final pools = detector.detect([
        _low(10, 3250),
        _low(20, 3250.5),
      ], equalityTolerance: 0.5);

      expect(pools, hasLength(1));
    });

    test('highs and lows never mix into one liquidity pool', () {
      final pools = detector.detect([
        _high(10, 3300),
        _low(15, 3300.1),
        _high(20, 3300.2),
        _low(25, 3300.3),
      ], equalityTolerance: 0.5);

      expect(pools, hasLength(2));
      expect(pools[0].type, LiquidityPoolType.equalHighs);
      expect(pools[1].type, LiquidityPoolType.equalLows);
    });

    test('cluster uses full price span instead of chained drift', () {
      final pools = detector.detect([
        _high(10, 3300),
        _high(20, 3300.4),
        _high(30, 3300.8),
      ], equalityTolerance: 0.5);

      expect(pools, hasLength(1));
      expect(pools.single.swingCandleIndexes, [10, 20]);
    });

    test('rejects invalid equality tolerance', () {
      expect(
        () => detector.detect([
          _high(10, 3300),
          _high(20, 3300),
        ], equalityTolerance: -0.1),
        throwsArgumentError,
      );

      expect(
        () => detector.detect([
          _high(10, 3300),
          _high(20, 3300),
        ], equalityTolerance: double.nan),
        throwsArgumentError,
      );
    });
  });
}

SwingPoint _high(int candleIndex, double price) =>
    SwingPoint(type: SwingType.high, candleIndex: candleIndex, price: price);

SwingPoint _low(int candleIndex, double price) =>
    SwingPoint(type: SwingType.low, candleIndex: candleIndex, price: price);
