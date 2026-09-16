import 'package:market_models/market_models.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  group('MultiTimeframeBacktestFeed', () {
    test('uses M5 candle closes as the historical observation clock', () {
      final feed = MultiTimeframeBacktestFeed(
        m5Candles: [
          _candle(10, 30, const Duration(minutes: 5)),
          _candle(10, 35, const Duration(minutes: 5)),
        ],
        m15Candles: const [],
        h1Candles: const [],
        h4Candles: const [],
      );

      final observations = feed.observations().toList();

      expect(observations, hasLength(2));
      expect(observations[0].observationTime, DateTime.utc(2026, 1, 5, 10, 35));
      expect(observations[1].observationTime, DateTime.utc(2026, 1, 5, 10, 40));
    });

    test('does not expose an H1 candle before that candle has closed', () {
      final h1 = _candle(10, 0, const Duration(hours: 1));
      final feed = MultiTimeframeBacktestFeed(
        m5Candles: [
          _candle(10, 30, const Duration(minutes: 5)),
          _candle(10, 55, const Duration(minutes: 5)),
        ],
        m15Candles: const [],
        h1Candles: [h1],
        h4Candles: const [],
      );

      final observations = feed.observations().toList();

      expect(observations[0].observationTime, DateTime.utc(2026, 1, 5, 10, 35));
      expect(observations[0].historyFor(MarketTimeframe.h1), isEmpty);

      expect(observations[1].observationTime, DateTime.utc(2026, 1, 5, 11));
      expect(observations[1].historyFor(MarketTimeframe.h1), [same(h1)]);
    });

    test('exact higher-timeframe close boundary becomes visible', () {
      final m15 = _candle(10, 30, const Duration(minutes: 15));
      final feed = MultiTimeframeBacktestFeed(
        m5Candles: [_candle(10, 40, const Duration(minutes: 5))],
        m15Candles: [m15],
        h1Candles: const [],
        h4Candles: const [],
      );

      final observation = feed.observations().single;

      expect(observation.observationTime, DateTime.utc(2026, 1, 5, 10, 45));
      expect(observation.latestClosed(MarketTimeframe.m15), same(m15));
    });

    test('future H4 candle remains hidden', () {
      final closedH4 = _candle(4, 0, const Duration(hours: 4));
      final futureH4 = _candle(8, 0, const Duration(hours: 4));

      final observation = MultiTimeframeBacktestFeed(
        m5Candles: [_candle(10, 35, const Duration(minutes: 5))],
        m15Candles: const [],
        h1Candles: const [],
        h4Candles: [closedH4, futureH4],
      ).observations().single;

      expect(observation.historyFor(MarketTimeframe.h4), [same(closedH4)]);
      expect(
        observation.historyFor(MarketTimeframe.h4),
        isNot(contains(same(futureH4))),
      );
    });

    test('each timeframe history is immutable', () {
      final observation = MultiTimeframeBacktestFeed(
        m5Candles: [_candle(10, 0, const Duration(minutes: 5))],
        m15Candles: const [],
        h1Candles: const [],
        h4Candles: const [],
      ).observations().single;

      expect(
        () => observation
            .historyFor(MarketTimeframe.m5)
            .add(_candle(10, 5, const Duration(minutes: 5))),
        throwsUnsupportedError,
      );
      expect(
        () => observation.histories[MarketTimeframe.h1] = const [],
        throwsUnsupportedError,
      );
    });

    test('M5 history also never exposes future M5 candles', () {
      final first = _candle(10, 0, const Duration(minutes: 5));
      final second = _candle(10, 5, const Duration(minutes: 5));

      final observations = MultiTimeframeBacktestFeed(
        m5Candles: [first, second],
        m15Candles: const [],
        h1Candles: const [],
        h4Candles: const [],
      ).observations().toList();

      expect(observations.first.historyFor(MarketTimeframe.m5), [same(first)]);
      expect(
        observations.first.historyFor(MarketTimeframe.m5),
        isNot(contains(same(second))),
      );
    });

    test('empty M5 dataset emits no observations', () {
      final feed = MultiTimeframeBacktestFeed(
        m5Candles: const [],
        m15Candles: const [],
        h1Candles: const [],
        h4Candles: const [],
      );

      expect(feed.isEmpty, isTrue);
      expect(feed.length, 0);
      expect(feed.observations(), isEmpty);
    });

    test('rejects invalid chronology in any supplied timeframe', () {
      final later = _candle(11, 0, const Duration(hours: 1));
      final earlier = _candle(10, 0, const Duration(hours: 1));

      expect(
        () => MultiTimeframeBacktestFeed(
          m5Candles: [_candle(10, 0, const Duration(minutes: 5))],
          m15Candles: const [],
          h1Candles: [later, earlier],
          h4Candles: const [],
        ),
        throwsArgumentError,
      );
    });
  });
}

Candle _candle(int hour, int minute, Duration duration) {
  final openTime = DateTime.utc(2026, 1, 5, hour, minute);
  return Candle(
    openTime: openTime,
    closeTime: openTime.add(duration),
    open: 2300,
    high: 2302,
    low: 2298,
    close: 2301,
    volume: 100,
  );
}
