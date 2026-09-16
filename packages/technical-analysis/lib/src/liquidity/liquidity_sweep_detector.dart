import 'package:market_models/market_models.dart';

import '../levels/key_level.dart';

enum LiquiditySweepDirection { belowSupport, aboveResistance }

final class LiquiditySweep {
  const LiquiditySweep({
    required this.direction,
    required this.level,
    required this.extremePrice,
    required this.closePrice,
  });

  final LiquiditySweepDirection direction;
  final KeyLevel level;
  final double extremePrice;
  final double closePrice;
}

/// Detects the baseline single-candle liquidity sweep pattern.
///
/// Support:
/// - wick trades below the support zone's lower boundary;
/// - the closed candle reclaims the zone by closing at or above lowerBound.
///
/// Resistance:
/// - wick trades above the resistance zone's upper boundary;
/// - the closed candle reclaims the zone by closing at or below upperBound.
///
/// This intentionally does not classify every wick pierce as a sweep:
/// the candle must close back into or beyond the protected side of the zone.
final class LiquiditySweepDetector {
  const LiquiditySweepDetector();

  LiquiditySweep? detect({required Candle candle, required KeyLevel level}) {
    if (!level.isActive) {
      return null;
    }

    return switch (level.type) {
      KeyLevelType.support => _supportSweep(candle, level),
      KeyLevelType.resistance => _resistanceSweep(candle, level),
    };
  }

  LiquiditySweep? _supportSweep(Candle candle, KeyLevel level) {
    final pierced = candle.low < level.lowerBound;
    final reclaimed = candle.close >= level.lowerBound;

    if (!pierced || !reclaimed) {
      return null;
    }

    return LiquiditySweep(
      direction: LiquiditySweepDirection.belowSupport,
      level: level,
      extremePrice: candle.low,
      closePrice: candle.close,
    );
  }

  LiquiditySweep? _resistanceSweep(Candle candle, KeyLevel level) {
    final pierced = candle.high > level.upperBound;
    final reclaimed = candle.close <= level.upperBound;

    if (!pierced || !reclaimed) {
      return null;
    }

    return LiquiditySweep(
      direction: LiquiditySweepDirection.aboveResistance,
      level: level,
      extremePrice: candle.high,
      closePrice: candle.close,
    );
  }
}
