import 'package:market_models/market_models.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const atr = AverageTrueRange();

  group('AverageTrueRange.trueRange', () {
    test('uses candle high-low range without previous close', () {
      expect(atr.trueRange(candle: _candle(0, 100, 105, 99, 103)), 6);
    });

    test('captures upside gap versus previous close', () {
      expect(
        atr.trueRange(
          candle: _candle(1, 108, 110, 107, 109),
          previousClose: 103,
        ),
        7,
      );
    });

    test('captures downside gap versus previous close', () {
      expect(
        atr.trueRange(candle: _candle(1, 95, 96, 93, 94), previousClose: 103),
        10,
      );
    });
  });

  group('AverageTrueRange.calculate', () {
    test('averages latest period true ranges', () {
      final candles = [
        _candle(0, 100, 102, 99, 101),
        _candle(1, 103, 105, 102, 104), // TR 4
        _candle(2, 104, 106, 100, 101), // TR 6
        _candle(3, 98, 100, 96, 99), // TR 5
      ];

      expect(atr.calculate(candles: candles, period: 3), 5);
    });

    test('uses only latest requested window', () {
      final candles = [
        _candle(0, 90, 91, 89, 90),
        _candle(1, 100, 110, 99, 105),
        _candle(2, 105, 107, 103, 106), // TR 4
        _candle(3, 106, 109, 105, 108), // TR 4
      ];

      expect(atr.calculate(candles: candles, period: 2), 4);
    });

    test('rejects non-positive period', () {
      final candles = [
        _candle(0, 100, 102, 99, 101),
        _candle(1, 101, 103, 100, 102),
      ];

      expect(
        () => atr.calculate(candles: candles, period: 0),
        throwsArgumentError,
      );
      expect(
        () => atr.calculate(candles: candles, period: -1),
        throwsArgumentError,
      );
    });

    test('requires period plus one candles', () {
      final candles = [
        _candle(0, 100, 102, 99, 101),
        _candle(1, 101, 103, 100, 102),
        _candle(2, 102, 104, 101, 103),
      ];

      expect(
        () => atr.calculate(candles: candles, period: 3),
        throwsArgumentError,
      );
    });

    test('requires strictly chronological candle order', () {
      expect(
        () => atr.calculate(
          candles: [
            _candle(1, 100, 102, 99, 101),
            _candle(0, 101, 103, 100, 102),
          ],
          period: 1,
        ),
        throwsArgumentError,
      );
    });
  });
}

Candle _candle(int hour, double open, double high, double low, double close) {
  final openTime = DateTime.utc(2026, 9, 15, hour);
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
