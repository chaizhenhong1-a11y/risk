import 'key_level.dart';
import 'level_break_detector.dart';

/// Applies already-classified market events to a key level.
///
/// Detection and lifecycle mutation stay separate: the break detector decides
/// what happened; this class decides whether that event changes level state.
final class KeyLevelLifecycle {
  const KeyLevelLifecycle();

  KeyLevel applyBreakResult({
    required KeyLevel level,
    required LevelBreakResult breakResult,
  }) {
    if (!level.isActive) {
      return level;
    }

    if (breakResult != LevelBreakResult.confirmedBreak) {
      return level;
    }

    return KeyLevel(
      type: level.type,
      source: level.source,
      status: KeyLevelStatus.broken,
      lowerBound: level.lowerBound,
      upperBound: level.upperBound,
      createdAtCandleIndex: level.createdAtCandleIndex,
    );
  }
}
