import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  group('KeyLevel', () {
    test('creates a valid support zone from a swing low', () {
      final level = KeyLevel(
        type: KeyLevelType.support,
        source: KeyLevelSource.swingLow,
        status: KeyLevelStatus.active,
        lowerBound: 3250,
        upperBound: 3252,
        createdAtCandleIndex: 20,
      );

      expect(level.midpoint, 3251);
      expect(level.width, 2);
      expect(level.contains(3250), isTrue);
      expect(level.contains(3251), isTrue);
      expect(level.contains(3252), isTrue);
      expect(level.contains(3252.01), isFalse);
      expect(level.isActive, isTrue);
    });

    test('creates a valid resistance zone from a swing high', () {
      final level = KeyLevel(
        type: KeyLevelType.resistance,
        source: KeyLevelSource.swingHigh,
        status: KeyLevelStatus.broken,
        lowerBound: 3300,
        upperBound: 3303,
        createdAtCandleIndex: 40,
      );

      expect(level.midpoint, 3301.5);
      expect(level.width, 3);
      expect(level.isActive, isFalse);
    });

    test('rejects inverted bounds', () {
      expect(
        () => KeyLevel(
          type: KeyLevelType.support,
          source: KeyLevelSource.swingLow,
          status: KeyLevelStatus.active,
          lowerBound: 3252,
          upperBound: 3250,
          createdAtCandleIndex: 20,
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative or non-finite bounds', () {
      expect(
        () => KeyLevel(
          type: KeyLevelType.support,
          source: KeyLevelSource.swingLow,
          status: KeyLevelStatus.active,
          lowerBound: -1,
          upperBound: 1,
          createdAtCandleIndex: 20,
        ),
        throwsArgumentError,
      );

      expect(
        () => KeyLevel(
          type: KeyLevelType.resistance,
          source: KeyLevelSource.swingHigh,
          status: KeyLevelStatus.active,
          lowerBound: 3300,
          upperBound: double.infinity,
          createdAtCandleIndex: 20,
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative origin candle index', () {
      expect(
        () => KeyLevel(
          type: KeyLevelType.support,
          source: KeyLevelSource.swingLow,
          status: KeyLevelStatus.active,
          lowerBound: 3250,
          upperBound: 3252,
          createdAtCandleIndex: -1,
        ),
        throwsArgumentError,
      );
    });

    test('rejects source and level type mismatch', () {
      expect(
        () => KeyLevel(
          type: KeyLevelType.support,
          source: KeyLevelSource.swingHigh,
          status: KeyLevelStatus.active,
          lowerBound: 3250,
          upperBound: 3252,
          createdAtCandleIndex: 20,
        ),
        throwsArgumentError,
      );

      expect(
        () => KeyLevel(
          type: KeyLevelType.resistance,
          source: KeyLevelSource.swingLow,
          status: KeyLevelStatus.active,
          lowerBound: 3300,
          upperBound: 3302,
          createdAtCandleIndex: 20,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid prices passed to contains', () {
      final level = KeyLevel(
        type: KeyLevelType.support,
        source: KeyLevelSource.swingLow,
        status: KeyLevelStatus.active,
        lowerBound: 3250,
        upperBound: 3252,
        createdAtCandleIndex: 20,
      );

      expect(() => level.contains(-1), throwsArgumentError);
      expect(() => level.contains(double.nan), throwsArgumentError);
    });
  });
}
