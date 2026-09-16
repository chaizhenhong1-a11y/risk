import 'level_touch_event_detector.dart';

enum LevelStrength { untested, weak, established, wellTested }

/// Baseline strength classification based only on independent touch events.
///
/// This is deliberately not a trading score. Rejection quality, recency,
/// volatility, break history, and higher-timeframe confluence are separate
/// future inputs.
final class LevelStrengthEvaluator {
  const LevelStrengthEvaluator();

  LevelStrength evaluate(List<LevelTouchEvent> events) {
    return switch (events.length) {
      0 => LevelStrength.untested,
      1 => LevelStrength.weak,
      2 => LevelStrength.established,
      _ => LevelStrength.wellTested,
    };
  }
}
