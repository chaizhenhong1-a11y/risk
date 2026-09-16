import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const lifecycle = KeyLevelLifecycle();

  group('KeyLevelLifecycle', () {
    test('confirmed break transitions active level to broken', () {
      final level = _activeSupport();

      final updated = lifecycle.applyBreakResult(
        level: level,
        breakResult: LevelBreakResult.confirmedBreak,
      );

      expect(updated.status, KeyLevelStatus.broken);
      expect(updated.type, level.type);
      expect(updated.source, level.source);
      expect(updated.lowerBound, level.lowerBound);
      expect(updated.upperBound, level.upperBound);
      expect(updated.createdAtCandleIndex, level.createdAtCandleIndex);
    });

    test('wick pierce leaves active level unchanged', () {
      final level = _activeSupport();

      final updated = lifecycle.applyBreakResult(
        level: level,
        breakResult: LevelBreakResult.wickPierce,
      );

      expect(identical(updated, level), isTrue);
      expect(updated.status, KeyLevelStatus.active);
    });

    test('no break leaves active level unchanged', () {
      final level = _activeSupport();

      final updated = lifecycle.applyBreakResult(
        level: level,
        breakResult: LevelBreakResult.none,
      );

      expect(identical(updated, level), isTrue);
      expect(updated.status, KeyLevelStatus.active);
    });

    test('already broken level remains broken', () {
      final level = KeyLevel(
        type: KeyLevelType.resistance,
        source: KeyLevelSource.swingHigh,
        status: KeyLevelStatus.broken,
        lowerBound: 3300,
        upperBound: 3302,
        createdAtCandleIndex: 8,
      );

      final updated = lifecycle.applyBreakResult(
        level: level,
        breakResult: LevelBreakResult.confirmedBreak,
      );

      expect(identical(updated, level), isTrue);
      expect(updated.status, KeyLevelStatus.broken);
    });

    test('invalidated level is not revived or changed by break result', () {
      final level = KeyLevel(
        type: KeyLevelType.support,
        source: KeyLevelSource.swingLow,
        status: KeyLevelStatus.invalidated,
        lowerBound: 3250,
        upperBound: 3252,
        createdAtCandleIndex: 5,
      );

      final updated = lifecycle.applyBreakResult(
        level: level,
        breakResult: LevelBreakResult.confirmedBreak,
      );

      expect(identical(updated, level), isTrue);
      expect(updated.status, KeyLevelStatus.invalidated);
    });
  });
}

KeyLevel _activeSupport() => KeyLevel(
  type: KeyLevelType.support,
  source: KeyLevelSource.swingLow,
  status: KeyLevelStatus.active,
  lowerBound: 3250,
  upperBound: 3252,
  createdAtCandleIndex: 5,
);
