import '../dataset/strategy_c_episode_validation.dart';

/// Frozen descriptive C5 state from the validated Strategy-C research.
///
/// C5 is bullish and matches exactly:
/// H4 neutral / H1 bullish / M15 bearish / resistance sweep.
///
/// This class owns only incremental episode-edge detection. It does not create
/// Entry/SL/TP geometry; that remains the frozen structural-risk pipeline.
final class FrozenC5EpisodeDetector {
  FrozenC5EpisodeDetector({bool previousMatched = false})
    : _previousMatched = previousMatched;

  static const definition = StrategyCCandidateDefinition(
    id: 'C5',
    h4: 'neutral',
    h1: 'bullish',
    m15: 'bearish',
    sweep: 'resistance',
    expectedBullish: true,
  );

  bool _previousMatched;

  bool get previousMatched => _previousMatched;

  /// Returns true only on a false -> true C5 transition.
  bool observe(StrategyCEpisodeSample row) {
    final matched = definition.matches(row);
    final episodeStarted = matched && !_previousMatched;
    _previousMatched = matched;
    return episodeStarted;
  }

  /// Seeds continuity from warm-up/history without publishing a historical
  /// signal. Only the final observed match-state is retained.
  void warmUp(Iterable<StrategyCEpisodeSample> rows) {
    for (final row in rows) {
      _previousMatched = definition.matches(row);
    }
  }
}
