import 'package:market_models/market_models.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const detector = LevelBreakDetector();

  group('LevelBreakDetector', () {
    test('support wick below zone without close below is only wick pierce', () {
      expect(
        detector.classify(
          candle: _candle(low: 3248, high: 3255, close: 3251),
          level: _support(),
        ),
        LevelBreakResult.wickPierce,
      );
    });

    test('support close below lower boundary confirms break', () {
      expect(
        detector.classify(
          candle: _candle(low: 3247, high: 3253, close: 3249),
          level: _support(),
        ),
        LevelBreakResult.confirmedBreak,
      );
    });

    test(
      'resistance wick above zone without close above is only wick pierce',
      () {
        expect(
          detector.classify(
            candle: _candle(low: 3298, high: 3304, close: 3301),
            level: _resistance(),
          ),
          LevelBreakResult.wickPierce,
        );
      },
    );

    test('resistance close above upper boundary confirms break', () {
      expect(
        detector.classify(
          candle: _candle(low: 3300, high: 3305, close: 3303),
          level: _resistance(),
        ),
        LevelBreakResult.confirmedBreak,
      );
    });

    test('close exactly on outer boundary is not a confirmed break', () {
      expect(
        detector.classify(
          candle: _candle(low: 3249, high: 3254, close: 3250),
          level: _support(),
        ),
        LevelBreakResult.wickPierce,
      );

      expect(
        detector.classify(
          candle: _candle(low: 3299, high: 3303, close: 3302),
          level: _resistance(),
        ),
        LevelBreakResult.wickPierce,
      );
    });

    test('close buffer requires additional distance beyond the zone', () {
      expect(
        detector.classify(
          candle: _candle(low: 3248, high: 3253, close: 3249.5),
          level: _support(),
          closeBuffer: 1,
        ),
        LevelBreakResult.wickPierce,
      );

      expect(
        detector.classify(
          candle: _candle(low: 3247, high: 3253, close: 3248.9),
          level: _support(),
          closeBuffer: 1,
        ),
        LevelBreakResult.confirmedBreak,
      );
    });

    test('inactive level cannot produce a break', () {
      final broken = KeyLevel(
        type: KeyLevelType.support,
        source: KeyLevelSource.swingLow,
        status: KeyLevelStatus.broken,
        lowerBound: 3250,
        upperBound: 3252,
        createdAtCandleIndex: 5,
      );

      expect(
        detector.classify(
          candle: _candle(low: 3240, high: 3255, close: 3245),
          level: broken,
        ),
        LevelBreakResult.none,
      );
    });

    test('rejects invalid close buffer', () {
      expect(
        () => detector.classify(
          candle: _candle(low: 3249, high: 3255, close: 3251),
          level: _support(),
          closeBuffer: -0.1,
        ),
        throwsArgumentError,
      );

      expect(
        () => detector.classify(
          candle: _candle(low: 3249, high: 3255, close: 3251),
          level: _support(),
          closeBuffer: double.nan,
        ),
        throwsArgumentError,
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
  final open = (low + high) / 2;

  return Candle(
    openTime: openTime,
    closeTime: openTime.add(const Duration(minutes: 15)),
    open: open,
    high: high,
    low: low,
    close: close,
    volume: 100,
  );
}
