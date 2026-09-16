import 'package:market_models/market_models.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  group('SwingDetector', () {
    const detector = SwingDetector();

    test('detects a confirmed swing high with two candles on each side', () {
      final candles = _candles(
        highs: [10, 12, 15, 13, 11],
        lows: [8, 9, 10, 9, 8],
      );

      final swings = detector.detect(candles);

      expect(swings, hasLength(1));
      expect(swings.single.type, SwingType.high);
      expect(swings.single.candleIndex, 2);
      expect(swings.single.price, 15);
    });

    test('detects a confirmed swing low with two candles on each side', () {
      final candles = _candles(
        highs: [15, 14, 13, 14, 15],
        lows: [10, 8, 5, 7, 9],
      );

      final swings = detector.detect(candles);

      expect(swings, hasLength(1));
      expect(swings.single.type, SwingType.low);
      expect(swings.single.candleIndex, 2);
      expect(swings.single.price, 5);
    });

    test('does not confirm a pivot until both right-side candles exist', () {
      final incomplete = _candles(highs: [10, 12, 15, 13], lows: [8, 9, 10, 9]);

      expect(detector.detect(incomplete), isEmpty);

      final confirmed = _candles(
        highs: [10, 12, 15, 13, 11],
        lows: [8, 9, 10, 9, 8],
      );

      expect(
        detector
            .detect(confirmed)
            .any(
              (swing) => swing.type == SwingType.high && swing.candleIndex == 2,
            ),
        isTrue,
      );
    });

    test('requires strict inequality against neighboring highs and lows', () {
      final equalHigh = _candles(
        highs: [10, 15, 15, 13, 11],
        lows: [8, 9, 10, 9, 8],
      );
      final equalLow = _candles(
        highs: [15, 14, 13, 14, 15],
        lows: [10, 5, 5, 7, 9],
      );

      expect(
        detector
            .detect(equalHigh)
            .where(
              (swing) => swing.type == SwingType.high && swing.candleIndex == 2,
            ),
        isEmpty,
      );
      expect(
        detector
            .detect(equalLow)
            .where(
              (swing) => swing.type == SwingType.low && swing.candleIndex == 2,
            ),
        isEmpty,
      );
    });

    test('returns no swings when fewer than five candles are available', () {
      final candles = _candles(highs: [10, 12, 11, 10], lows: [8, 9, 8, 7]);

      expect(detector.detect(candles), isEmpty);
    });
  });
}

List<Candle> _candles({
  required List<double> highs,
  required List<double> lows,
}) {
  assert(highs.length == lows.length);

  return List.generate(highs.length, (index) {
    final high = highs[index];
    final low = lows[index];
    final midpoint = (high + low) / 2;
    final openTime = DateTime.utc(2026, 9, 15).add(Duration(hours: index));

    return Candle(
      openTime: openTime,
      closeTime: openTime.add(const Duration(hours: 1)),
      open: midpoint,
      high: high,
      low: low,
      close: midpoint,
      volume: 100,
    );
  });
}
