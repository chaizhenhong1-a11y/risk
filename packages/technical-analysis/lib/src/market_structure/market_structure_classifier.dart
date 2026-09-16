import 'swing_relationship.dart';

/// High-level market structure derived only from confirmed swing relationships.
enum MarketStructure { bullish, bearish, neutral, unknown }

final class MarketStructureClassifier {
  const MarketStructureClassifier();

  MarketStructure classify({
    SwingRelationship? highRelationship,
    SwingRelationship? lowRelationship,
  }) {
    if (highRelationship == null || lowRelationship == null) {
      return MarketStructure.unknown;
    }

    _validateHighRelationship(highRelationship);
    _validateLowRelationship(lowRelationship);

    if (highRelationship == SwingRelationship.higherHigh &&
        lowRelationship == SwingRelationship.higherLow) {
      return MarketStructure.bullish;
    }

    if (highRelationship == SwingRelationship.lowerHigh &&
        lowRelationship == SwingRelationship.lowerLow) {
      return MarketStructure.bearish;
    }

    return MarketStructure.neutral;
  }

  void _validateHighRelationship(SwingRelationship relationship) {
    if (relationship != SwingRelationship.higherHigh &&
        relationship != SwingRelationship.lowerHigh &&
        relationship != SwingRelationship.equalHigh) {
      throw ArgumentError.value(
        relationship,
        'highRelationship',
        'must be HH, LH, or EH',
      );
    }
  }

  void _validateLowRelationship(SwingRelationship relationship) {
    if (relationship != SwingRelationship.higherLow &&
        relationship != SwingRelationship.lowerLow &&
        relationship != SwingRelationship.equalLow) {
      throw ArgumentError.value(
        relationship,
        'lowRelationship',
        'must be HL, LL, or EL',
      );
    }
  }
}
