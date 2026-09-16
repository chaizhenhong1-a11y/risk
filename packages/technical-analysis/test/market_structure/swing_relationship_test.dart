import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const classifier = SwingRelationshipClassifier();

  group('SwingRelationshipClassifier', () {
    test('classifies higher and lower highs', () {
      expect(
        classifier.classify(
          previous: _high(10, 3300),
          current: _high(20, 3310),
          equalityTolerance: 0,
        ),
        SwingRelationship.higherHigh,
      );

      expect(
        classifier.classify(
          previous: _high(10, 3300),
          current: _high(20, 3290),
          equalityTolerance: 0,
        ),
        SwingRelationship.lowerHigh,
      );
    });

    test('classifies higher and lower lows', () {
      expect(
        classifier.classify(
          previous: _low(10, 3250),
          current: _low(20, 3260),
          equalityTolerance: 0,
        ),
        SwingRelationship.higherLow,
      );

      expect(
        classifier.classify(
          previous: _low(10, 3250),
          current: _low(20, 3240),
          equalityTolerance: 0,
        ),
        SwingRelationship.lowerLow,
      );
    });

    test('classifies equal highs and lows using caller-provided tolerance', () {
      expect(
        classifier.classify(
          previous: _high(10, 3300),
          current: _high(20, 3300.40),
          equalityTolerance: 0.50,
        ),
        SwingRelationship.equalHigh,
      );

      expect(
        classifier.classify(
          previous: _low(10, 3250),
          current: _low(20, 3249.60),
          equalityTolerance: 0.50,
        ),
        SwingRelationship.equalLow,
      );
    });

    test('does not hide directional movement outside equality tolerance', () {
      expect(
        classifier.classify(
          previous: _high(10, 3300),
          current: _high(20, 3300.51),
          equalityTolerance: 0.50,
        ),
        SwingRelationship.higherHigh,
      );

      expect(
        classifier.classify(
          previous: _low(10, 3250),
          current: _low(20, 3249.49),
          equalityTolerance: 0.50,
        ),
        SwingRelationship.lowerLow,
      );
    });

    test('rejects comparison between different swing types', () {
      expect(
        () => classifier.classify(
          previous: _high(10, 3300),
          current: _low(20, 3250),
          equalityTolerance: 0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-chronological swing comparisons', () {
      expect(
        () => classifier.classify(
          previous: _high(20, 3300),
          current: _high(10, 3310),
          equalityTolerance: 0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid equality tolerance', () {
      expect(
        () => classifier.classify(
          previous: _high(10, 3300),
          current: _high(20, 3310),
          equalityTolerance: -0.01,
        ),
        throwsArgumentError,
      );

      expect(
        () => classifier.classify(
          previous: _high(10, 3300),
          current: _high(20, 3310),
          equalityTolerance: double.nan,
        ),
        throwsArgumentError,
      );
    });
  });
}

SwingPoint _high(int index, double price) =>
    SwingPoint(type: SwingType.high, candleIndex: index, price: price);

SwingPoint _low(int index, double price) =>
    SwingPoint(type: SwingType.low, candleIndex: index, price: price);
