import 'package:market_models/market_models.dart';

/// One chronological observation emitted by [BacktestCandleFeed].
///
/// [history] contains only candles available up to and including
/// [currentCandle]. Future candles are never exposed to the consumer.
final class BacktestCandleObservation {
  BacktestCandleObservation({
    required this.index,
    required this.currentCandle,
    required List<Candle> history,
  }) : history = List<Candle>.unmodifiable(history);

  final int index;
  final Candle currentCandle;
  final List<Candle> history;
}

/// Deterministic chronological candle feed for historical research.
///
/// This is the first Phase 7 anti-look-ahead boundary. Input must already be
/// strictly chronological. The feed deliberately rejects duplicate/out-of-order
/// candle open times instead of silently sorting them, because silent sorting
/// can hide bad historical datasets.
final class BacktestCandleFeed {
  BacktestCandleFeed(List<Candle> candles)
    : candles = List<Candle>.unmodifiable(candles) {
    _validateChronology(this.candles);
  }

  final List<Candle> candles;

  int get length => candles.length;
  bool get isEmpty => candles.isEmpty;

  Iterable<BacktestCandleObservation> observations() sync* {
    final history = <Candle>[];

    for (var index = 0; index < candles.length; index++) {
      final candle = candles[index];
      history.add(candle);

      yield BacktestCandleObservation(
        index: index,
        currentCandle: candle,
        history: history,
      );
    }
  }

  static void _validateChronology(List<Candle> candles) {
    for (var index = 1; index < candles.length; index++) {
      final previous = candles[index - 1];
      final current = candles[index];

      if (!current.openTime.isAfter(previous.openTime)) {
        throw ArgumentError(
          'Backtest candles must have strictly increasing openTime. '
          'Invalid order at indexes ${index - 1} and $index.',
        );
      }

      if (current.openTime.isBefore(previous.closeTime)) {
        throw ArgumentError(
          'Backtest candles must not overlap. '
          'Candle $index opens before candle ${index - 1} closes.',
        );
      }
    }
  }
}
