import 'level_touch_detector.dart';

/// One independent interaction with a key-level zone.
///
/// Consecutive touching candles belong to the same event. A new event starts
/// only after at least one non-touching candle separates it from the previous
/// interaction.
final class LevelTouchEvent {
  const LevelTouchEvent({
    required this.startCandleIndex,
    required this.endCandleIndex,
    required this.touchCount,
  });

  final int startCandleIndex;
  final int endCandleIndex;
  final int touchCount;

  int get durationInCandles => endCandleIndex - startCandleIndex + 1;
}

/// Groups raw candle touches into independent level-touch events.
final class LevelTouchEventDetector {
  const LevelTouchEventDetector();

  List<LevelTouchEvent> group(List<LevelTouch> touches) {
    if (touches.isEmpty) {
      return const [];
    }

    _validateStrictlyIncreasing(touches);

    final events = <LevelTouchEvent>[];
    var start = touches.first.candleIndex;
    var end = start;
    var count = 1;

    for (var index = 1; index < touches.length; index++) {
      final candleIndex = touches[index].candleIndex;

      if (candleIndex == end + 1) {
        end = candleIndex;
        count++;
        continue;
      }

      events.add(
        LevelTouchEvent(
          startCandleIndex: start,
          endCandleIndex: end,
          touchCount: count,
        ),
      );

      start = candleIndex;
      end = candleIndex;
      count = 1;
    }

    events.add(
      LevelTouchEvent(
        startCandleIndex: start,
        endCandleIndex: end,
        touchCount: count,
      ),
    );

    return List.unmodifiable(events);
  }

  void _validateStrictlyIncreasing(List<LevelTouch> touches) {
    for (var index = 1; index < touches.length; index++) {
      if (touches[index].candleIndex <= touches[index - 1].candleIndex) {
        throw ArgumentError(
          'Touch candle indexes must be strictly increasing and unique.',
        );
      }
    }
  }
}
