enum KeyLevelType { support, resistance }

enum KeyLevelSource { swingHigh, swingLow }

enum KeyLevelStatus { active, broken, invalidated }

final class KeyLevel {
  KeyLevel({
    required this.type,
    required this.source,
    required this.status,
    required this.lowerBound,
    required this.upperBound,
    required this.createdAtCandleIndex,
  }) {
    if (!lowerBound.isFinite || !upperBound.isFinite) {
      throw ArgumentError('Key level bounds must be finite.');
    }
    if (lowerBound < 0 || upperBound < 0) {
      throw ArgumentError('Key level bounds must be non-negative.');
    }
    if (lowerBound > upperBound) {
      throw ArgumentError('Key level lowerBound must not exceed upperBound.');
    }
    if (createdAtCandleIndex < 0) {
      throw ArgumentError.value(
        createdAtCandleIndex,
        'createdAtCandleIndex',
        'must be non-negative',
      );
    }
    if (!_sourceMatchesType(type, source)) {
      throw ArgumentError(
        'Support must originate from a swing low and resistance '
        'must originate from a swing high.',
      );
    }
  }

  final KeyLevelType type;
  final KeyLevelSource source;
  final KeyLevelStatus status;

  /// Price zone rather than fake single-price precision.
  final double lowerBound;
  final double upperBound;

  /// Index of the confirmed swing candle that originated this level.
  final int createdAtCandleIndex;

  double get midpoint => (lowerBound + upperBound) / 2;

  double get width => upperBound - lowerBound;

  bool contains(double price) {
    if (!price.isFinite || price < 0) {
      throw ArgumentError.value(
        price,
        'price',
        'must be finite and non-negative',
      );
    }
    return price >= lowerBound && price <= upperBound;
  }

  bool get isActive => status == KeyLevelStatus.active;

  static bool _sourceMatchesType(KeyLevelType type, KeyLevelSource source) {
    return switch ((type, source)) {
      (KeyLevelType.support, KeyLevelSource.swingLow) => true,
      (KeyLevelType.resistance, KeyLevelSource.swingHigh) => true,
      _ => false,
    };
  }
}
