import 'package:market_models/market_models.dart';
import 'package:test/test.dart';

void main() {
  final openTime = DateTime.utc(2026, 9, 15, 10);
  final closeTime = DateTime.utc(2026, 9, 15, 11);

  group('Candle', () {
    test('stores valid OHLCV market data', () {
      final candle = Candle(
        openTime: openTime,
        closeTime: closeTime,
        open: 3650,
        high: 3660,
        low: 3640,
        close: 3655,
        volume: 1200,
      );

      expect(candle.open, 3650);
      expect(candle.high, 3660);
      expect(candle.low, 3640);
      expect(candle.close, 3655);
      expect(candle.volume, 1200);
      expect(candle.range, 20);
      expect(candle.bodySize, 5);
      expect(candle.isBullish, isTrue);
      expect(candle.isBearish, isFalse);
      expect(candle.isDoji, isFalse);
    });

    test('classifies bearish and doji candles', () {
      final bearish = Candle(
        openTime: openTime,
        closeTime: closeTime,
        open: 3655,
        high: 3660,
        low: 3640,
        close: 3645,
        volume: 100,
      );
      final doji = Candle(
        openTime: openTime,
        closeTime: closeTime,
        open: 3650,
        high: 3660,
        low: 3640,
        close: 3650,
        volume: 100,
      );

      expect(bearish.isBearish, isTrue);
      expect(doji.isDoji, isTrue);
    });

    test('rejects closeTime that is not after openTime', () {
      expect(
        () => Candle(
          openTime: openTime,
          closeTime: openTime,
          open: 3650,
          high: 3660,
          low: 3640,
          close: 3655,
          volume: 100,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid OHLC relationships', () {
      expect(
        () => Candle(
          openTime: openTime,
          closeTime: closeTime,
          open: 3650,
          high: 3640,
          low: 3660,
          close: 3655,
          volume: 100,
        ),
        throwsArgumentError,
      );

      expect(
        () => Candle(
          openTime: openTime,
          closeTime: closeTime,
          open: 3670,
          high: 3660,
          low: 3640,
          close: 3655,
          volume: 100,
        ),
        throwsArgumentError,
      );

      expect(
        () => Candle(
          openTime: openTime,
          closeTime: closeTime,
          open: 3650,
          high: 3660,
          low: 3640,
          close: 3630,
          volume: 100,
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative or non-finite numeric values', () {
      expect(
        () => Candle(
          openTime: openTime,
          closeTime: closeTime,
          open: 3650,
          high: 3660,
          low: 3640,
          close: 3655,
          volume: -1,
        ),
        throwsArgumentError,
      );

      expect(
        () => Candle(
          openTime: openTime,
          closeTime: closeTime,
          open: double.nan,
          high: 3660,
          low: 3640,
          close: 3655,
          volume: 100,
        ),
        throwsArgumentError,
      );
    });
  });
}
