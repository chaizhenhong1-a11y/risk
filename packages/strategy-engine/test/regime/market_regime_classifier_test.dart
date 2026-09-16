import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const classifier = MarketRegimeClassifier();

  group('MarketRegimeClassifier', () {
    test('classifies aligned bullish H4/H1 as bullish trend', () {
      final result = classifier.classify(
        h4Structure: MarketStructure.bullish,
        h1Structure: MarketStructure.bullish,
      );

      expect(result.regime, MarketRegime.trendAligned);
      expect(result.direction, MarketRegimeDirection.bullish);
    });

    test('classifies aligned bearish H4/H1 as bearish trend', () {
      final result = classifier.classify(
        h4Structure: MarketStructure.bearish,
        h1Structure: MarketStructure.bearish,
      );

      expect(result.regime, MarketRegime.trendAligned);
      expect(result.direction, MarketRegimeDirection.bearish);
    });

    test('classifies bullish H4 and bearish H1 as bullish correction', () {
      final result = classifier.classify(
        h4Structure: MarketStructure.bullish,
        h1Structure: MarketStructure.bearish,
      );

      expect(
        result.regime,
        MarketRegime.higherTimeframeTrendLowerTimeframeCorrection,
      );
      expect(result.direction, MarketRegimeDirection.bullish);
    });

    test('classifies bearish H4 and bullish H1 as bearish correction', () {
      final result = classifier.classify(
        h4Structure: MarketStructure.bearish,
        h1Structure: MarketStructure.bullish,
      );

      expect(
        result.regime,
        MarketRegime.higherTimeframeTrendLowerTimeframeCorrection,
      );
      expect(result.direction, MarketRegimeDirection.bearish);
    });

    test('does not invent range from neutral structure alone', () {
      final result = classifier.classify(
        h4Structure: MarketStructure.neutral,
        h1Structure: MarketStructure.neutral,
      );

      expect(result.regime, MarketRegime.transition);
      expect(result.direction, MarketRegimeDirection.none);
      expect(result.rangeEvidencePresent, isFalse);
    });

    test('classifies neutral context as range only with explicit evidence', () {
      final result = classifier.classify(
        h4Structure: MarketStructure.neutral,
        h1Structure: MarketStructure.neutral,
        rangeEvidencePresent: true,
      );

      expect(result.regime, MarketRegime.range);
      expect(result.direction, MarketRegimeDirection.none);
      expect(result.rangeEvidencePresent, isTrue);
    });

    test('unknown structure has precedence over supplied range evidence', () {
      final result = classifier.classify(
        h4Structure: MarketStructure.unknown,
        h1Structure: MarketStructure.neutral,
        rangeEvidencePresent: true,
      );

      expect(result.regime, MarketRegime.unknown);
      expect(result.direction, MarketRegimeDirection.none);
    });

    test('mixed neutral and directional structure is transition', () {
      final result = classifier.classify(
        h4Structure: MarketStructure.bullish,
        h1Structure: MarketStructure.neutral,
      );

      expect(result.regime, MarketRegime.transition);
      expect(result.direction, MarketRegimeDirection.none);
    });
  });
}
