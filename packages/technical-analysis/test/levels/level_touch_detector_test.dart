import 'package:market_models/market_models.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const detector = LevelTouchDetector();

  group('LevelTouchDetector', () {
    test('detects candle range intersecting a support zone', () {
      final level = _support(3250, 3252);
      final candle = _candle(low: 3251, high: 3255);

      expect(detector.isTouch(candle: candle, level: level), isTrue);
    });

    test('detects wick-only contact with a resistance zone', () {
      final level = _resistance(3300, 3302);
      final candle = _candle(low: 3295, high: 3300, open: 3297, close: 3298);

      expect(detector.isTouch(candle: candle, level: level), isTrue);
    });

    test('does not detect a candle completely outside the zone', () {
      final level = _support(3250, 3252);

      expect(
        detector.isTouch(
          candle: _candle(low: 3252.01, high: 3255),
          level: level,
        ),
        isFalse,
      );
      expect(
        detector.isTouch(
          candle: _candle(low: 3245, high: 3249.99),
          level: level,
        ),
        isFalse,
      );
    });

    test('zone boundaries count as a touch', () {
      final level = _support(3250, 3252);

      expect(
        detector.isTouch(candle: _candle(low: 3252, high: 3255), level: level),
        isTrue,
      );
      expect(
        detector.isTouch(candle: _candle(low: 3245, high: 3250), level: level),
        isTrue,
      );
    });

    test('inactive levels do not produce touches', () {
      final broken = KeyLevel(
        type: KeyLevelType.support,
        source: KeyLevelSource.swingLow,
        status: KeyLevelStatus.broken,
        lowerBound: 3250,
        upperBound: 3252,
        createdAtCandleIndex: 5,
      );

      expect(
        detector.isTouch(candle: _candle(low: 3251, high: 3255), level: broken),
        isFalse,
      );
    });

    test('detect returns all touching candle indexes from requested start', () {
      final level = _support(3250, 3252);
      final candles = [
        _candle(low: 3240, high: 3245, hour: 0),
        _candle(low: 3251, high: 3255, hour: 1),
        _candle(low: 3253, high: 3256, hour: 2),
        _candle(low: 3249, high: 3250, hour: 3),
      ];

      final touches = detector.detect(
        closedCandles: candles,
        level: level,
        startCandleIndex: 1,
      );

      expect(touches.map((touch) => touch.candleIndex), [1, 3]);
    });

    test('rejects invalid start candle index', () {
      final candles = [_candle(low: 3250, high: 3255)];

      expect(
        () => detector.detect(
          closedCandles: candles,
          level: _support(3250, 3252),
          startCandleIndex: -1,
        ),
        throwsRangeError,
      );

      expect(
        () => detector.detect(
          closedCandles: candles,
          level: _support(3250, 3252),
          startCandleIndex: 2,
        ),
        throwsRangeError,
      );
    });
  });
}

KeyLevel _support(double lower, double upper) => KeyLevel(
  type: KeyLevelType.support,
  source: KeyLevelSource.swingLow,
  status: KeyLevelStatus.active,
  lowerBound: lower,
  upperBound: upper,
  createdAtCandleIndex: 0,
);

KeyLevel _resistance(double lower, double upper) => KeyLevel(
  type: KeyLevelType.resistance,
  source: KeyLevelSource.swingHigh,
  status: KeyLevelStatus.active,
  lowerBound: lower,
  upperBound: upper,
  createdAtCandleIndex: 0,
);

Candle _candle({
  required double low,
  required double high,
  double? open,
  double? close,
  int hour = 0,
}) {
  final midpoint = (low + high) / 2;
  final openTime = DateTime.utc(2026, 9, 15, hour);

  return Candle(
    openTime: openTime,
    closeTime: openTime.add(const Duration(hours: 1)),
    open: open ?? midpoint,
    high: high,
    low: low,
    close: close ?? midpoint,
    volume: 100,
  );
}
