import 'package:market_models/market_models.dart';

import 'key_level.dart';

enum LevelBreakResult { none, wickPierce, confirmedBreak }

/// Baseline deterministic break classification for a closed candle.
///
/// A wick beyond a zone is not enough to confirm a break. Confirmation
/// requires the candle close to finish beyond the relevant outer boundary.
/// Any future close buffer / ATR filter remains explicit and uncalibrated.
final class LevelBreakDetector {
  const LevelBreakDetector();

  LevelBreakResult classify({
    required Candle candle,
    required KeyLevel level,
    double closeBuffer = 0,
  }) {
    if (!closeBuffer.isFinite || closeBuffer < 0) {
      throw ArgumentError.value(
        closeBuffer,
        'closeBuffer',
        'must be finite and non-negative',
      );
    }

    if (!level.isActive) {
      return LevelBreakResult.none;
    }

    return switch (level.type) {
      KeyLevelType.support => _classifySupport(candle, level, closeBuffer),
      KeyLevelType.resistance => _classifyResistance(
        candle,
        level,
        closeBuffer,
      ),
    };
  }

  LevelBreakResult _classifySupport(
    Candle candle,
    KeyLevel level,
    double closeBuffer,
  ) {
    final confirmationPrice = level.lowerBound - closeBuffer;

    if (confirmationPrice < 0) {
      throw ArgumentError(
        'closeBuffer creates an invalid negative support break threshold.',
      );
    }

    if (candle.close < confirmationPrice) {
      return LevelBreakResult.confirmedBreak;
    }

    if (candle.low < level.lowerBound) {
      return LevelBreakResult.wickPierce;
    }

    return LevelBreakResult.none;
  }

  LevelBreakResult _classifyResistance(
    Candle candle,
    KeyLevel level,
    double closeBuffer,
  ) {
    final confirmationPrice = level.upperBound + closeBuffer;

    if (!confirmationPrice.isFinite) {
      throw ArgumentError(
        'closeBuffer creates a non-finite resistance break threshold.',
      );
    }

    if (candle.close > confirmationPrice) {
      return LevelBreakResult.confirmedBreak;
    }

    if (candle.high > level.upperBound) {
      return LevelBreakResult.wickPierce;
    }

    return LevelBreakResult.none;
  }
}
