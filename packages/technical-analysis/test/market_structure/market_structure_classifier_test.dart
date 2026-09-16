import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const classifier = MarketStructureClassifier();

  group('MarketStructureClassifier', () {
    test('HH + HL is bullish', () {
      expect(
        classifier.classify(
          highRelationship: SwingRelationship.higherHigh,
          lowRelationship: SwingRelationship.higherLow,
        ),
        MarketStructure.bullish,
      );
    });

    test('LH + LL is bearish', () {
      expect(
        classifier.classify(
          highRelationship: SwingRelationship.lowerHigh,
          lowRelationship: SwingRelationship.lowerLow,
        ),
        MarketStructure.bearish,
      );
    });

    test('other valid relationship combinations are neutral', () {
      final combinations = <(SwingRelationship, SwingRelationship)>[
        (SwingRelationship.higherHigh, SwingRelationship.lowerLow),
        (SwingRelationship.higherHigh, SwingRelationship.equalLow),
        (SwingRelationship.lowerHigh, SwingRelationship.higherLow),
        (SwingRelationship.lowerHigh, SwingRelationship.equalLow),
        (SwingRelationship.equalHigh, SwingRelationship.higherLow),
        (SwingRelationship.equalHigh, SwingRelationship.lowerLow),
        (SwingRelationship.equalHigh, SwingRelationship.equalLow),
      ];

      for (final combination in combinations) {
        expect(
          classifier.classify(
            highRelationship: combination.$1,
            lowRelationship: combination.$2,
          ),
          MarketStructure.neutral,
        );
      }
    });

    test('missing swing relationship data is unknown', () {
      expect(classifier.classify(), MarketStructure.unknown);

      expect(
        classifier.classify(highRelationship: SwingRelationship.higherHigh),
        MarketStructure.unknown,
      );

      expect(
        classifier.classify(lowRelationship: SwingRelationship.higherLow),
        MarketStructure.unknown,
      );
    });

    test('rejects a low relationship passed as the high relationship', () {
      expect(
        () => classifier.classify(
          highRelationship: SwingRelationship.higherLow,
          lowRelationship: SwingRelationship.higherLow,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a high relationship passed as the low relationship', () {
      expect(
        () => classifier.classify(
          highRelationship: SwingRelationship.higherHigh,
          lowRelationship: SwingRelationship.higherHigh,
        ),
        throwsArgumentError,
      );
    });
  });
}
