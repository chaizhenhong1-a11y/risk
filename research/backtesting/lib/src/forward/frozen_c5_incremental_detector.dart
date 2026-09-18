import '../dataset/strategy_c_episode_validation.dart';
import 'frozen_c5_episode_detector.dart';
import 'paper_strategy_opportunity.dart';

/// Frozen C5 opportunity resolver supplied by the existing structural-risk
/// pipeline.
///
/// The resolver owns the already-frozen structural Entry/SL/TP calculation and
/// conversion to a paper opportunity. Returning null means valid structural
/// geometry is unavailable, so no trade is invented.
///
/// Keeping this boundary at [PaperStrategyOpportunity] avoids coupling the
/// incremental episode detector to a research-only structural-risk DTO.
typedef FrozenC5OpportunityResolver =
    PaperStrategyOpportunity? Function(StrategyCEpisodeSample episode);

/// Incremental paper-forward boundary for C5.
///
/// It detects only a new C5 episode edge, then asks the already-frozen
/// structural-risk pipeline for the complete opportunity. No additional
/// quality gate, quota, fallback stop, or synthetic target is introduced here.
final class FrozenC5IncrementalDetector {
  FrozenC5IncrementalDetector({
    required this.resolveOpportunity,
    FrozenC5EpisodeDetector? episodeDetector,
  }) : episodeDetector = episodeDetector ?? FrozenC5EpisodeDetector();

  final FrozenC5OpportunityResolver resolveOpportunity;
  final FrozenC5EpisodeDetector episodeDetector;

  PaperStrategyOpportunity? observe(StrategyCEpisodeSample row) {
    if (!episodeDetector.observe(row)) return null;

    final opportunity = resolveOpportunity(row);
    if (opportunity == null) return null;

    if (opportunity.strategy != 'C5') {
      throw StateError(
        'Frozen C5 resolver emitted strategy ${opportunity.strategy}.',
      );
    }
    if (opportunity.observedAt != row.time) {
      throw StateError(
        'Frozen C5 opportunity timestamp does not match the episode.',
      );
    }

    return opportunity;
  }

  void warmUp(Iterable<StrategyCEpisodeSample> rows) {
    episodeDetector.warmUp(rows);
  }
}
