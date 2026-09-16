import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const evaluator = KeyLevelQualityEvidenceEvaluator();

  group('KeyLevelQualityEvidenceEvaluator', () {
    test('missing strength is unavailable and not positive evidence', () {
      final evidence = evaluator.evaluate();

      expect(evidence.quality, KeyLevelQuality.unavailable);
      expect(evidence.present, isFalse);
    });

    test('untested level is unavailable and not positive evidence', () {
      final evidence = evaluator.evaluate(
        levelStrength: LevelStrength.untested,
      );

      expect(evidence.quality, KeyLevelQuality.unavailable);
      expect(evidence.present, isFalse);
    });

    test('weak level preserves weak quality without positive evidence', () {
      final evidence = evaluator.evaluate(levelStrength: LevelStrength.weak);

      expect(evidence.quality, KeyLevelQuality.weak);
      expect(evidence.present, isFalse);
    });

    test('established level is positive quality evidence', () {
      final evidence = evaluator.evaluate(
        levelStrength: LevelStrength.established,
      );

      expect(evidence.quality, KeyLevelQuality.established);
      expect(evidence.present, isTrue);
    });

    test('well-tested level is positive quality evidence', () {
      final evidence = evaluator.evaluate(
        levelStrength: LevelStrength.wellTested,
      );

      expect(evidence.quality, KeyLevelQuality.wellTested);
      expect(evidence.present, isTrue);
    });
  });
}
