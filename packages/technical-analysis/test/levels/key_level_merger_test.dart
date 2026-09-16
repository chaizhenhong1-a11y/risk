import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const merger = KeyLevelMerger();

  group('KeyLevelMerger', () {
    test('merges overlapping active support zones', () {
      final result = merger.merge([
        _support(10, 3249, 3251),
        _support(20, 3250.5, 3252),
      ], maxGap: 0);

      expect(result, hasLength(1));
      expect(result.single.type, KeyLevelType.support);
      expect(result.single.lowerBound, 3249);
      expect(result.single.upperBound, 3252);
      expect(result.single.createdAtCandleIndex, 10);
    });

    test('merges same-type active zones within max gap', () {
      final result = merger.merge([
        _resistance(10, 3300, 3301),
        _resistance(20, 3301.4, 3302),
      ], maxGap: 0.5);

      expect(result, hasLength(1));
      expect(result.single.lowerBound, 3300);
      expect(result.single.upperBound, 3302);
    });

    test('does not merge zones beyond max gap', () {
      final result = merger.merge([
        _support(10, 3249, 3250),
        _support(20, 3251, 3252),
      ], maxGap: 0.5);

      expect(result, hasLength(2));
    });

    test('does not merge support with resistance', () {
      final result = merger.merge([
        _support(10, 3250, 3252),
        _resistance(20, 3251, 3253),
      ], maxGap: 10);

      expect(result, hasLength(2));
    });

    test('does not merge inactive levels', () {
      final result = merger.merge([
        _support(10, 3250, 3252),
        KeyLevel(
          type: KeyLevelType.support,
          source: KeyLevelSource.swingLow,
          status: KeyLevelStatus.broken,
          lowerBound: 3251,
          upperBound: 3253,
          createdAtCandleIndex: 20,
        ),
      ], maxGap: 10);

      expect(result, hasLength(2));
      expect(
        result.any((level) => level.status == KeyLevelStatus.broken),
        isTrue,
      );
    });

    test('supports chained merging across several nearby zones', () {
      final result = merger.merge([
        _support(10, 3249, 3250),
        _support(20, 3250.4, 3251),
        _support(30, 3251.4, 3252),
      ], maxGap: 0.5);

      expect(result, hasLength(1));
      expect(result.single.lowerBound, 3249);
      expect(result.single.upperBound, 3252);
      expect(result.single.createdAtCandleIndex, 10);
    });

    test('rejects negative or non-finite max gap', () {
      expect(
        () => merger.merge([_support(10, 3250, 3252)], maxGap: -0.1),
        throwsArgumentError,
      );
      expect(
        () => merger.merge([_support(10, 3250, 3252)], maxGap: double.nan),
        throwsArgumentError,
      );
    });
  });
}

KeyLevel _support(int index, double lower, double upper) => KeyLevel(
  type: KeyLevelType.support,
  source: KeyLevelSource.swingLow,
  status: KeyLevelStatus.active,
  lowerBound: lower,
  upperBound: upper,
  createdAtCandleIndex: index,
);

KeyLevel _resistance(int index, double lower, double upper) => KeyLevel(
  type: KeyLevelType.resistance,
  source: KeyLevelSource.swingHigh,
  status: KeyLevelStatus.active,
  lowerBound: lower,
  upperBound: upper,
  createdAtCandleIndex: index,
);
