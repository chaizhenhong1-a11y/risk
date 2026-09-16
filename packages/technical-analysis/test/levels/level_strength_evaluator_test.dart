import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const evaluator = LevelStrengthEvaluator();

  group('LevelStrengthEvaluator', () {
    test('zero independent events is untested', () {
      expect(evaluator.evaluate(const []), LevelStrength.untested);
    });

    test('one independent event is weak', () {
      expect(evaluator.evaluate([_event(10, 12, 3)]), LevelStrength.weak);
    });

    test('two independent events is established', () {
      expect(
        evaluator.evaluate([_event(10, 12, 3), _event(20, 20, 1)]),
        LevelStrength.established,
      );
    });

    test('three or more independent events is well tested', () {
      expect(
        evaluator.evaluate([
          _event(10, 12, 3),
          _event(20, 20, 1),
          _event(30, 31, 2),
        ]),
        LevelStrength.wellTested,
      );
    });

    test('raw candle count inside one event does not inflate strength', () {
      expect(evaluator.evaluate([_event(10, 19, 10)]), LevelStrength.weak);
    });
  });
}

LevelTouchEvent _event(int start, int end, int touchCount) => LevelTouchEvent(
  startCandleIndex: start,
  endCandleIndex: end,
  touchCount: touchCount,
);
