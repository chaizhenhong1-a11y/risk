import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const detector = LevelTouchEventDetector();

  group('LevelTouchEventDetector', () {
    test('groups consecutive touching candles into one independent event', () {
      final events = detector.group([_touch(10), _touch(11), _touch(12)]);

      expect(events, hasLength(1));
      expect(events.single.startCandleIndex, 10);
      expect(events.single.endCandleIndex, 12);
      expect(events.single.touchCount, 3);
      expect(events.single.durationInCandles, 3);
    });

    test('separates events after at least one non-touching candle', () {
      final events = detector.group([
        _touch(10),
        _touch(11),
        _touch(13),
        _touch(16),
        _touch(17),
      ]);

      expect(events, hasLength(3));

      expect(events[0].startCandleIndex, 10);
      expect(events[0].endCandleIndex, 11);
      expect(events[0].touchCount, 2);

      expect(events[1].startCandleIndex, 13);
      expect(events[1].endCandleIndex, 13);
      expect(events[1].touchCount, 1);

      expect(events[2].startCandleIndex, 16);
      expect(events[2].endCandleIndex, 17);
      expect(events[2].touchCount, 2);
    });

    test('single touch becomes one one-candle event', () {
      final events = detector.group([_touch(7)]);

      expect(events, hasLength(1));
      expect(events.single.startCandleIndex, 7);
      expect(events.single.endCandleIndex, 7);
      expect(events.single.touchCount, 1);
      expect(events.single.durationInCandles, 1);
    });

    test('empty touches produce no events', () {
      expect(detector.group(const []), isEmpty);
    });

    test('rejects duplicate candle indexes', () {
      expect(
        () => detector.group([_touch(10), _touch(10)]),
        throwsArgumentError,
      );
    });

    test('rejects out-of-order candle indexes', () {
      expect(
        () => detector.group([_touch(11), _touch(10)]),
        throwsArgumentError,
      );
    });
  });
}

LevelTouch _touch(int candleIndex) => LevelTouch(
  candleIndex: candleIndex,
  level: KeyLevel(
    type: KeyLevelType.support,
    source: KeyLevelSource.swingLow,
    status: KeyLevelStatus.active,
    lowerBound: 3250,
    upperBound: 3252,
    createdAtCandleIndex: 5,
  ),
);
