import 'package:market_models/market_models.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const analyzer = LevelLiquidityAnalyzer();

  group('LevelLiquidityAnalyzer', () {
    test('integrates levels, liquidity pools, and current-candle sweeps', () {
      final result = analyzer.analyze(
        confirmedSwings: [
          _high(10, 3300),
          _low(15, 3250),
          _high(20, 3300.4),
          _low(25, 3249.8),
        ],
        closedCandle: _candle(low: 3298, high: 3302, close: 3300.2),
        zoneHalfWidth: 0.2,
        levelMergeMaxGap: 0.1,
        equalityTolerance: 0.5,
      );

      // The two nearby swing highs merge into one resistance zone and the
      // two nearby swing lows merge into one support zone.
      expect(result.keyLevels, hasLength(2));
      expect(
        result.keyLevels.map((level) => level.type),
        containsAll([KeyLevelType.support, KeyLevelType.resistance]),
      );

      expect(result.liquidityPools, hasLength(2));
      expect(
        result.liquidityPools.map((pool) => pool.type),
        containsAll([
          LiquidityPoolType.equalHighs,
          LiquidityPoolType.equalLows,
        ]),
      );

      expect(result.levelSweeps, isNotEmpty);
      expect(
        result.poolSweeps.any(
          (sweep) =>
              sweep.direction == LiquidityPoolSweepDirection.aboveEqualHighs,
        ),
        isTrue,
      );
    });

    test('merges compatible key levels before exposing snapshot', () {
      final result = analyzer.analyze(
        confirmedSwings: [_low(10, 3250), _low(20, 3250.3)],
        closedCandle: _candle(low: 3260, high: 3265, close: 3262),
        zoneHalfWidth: 0.2,
        levelMergeMaxGap: 0.1,
        equalityTolerance: 0.5,
      );

      expect(result.keyLevels, hasLength(1));
      expect(result.keyLevels.single.type, KeyLevelType.support);
      expect(result.liquidityPools, hasLength(1));
      expect(result.liquidityPools.single.type, LiquidityPoolType.equalLows);
    });

    test('returns empty collections when no swings exist', () {
      final result = analyzer.analyze(
        confirmedSwings: const [],
        closedCandle: _candle(low: 3250, high: 3260, close: 3255),
        zoneHalfWidth: 0.2,
        levelMergeMaxGap: 0.1,
        equalityTolerance: 0.5,
      );

      expect(result.keyLevels, isEmpty);
      expect(result.liquidityPools, isEmpty);
      expect(result.levelSweeps, isEmpty);
      expect(result.poolSweeps, isEmpty);
    });

    test('snapshot collections are unmodifiable', () {
      final result = analyzer.analyze(
        confirmedSwings: [_high(10, 3300)],
        closedCandle: _candle(low: 3290, high: 3295, close: 3293),
        zoneHalfWidth: 0.2,
        levelMergeMaxGap: 0.1,
        equalityTolerance: 0.5,
      );

      expect(
        () => result.keyLevels.add(
          KeyLevel(
            type: KeyLevelType.support,
            source: KeyLevelSource.swingLow,
            status: KeyLevelStatus.active,
            lowerBound: 3200,
            upperBound: 3201,
            createdAtCandleIndex: 1,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('rejects invalid analysis tolerances', () {
      expect(
        () => analyzer.analyze(
          confirmedSwings: const [],
          closedCandle: _candle(low: 3250, high: 3260, close: 3255),
          zoneHalfWidth: -0.1,
          levelMergeMaxGap: 0.1,
          equalityTolerance: 0.5,
        ),
        throwsArgumentError,
      );

      expect(
        () => analyzer.analyze(
          confirmedSwings: const [],
          closedCandle: _candle(low: 3250, high: 3260, close: 3255),
          zoneHalfWidth: 0.1,
          levelMergeMaxGap: double.nan,
          equalityTolerance: 0.5,
        ),
        throwsArgumentError,
      );

      expect(
        () => analyzer.analyze(
          confirmedSwings: const [],
          closedCandle: _candle(low: 3250, high: 3260, close: 3255),
          zoneHalfWidth: 0.1,
          levelMergeMaxGap: 0.1,
          equalityTolerance: double.infinity,
        ),
        throwsArgumentError,
      );
    });
  });
}

SwingPoint _high(int candleIndex, double price) =>
    SwingPoint(type: SwingType.high, candleIndex: candleIndex, price: price);

SwingPoint _low(int candleIndex, double price) =>
    SwingPoint(type: SwingType.low, candleIndex: candleIndex, price: price);

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
