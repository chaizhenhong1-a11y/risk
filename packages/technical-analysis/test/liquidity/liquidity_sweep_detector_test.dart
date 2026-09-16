import 'package:market_models/market_models.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const detector = LiquiditySweepDetector();

  group('LiquiditySweepDetector', () {
    test('detects sweep below support when candle reclaims zone', () {
      final sweep = detector.detect(
        candle: _candle(low: 3247, high: 3255, close: 3251),
        level: _support(),
      );

      expect(sweep, isNotNull);
      expect(sweep!.direction, LiquiditySweepDirection.belowSupport);
      expect(sweep.extremePrice, 3247);
      expect(sweep.closePrice, 3251);
    });

    test('support close exactly on lower boundary counts as reclaim', () {
      final sweep = detector.detect(
        candle: _candle(low: 3248, high: 3254, close: 3250),
        level: _support(),
      );

      expect(sweep, isNotNull);
      expect(sweep!.direction, LiquiditySweepDirection.belowSupport);
    });

    test('support pierce without reclaim is not a sweep', () {
      expect(
        detector.detect(
          candle: _candle(low: 3247, high: 3252, close: 3249),
          level: _support(),
        ),
        isNull,
      );
    });

    test('detects sweep above resistance when candle reclaims zone', () {
      final sweep = detector.detect(
        candle: _candle(low: 3298, high: 3305, close: 3301),
        level: _resistance(),
      );

      expect(sweep, isNotNull);
      expect(sweep!.direction, LiquiditySweepDirection.aboveResistance);
      expect(sweep.extremePrice, 3305);
      expect(sweep.closePrice, 3301);
    });

    test('resistance close exactly on upper boundary counts as reclaim', () {
      final sweep = detector.detect(
        candle: _candle(low: 3299, high: 3304, close: 3302),
        level: _resistance(),
      );

      expect(sweep, isNotNull);
      expect(sweep!.direction, LiquiditySweepDirection.aboveResistance);
    });

    test('resistance pierce without reclaim is not a sweep', () {
      expect(
        detector.detect(
          candle: _candle(low: 3300, high: 3305, close: 3303),
          level: _resistance(),
        ),
        isNull,
      );
    });

    test('touch without piercing outer boundary is not a sweep', () {
      expect(
        detector.detect(
          candle: _candle(low: 3250, high: 3255, close: 3251),
          level: _support(),
        ),
        isNull,
      );
    });

    test('inactive level cannot produce a liquidity sweep', () {
      final broken = KeyLevel(
        type: KeyLevelType.support,
        source: KeyLevelSource.swingLow,
        status: KeyLevelStatus.broken,
        lowerBound: 3250,
        upperBound: 3252,
        createdAtCandleIndex: 5,
      );

      expect(
        detector.detect(
          candle: _candle(low: 3245, high: 3255, close: 3251),
          level: broken,
        ),
        isNull,
      );
    });
  });
}

KeyLevel _support() => KeyLevel(
  type: KeyLevelType.support,
  source: KeyLevelSource.swingLow,
  status: KeyLevelStatus.active,
  lowerBound: 3250,
  upperBound: 3252,
  createdAtCandleIndex: 5,
);

KeyLevel _resistance() => KeyLevel(
  type: KeyLevelType.resistance,
  source: KeyLevelSource.swingHigh,
  status: KeyLevelStatus.active,
  lowerBound: 3300,
  upperBound: 3302,
  createdAtCandleIndex: 5,
);

Candle _candle({
  required double low,
  required double high,
  required double close,
}) {
  final openTime = DateTime.utc(2026, 9, 15);
  return Candle(
    openTime: openTime,
    closeTime: openTime.add(const Duration(minutes: 15)),
    open: (low + high) / 2,
    high: high,
    low: low,
    close: close,
    volume: 100,
  );
}
