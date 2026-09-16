import 'dart:collection';

import 'package:market_models/market_models.dart';

import 'backtest_candle_feed.dart';
import 'mt5_history_adapter.dart';

/// One M5-driven historical observation with only CLOSED candles visible.
///
/// [observationTime] is the close time of [currentM5Candle]. Every candle
/// exposed in every timeframe history has `closeTime <= observationTime`.
final class MultiTimeframeBacktestObservation {
  MultiTimeframeBacktestObservation({
    required this.index,
    required this.observationTime,
    required this.currentM5Candle,
    required Map<MarketTimeframe, List<Candle>> histories,
  }) : histories = Map<MarketTimeframe, List<Candle>>.unmodifiable(
         histories.map(
           (timeframe, candles) => MapEntry(
             timeframe,
             candles is _FrozenPrefixList<Candle>
                 ? candles
                 : List<Candle>.unmodifiable(candles),
           ),
         ),
       );

  final int index;
  final DateTime observationTime;
  final Candle currentM5Candle;
  final Map<MarketTimeframe, List<Candle>> histories;

  List<Candle> historyFor(MarketTimeframe timeframe) =>
      histories[timeframe] ?? const <Candle>[];

  Candle? latestClosed(MarketTimeframe timeframe) {
    final history = historyFor(timeframe);
    return history.isEmpty ? null : history.last;
  }
}

/// Synchronizes M5, M15, H1 and H4 history without look-ahead.
///
/// M5 is the research clock. An observation is emitted only after an M5 candle
/// has closed. Higher-timeframe candles become visible only when their own
/// close time is less than or equal to that M5 close time.
///
/// Example: after the 10:35-10:40 M5 candle closes, an H1 candle that closes at
/// 11:00 is still hidden.
final class MultiTimeframeBacktestFeed {
  MultiTimeframeBacktestFeed({
    required List<Candle> m5Candles,
    required List<Candle> m15Candles,
    required List<Candle> h1Candles,
    required List<Candle> h4Candles,
  }) : _m5 = BacktestCandleFeed(m5Candles).candles,
       _m15 = BacktestCandleFeed(m15Candles).candles,
       _h1 = BacktestCandleFeed(h1Candles).candles,
       _h4 = BacktestCandleFeed(h4Candles).candles;

  final List<Candle> _m5;
  final List<Candle> _m15;
  final List<Candle> _h1;
  final List<Candle> _h4;

  int get length => _m5.length;
  bool get isEmpty => _m5.isEmpty;

  Iterable<MultiTimeframeBacktestObservation> observations() sync* {
    final visibleM5 = <Candle>[];
    final visibleM15 = <Candle>[];
    final visibleH1 = <Candle>[];
    final visibleH4 = <Candle>[];

    var m15Index = 0;
    var h1Index = 0;
    var h4Index = 0;

    for (var index = 0; index < _m5.length; index++) {
      final currentM5 = _m5[index];
      final observationTime = currentM5.closeTime;
      visibleM5.add(currentM5);

      m15Index = _revealClosedCandles(
        source: _m15,
        nextIndex: m15Index,
        observationTime: observationTime,
        visible: visibleM15,
      );
      h1Index = _revealClosedCandles(
        source: _h1,
        nextIndex: h1Index,
        observationTime: observationTime,
        visible: visibleH1,
      );
      h4Index = _revealClosedCandles(
        source: _h4,
        nextIndex: h4Index,
        observationTime: observationTime,
        visible: visibleH4,
      );

      yield MultiTimeframeBacktestObservation(
        index: index,
        observationTime: observationTime,
        currentM5Candle: currentM5,
        histories: {
          MarketTimeframe.m5: _FrozenPrefixList(visibleM5, visibleM5.length),
          MarketTimeframe.m15: _FrozenPrefixList(visibleM15, visibleM15.length),
          MarketTimeframe.h1: _FrozenPrefixList(visibleH1, visibleH1.length),
          MarketTimeframe.h4: _FrozenPrefixList(visibleH4, visibleH4.length),
        },
      );
    }
  }

  static int _revealClosedCandles({
    required List<Candle> source,
    required int nextIndex,
    required DateTime observationTime,
    required List<Candle> visible,
  }) {
    var index = nextIndex;

    while (index < source.length &&
        !source[index].closeTime.isAfter(observationTime)) {
      visible.add(source[index]);
      index++;
    }

    return index;
  }
}

/// Read-only snapshot of a list prefix without copying the prefix contents.
///
/// The backing replay history may continue growing after this view is created,
/// but [_visibleLength] is frozen at the observation boundary. Later candles
/// therefore remain inaccessible and anti-look-ahead semantics are preserved.
/// This removes the O(history length) list copy previously paid four times for
/// every M5 observation.
final class _FrozenPrefixList<E> extends ListBase<E> {
  _FrozenPrefixList(this._backing, this._visibleLength);

  final List<E> _backing;
  final int _visibleLength;

  @override
  int get length => _visibleLength;

  @override
  set length(int value) =>
      throw UnsupportedError('Historical view is immutable.');

  @override
  E operator [](int index) {
    RangeError.checkValidIndex(index, this);
    return _backing[index];
  }

  @override
  void operator []=(int index, E value) {
    throw UnsupportedError('Historical view is immutable.');
  }
}
