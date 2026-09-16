import 'package:market_models/market_models.dart';

import 'key_level.dart';

final class LevelTouch {
  const LevelTouch({required this.candleIndex, required this.level});

  final int candleIndex;
  final KeyLevel level;
}

/// Detects whether a closed candle's traded price range intersects an active
/// key-level zone.
///
/// Touch detection intentionally uses the candle high/low range, not only its
/// close. Rejection/confirmation quality is a separate later rule.
final class LevelTouchDetector {
  const LevelTouchDetector();

  bool isTouch({required Candle candle, required KeyLevel level}) {
    if (!level.isActive) {
      return false;
    }

    return candle.high >= level.lowerBound && candle.low <= level.upperBound;
  }

  List<LevelTouch> detect({
    required List<Candle> closedCandles,
    required KeyLevel level,
    int startCandleIndex = 0,
  }) {
    if (startCandleIndex < 0 || startCandleIndex > closedCandles.length) {
      throw RangeError.range(
        startCandleIndex,
        0,
        closedCandles.length,
        'startCandleIndex',
      );
    }

    if (!level.isActive) {
      return const [];
    }

    final touches = <LevelTouch>[];

    for (var index = startCandleIndex; index < closedCandles.length; index++) {
      if (isTouch(candle: closedCandles[index], level: level)) {
        touches.add(LevelTouch(candleIndex: index, level: level));
      }
    }

    return List.unmodifiable(touches);
  }
}
