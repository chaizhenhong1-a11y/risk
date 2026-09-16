import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const factory = KeyLevelFactory();

  group('KeyLevelFactory', () {
    test('creates active resistance from a confirmed swing high', () {
      final level = factory.fromSwing(
        const SwingPoint(type: SwingType.high, candleIndex: 12, price: 3300),
        zoneHalfWidth: 1.5,
      );

      expect(level.type, KeyLevelType.resistance);
      expect(level.source, KeyLevelSource.swingHigh);
      expect(level.status, KeyLevelStatus.active);
      expect(level.lowerBound, 3298.5);
      expect(level.upperBound, 3301.5);
      expect(level.createdAtCandleIndex, 12);
    });

    test('creates active support from a confirmed swing low', () {
      final level = factory.fromSwing(
        const SwingPoint(type: SwingType.low, candleIndex: 20, price: 3250),
        zoneHalfWidth: 2,
      );

      expect(level.type, KeyLevelType.support);
      expect(level.source, KeyLevelSource.swingLow);
      expect(level.status, KeyLevelStatus.active);
      expect(level.lowerBound, 3248);
      expect(level.upperBound, 3252);
      expect(level.createdAtCandleIndex, 20);
    });

    test('zero width creates an exact initial price level', () {
      final level = factory.fromSwing(
        const SwingPoint(type: SwingType.high, candleIndex: 8, price: 3300),
        zoneHalfWidth: 0,
      );

      expect(level.lowerBound, 3300);
      expect(level.upperBound, 3300);
      expect(level.width, 0);
    });

    test('creates levels for multiple confirmed swings in order', () {
      final levels = factory.fromSwings(const [
        SwingPoint(type: SwingType.high, candleIndex: 5, price: 3300),
        SwingPoint(type: SwingType.low, candleIndex: 10, price: 3250),
      ], zoneHalfWidth: 1);

      expect(levels, hasLength(2));
      expect(levels[0].type, KeyLevelType.resistance);
      expect(levels[1].type, KeyLevelType.support);
      expect(levels[0].createdAtCandleIndex, 5);
      expect(levels[1].createdAtCandleIndex, 10);
    });

    test('rejects negative or non-finite zone width', () {
      const swing = SwingPoint(
        type: SwingType.high,
        candleIndex: 5,
        price: 3300,
      );

      expect(
        () => factory.fromSwing(swing, zoneHalfWidth: -0.1),
        throwsArgumentError,
      );
      expect(
        () => factory.fromSwing(swing, zoneHalfWidth: double.nan),
        throwsArgumentError,
      );
      expect(
        () => factory.fromSwing(swing, zoneHalfWidth: double.infinity),
        throwsArgumentError,
      );
    });

    test('rejects a zone that would extend below zero', () {
      expect(
        () => factory.fromSwing(
          const SwingPoint(type: SwingType.low, candleIndex: 5, price: 1),
          zoneHalfWidth: 2,
        ),
        throwsArgumentError,
      );
    });
  });
}
