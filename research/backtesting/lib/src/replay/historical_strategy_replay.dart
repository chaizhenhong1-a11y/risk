import '../data/multi_timeframe_backtest_feed.dart';

typedef HistoricalStrategyEvaluator<T> =
    T Function(MultiTimeframeBacktestObservation observation);

final class HistoricalReplayStep<T> {
  const HistoricalReplayStep({
    required this.index,
    required this.observation,
    required this.result,
  });

  final int index;
  final MultiTimeframeBacktestObservation observation;
  final T result;
}

/// Deterministically replays one strategy evaluation per historical M5 close.
///
/// This runner owns iteration only. It deliberately does not calculate trading
/// metrics, mutate signal lifecycle state, choose parameters, or look ahead.
/// The supplied evaluator receives exactly the synchronized observation that
/// was available at that historical instant.
final class HistoricalStrategyReplay<T> {
  const HistoricalStrategyReplay({required this.feed, required this.evaluator});

  final MultiTimeframeBacktestFeed feed;
  final HistoricalStrategyEvaluator<T> evaluator;

  Iterable<HistoricalReplayStep<T>> run() sync* {
    for (final observation in feed.observations()) {
      yield HistoricalReplayStep<T>(
        index: observation.index,
        observation: observation,
        result: evaluator(observation),
      );
    }
  }
}
