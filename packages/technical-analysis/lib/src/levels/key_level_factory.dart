import '../market_structure/swing_point.dart';
import 'key_level.dart';

/// Creates initial support/resistance zones from already-confirmed swings.
///
/// Zone sizing remains explicit at the call site. TradeForge V2 has not yet
/// calibrated an ATR- or volatility-based XAUUSD zone-width policy.
final class KeyLevelFactory {
  const KeyLevelFactory();

  KeyLevel fromSwing(SwingPoint swing, {required double zoneHalfWidth}) {
    if (!zoneHalfWidth.isFinite || zoneHalfWidth < 0) {
      throw ArgumentError.value(
        zoneHalfWidth,
        'zoneHalfWidth',
        'must be finite and non-negative',
      );
    }

    final lowerBound = swing.price - zoneHalfWidth;
    final upperBound = swing.price + zoneHalfWidth;

    if (lowerBound < 0) {
      throw ArgumentError(
        'zoneHalfWidth creates a negative lower price bound.',
      );
    }

    return switch (swing.type) {
      SwingType.high => KeyLevel(
        type: KeyLevelType.resistance,
        source: KeyLevelSource.swingHigh,
        status: KeyLevelStatus.active,
        lowerBound: lowerBound,
        upperBound: upperBound,
        createdAtCandleIndex: swing.candleIndex,
      ),
      SwingType.low => KeyLevel(
        type: KeyLevelType.support,
        source: KeyLevelSource.swingLow,
        status: KeyLevelStatus.active,
        lowerBound: lowerBound,
        upperBound: upperBound,
        createdAtCandleIndex: swing.candleIndex,
      ),
    };
  }

  List<KeyLevel> fromSwings(
    Iterable<SwingPoint> swings, {
    required double zoneHalfWidth,
  }) {
    return List.unmodifiable(
      swings.map((swing) => fromSwing(swing, zoneHalfWidth: zoneHalfWidth)),
    );
  }
}
