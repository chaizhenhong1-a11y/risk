import 'package:market_models/market_models.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  group('BacktestCandleFeed', () {
    test('emits candles in strict chronological order', () {
      final candles = [_candle(0, 2300), _candle(1, 2301), _candle(2, 2302)];
      final feed = BacktestCandleFeed(candles);

      final observations = feed.observations().toList();

      expect(observations, hasLength(3));
      expect(observations[0].index, 0);
      expect(observations[1].index, 1);
      expect(observations[2].index, 2);
      expect(observations[2].currentCandle, same(candles[2]));
    });

    test('history never exposes future candles', () {
      final candles = [_candle(0, 2300), _candle(1, 2301), _candle(2, 2302)];

      final observations = BacktestCandleFeed(candles).observations().toList();

      expect(observations[0].history, [same(candles[0])]);
      expect(observations[1].history, [same(candles[0]), same(candles[1])]);
      expect(observations[0].history, isNot(contains(same(candles[2]))));
    });

    test('observation history is immutable', () {
      final observation = BacktestCandleFeed([
        _candle(0, 2300),
      ]).observations().single;

      expect(
        () => observation.history.add(_candle(1, 2301)),
        throwsUnsupportedError,
      );
    });

    test('rejects duplicate candle open times', () {
      final first = _candle(0, 2300);
      final duplicate = Candle(
        openTime: first.openTime,
        closeTime: first.closeTime,
        open: 2301,
        high: 2302,
        low: 2300,
        close: 2301.5,
        volume: 100,
      );

      expect(() => BacktestCandleFeed([first, duplicate]), throwsArgumentError);
    });

    test('rejects out-of-order candles instead of silently sorting', () {
      expect(
        () => BacktestCandleFeed([_candle(1, 2301), _candle(0, 2300)]),
        throwsArgumentError,
      );
    });

    test('rejects overlapping candle intervals', () {
      final first = _candle(0, 2300);
      final overlapping = Candle(
        openTime: first.openTime.add(const Duration(minutes: 30)),
        closeTime: first.openTime.add(const Duration(hours: 1, minutes: 30)),
        open: 2301,
        high: 2302,
        low: 2300,
        close: 2301.5,
        volume: 100,
      );

      expect(
        () => BacktestCandleFeed([first, overlapping]),
        throwsArgumentError,
      );
    });

    test('empty dataset is valid', () {
      final feed = BacktestCandleFeed(const []);

      expect(feed.isEmpty, isTrue);
      expect(feed.length, 0);
      expect(feed.observations(), isEmpty);
    });
  });
}

Candle _candle(int hourOffset, double price) {
  final openTime = DateTime.utc(2026, 1, 1, hourOffset);

  return Candle(
    openTime: openTime,
    closeTime: openTime.add(const Duration(hours: 1)),
    open: price,
    high: price + 2,
    low: price - 2,
    close: price + 1,
    volume: 100,
  );
}
