import '../dataset/strategy_c_episode_validation.dart';
import '../dataset/strategy_c_structural_lifecycle_validation.dart';
import 'frozen_c5_paper_adapter.dart';
import 'paper_strategy_opportunity.dart';

/// Live structural inputs produced from the SAME closed observation that
/// produced a new C5 episode.
final class FrozenC5StructuralContext {
  const FrozenC5StructuralContext({
    required this.time,
    required this.entryClose,
    required this.m15Atr14,
    required this.nearestActiveSupportLowerBound,
  });

  final DateTime time;
  final double entryClose;
  final double m15Atr14;
  final double nearestActiveSupportLowerBound;
}

/// Recreates only the frozen C5 risk geometry.
///
/// C5 definition/discovery remains in FrozenC5EpisodeDetector:
/// H4 neutral + H1 bullish + M15 bearish + resistance sweep, false -> true.
///
/// Risk is unchanged from the validated C5 research:
/// SL = nearest active M15 support lower bound - M15 ATR(14) * 0.50
/// TP = 2R.
final class FrozenC5StructuralResolver {
  const FrozenC5StructuralResolver({
    this.atrBufferMultiplier = 0.50,
    FrozenC5PaperAdapter? adapter,
  }) : adapter = adapter ?? const FrozenC5PaperAdapter();

  final double atrBufferMultiplier;
  final FrozenC5PaperAdapter adapter;

  PaperStrategyOpportunity resolve({
    required StrategyCEpisodeSample episode,
    required FrozenC5StructuralContext context,
  }) {
    if (context.time != episode.time) {
      throw StateError(
        'C5 structural context timestamp does not match episode.',
      );
    }
    if (!context.entryClose.isFinite ||
        !context.m15Atr14.isFinite ||
        !context.nearestActiveSupportLowerBound.isFinite ||
        context.m15Atr14 <= 0) {
      throw ArgumentError('Invalid frozen C5 structural context.');
    }

    final stop =
        context.nearestActiveSupportLowerBound -
        (context.m15Atr14 * atrBufferMultiplier);
    final distance = context.entryClose - stop;
    if (!stop.isFinite || !distance.isFinite || distance <= 0) {
      throw ArgumentError('Invalid frozen C5 structural stop geometry.');
    }

    return adapter.convert(
      C5StructuralRisk(
        time: context.time,
        entryClose: context.entryClose,
        m15Atr14: context.m15Atr14,
        supportLowerBound: context.nearestActiveSupportLowerBound,
        bufferedStopPrice: stop,
        bufferedStopDistance: distance,
      ),
    );
  }
}
