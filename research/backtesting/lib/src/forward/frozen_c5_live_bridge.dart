import '../dataset/strategy_c_episode_validation.dart';
import 'frozen_c5_incremental_detector.dart';
import 'frozen_c5_structural_resolver.dart';
import 'paper_strategy_opportunity.dart';

typedef FrozenC5ContextResolver =
    FrozenC5StructuralContext? Function(StrategyCEpisodeSample episode);

/// Connects exact C5 episode-edge discovery to exact frozen structural risk.
///
/// Returning null structural context means the current closed observation has
/// no valid ATR/support geometry; no fallback stop or target is invented.
final class FrozenC5LiveBridge {
  FrozenC5LiveBridge({
    required this.resolveContext,
    FrozenC5StructuralResolver? structuralResolver,
  }) : _detector = FrozenC5IncrementalDetector(
         resolveOpportunity: (episode) {
           final context = resolveContext(episode);
           if (context == null) return null;
           return (structuralResolver ?? const FrozenC5StructuralResolver())
               .resolve(episode: episode, context: context);
         },
       );

  final FrozenC5ContextResolver resolveContext;
  final FrozenC5IncrementalDetector _detector;

  PaperStrategyOpportunity? observe(StrategyCEpisodeSample row) =>
      _detector.observe(row);

  void warmUp(Iterable<StrategyCEpisodeSample> rows) => _detector.warmUp(rows);
}
