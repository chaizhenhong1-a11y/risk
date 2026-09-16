import 'package:market_models/market_models.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  group('HistoricalStrategyReplay', () {
    test('evaluates exactly once per M5 historical observation', () {
      var evaluations = 0;
      final replay = HistoricalStrategyReplay<int>(
        feed: _feed(),
        evaluator: (observation) {
          evaluations++;
          return observation.index;
        },
      );

      final steps = replay.run().toList();

      expect(steps, hasLength(3));
      expect(evaluations, 3);
      expect(steps.map((step) => step.result), [0, 1, 2]);
    });

    test('preserves chronological observation order', () {
      final steps = HistoricalStrategyReplay<DateTime>(
        feed: _feed(),
        evaluator: (observation) => observation.observationTime,
      ).run().toList();

      expect(steps.map((step) => step.result), [
        DateTime.utc(2026, 1, 5, 10, 5),
        DateTime.utc(2026, 1, 5, 10, 10),
        DateTime.utc(2026, 1, 5, 10, 15),
      ]);
    });

    test('evaluator cannot see a higher timeframe candle before close', () {
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

      final visibleH1Counts = HistoricalStrategyReplay<int>(
        feed: feed,
        evaluator: (observation) =>
            observation.historyFor(MarketTimeframe.h1).length,
      ).run().map((step) => step.result).toList();

      expect(visibleH1Counts, [0, 1]);
    });

    test('step retains the exact observation used for evaluation', () {
      final step = HistoricalStrategyReplay<int>(
        feed: _feed(),
        evaluator: (observation) =>
            observation.historyFor(MarketTimeframe.m5).length,
      ).run().first;

      expect(step.index, 0);
      expect(step.observation.index, 0);
      expect(step.result, 1);
      expect(step.observation.historyFor(MarketTimeframe.m5), hasLength(1));
    });

    test('empty feed produces no replay steps and no evaluations', () {
      var evaluations = 0;
      final replay = HistoricalStrategyReplay<void>(
        feed: MultiTimeframeBacktestFeed(
          m5Candles: const [],
          m15Candles: const [],
          h1Candles: const [],
          h4Candles: const [],
        ),
        evaluator: (_) {
          evaluations++;
        },
      );

      expect(replay.run(), isEmpty);
      expect(evaluations, 0);
    });

    test('replay is lazy and does not evaluate future steps early', () {
      var evaluations = 0;
      final replay = HistoricalStrategyReplay<int>(
        feed: _feed(),
        evaluator: (observation) {
          evaluations++;
          return observation.index;
        },
      );

      final iterator = replay.run().iterator;

      expect(evaluations, 0);
      expect(iterator.moveNext(), isTrue);
      expect(evaluations, 1);
      expect(iterator.current.result, 0);
    });
  });
}

MultiTimeframeBacktestFeed _feed() {
  return MultiTimeframeBacktestFeed(
    m5Candles: [
      _candle(10, 0, const Duration(minutes: 5)),
      _candle(10, 5, const Duration(minutes: 5)),
      _candle(10, 10, const Duration(minutes: 5)),
    ],
    m15Candles: const [],
    h1Candles: const [],
    h4Candles: const [],
  );
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
