import 'package:market_models/market_models.dart';

import 'swing_point.dart';

/// Detects confirmed pivot swings without look-ahead.
///
/// With the default configuration, a candidate candle must have two candles
/// on both its left and right sides. A swing is therefore only confirmed once
/// the two right-side candles already exist in the supplied closed-candle data.
final class SwingDetector {
  const SwingDetector({this.pivotLeft = 2, this.pivotRight = 2})
    : assert(pivotLeft > 0),
      assert(pivotRight > 0);

  final int pivotLeft;
  final int pivotRight;

  List<SwingPoint> detect(List<Candle> closedCandles) {
    final requiredCount = pivotLeft + pivotRight + 1;
    if (closedCandles.length < requiredCount) {
      return const [];
    }

    final swings = <SwingPoint>[];

    for (
      var index = pivotLeft;
      index < closedCandles.length - pivotRight;
      index++
    ) {
      final candidate = closedCandles[index];

      if (_isSwingHigh(closedCandles, index, candidate.high)) {
        swings.add(
          SwingPoint(
            type: SwingType.high,
            candleIndex: index,
            price: candidate.high,
          ),
        );
      }

      if (_isSwingLow(closedCandles, index, candidate.low)) {
        swings.add(
          SwingPoint(
            type: SwingType.low,
            candleIndex: index,
            price: candidate.low,
          ),
        );
      }
    }

    return List.unmodifiable(swings);
  }

  bool _isSwingHigh(List<Candle> candles, int index, double candidateHigh) {
    for (var offset = 1; offset <= pivotLeft; offset++) {
      if (candidateHigh <= candles[index - offset].high) {
        return false;
      }
    }

    for (var offset = 1; offset <= pivotRight; offset++) {
      if (candidateHigh <= candles[index + offset].high) {
        return false;
      }
    }

    return true;
  }

  bool _isSwingLow(List<Candle> candles, int index, double candidateLow) {
    for (var offset = 1; offset <= pivotLeft; offset++) {
      if (candidateLow >= candles[index - offset].low) {
        return false;
      }
    }

    for (var offset = 1; offset <= pivotRight; offset++) {
      if (candidateLow >= candles[index + offset].low) {
        return false;
      }
    }

    return true;
  }
}
