import 'protective_stop.dart';

/// Explicit ATR multiplier used to convert volatility into stop-buffer distance.
///
/// No default value is provided. The multiplier is a research/calibration
/// parameter and must not be treated as a proven XAUUSD setting.
final class AtrStopBufferMultiplier {
  AtrStopBufferMultiplier(this.value) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(
        value,
        'value',
        'ATR stop-buffer multiplier must be finite and greater than zero.',
      );
    }
  }

  final double value;
}

/// Converts an already-computed ATR value into the Risk Engine's [StopBuffer].
///
/// Formula:
///   stopBuffer = ATR * multiplier
///
/// ATR calculation remains owned by `technical-analysis`. This policy only
/// converts volatility data into a protective-stop buffer, keeping the
/// dependency between technical analysis and risk planning explicit and small.
final class AtrStopBufferPolicy {
  const AtrStopBufferPolicy();

  StopBuffer create({
    required double atr,
    required AtrStopBufferMultiplier multiplier,
  }) {
    if (!atr.isFinite || atr <= 0) {
      throw ArgumentError.value(
        atr,
        'atr',
        'ATR must be finite and greater than zero.',
      );
    }

    final distance = atr * multiplier.value;
    if (!distance.isFinite || distance <= 0) {
      throw ArgumentError.value(
        distance,
        'distance',
        'Calculated ATR stop-buffer distance must be finite and positive.',
      );
    }

    return StopBuffer(distance);
  }
}
