import 'swing_point.dart';

/// Relationship between two confirmed swings of the same type.
///
/// Equal-high/equal-low classification requires an explicit tolerance.
/// TradeForge V2 intentionally has no global XAUUSD equality tolerance yet,
/// so callers must provide one when they want EH/EL classification.
enum SwingRelationship {
  higherHigh,
  lowerHigh,
  equalHigh,
  higherLow,
  lowerLow,
  equalLow,
}

final class SwingRelationshipClassifier {
  const SwingRelationshipClassifier();

  SwingRelationship classify({
    required SwingPoint previous,
    required SwingPoint current,
    required double equalityTolerance,
  }) {
    if (!equalityTolerance.isFinite || equalityTolerance < 0) {
      throw ArgumentError.value(
        equalityTolerance,
        'equalityTolerance',
        'must be finite and non-negative',
      );
    }

    if (previous.type != current.type) {
      throw ArgumentError(
        'Previous and current swings must have the same SwingType.',
      );
    }

    if (current.candleIndex <= previous.candleIndex) {
      throw ArgumentError('Current swing must occur after the previous swing.');
    }

    final difference = current.price - previous.price;

    if (difference.abs() <= equalityTolerance) {
      return current.type == SwingType.high
          ? SwingRelationship.equalHigh
          : SwingRelationship.equalLow;
    }

    if (current.type == SwingType.high) {
      return difference > 0
          ? SwingRelationship.higherHigh
          : SwingRelationship.lowerHigh;
    }

    return difference > 0
        ? SwingRelationship.higherLow
        : SwingRelationship.lowerLow;
  }
}
