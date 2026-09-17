import 'strategy_c_episode_validation.dart';

final class StrategyCWindowStats {
  StrategyCWindowStats({
    required this.window,
    required this.start,
    required this.end,
    required this.stats,
  });

  final int window;
  final DateTime start;
  final DateTime end;
  final StrategyCEpisodeStats stats;
}

final class StrategyCRobustnessResult {
  const StrategyCRobustnessResult({
    required this.candidate,
    required this.windows,
  });

  final StrategyCCandidateDefinition candidate;
  final List<StrategyCWindowStats> windows;

  int get sufficientlySizedWindows =>
      windows.where((w) => w.stats.episodes >= 20).length;

  int get directionallyStableWindows => windows.where((w) {
    final s = w.stats;
    if (s.episodes < 20) return false;
    return s.rate(s.success12, s.resolved12) >= .55 &&
        s.rate(s.success24, s.resolved24) >= .55 &&
        s.rate(s.success48, s.resolved48) >= .55;
  }).length;

  int get favorableExcursionWindows => windows.where((w) {
    final s = w.stats;
    return s.episodes >= 20 && s.excursionCount > 0 && s.avgMfe > s.avgMae;
  }).length;
}

final class StrategyCRobustnessValidator {
  const StrategyCRobustnessValidator({this.windowCount = 5});

  final int windowCount;

  StrategyCRobustnessResult validate(
    List<StrategyCEpisodeSample> rows,
    StrategyCCandidateDefinition candidate,
  ) {
    const episodeValidator = StrategyCEpisodeValidator();
    final episodes = episodeValidator.episodeStarts(rows, candidate);

    if (episodes.isEmpty) {
      return StrategyCRobustnessResult(candidate: candidate, windows: const []);
    }

    final windows = <StrategyCWindowStats>[];
    for (var window = 0; window < windowCount; window++) {
      final startIndex = (episodes.length * window / windowCount).floor();
      final endIndex = (episodes.length * (window + 1) / windowCount).floor();
      if (endIndex <= startIndex) continue;

      final slice = episodes.sublist(startIndex, endIndex);
      final stats = _stats(candidate, slice);
      windows.add(
        StrategyCWindowStats(
          window: window + 1,
          start: slice.first.time,
          end: slice.last.time,
          stats: stats,
        ),
      );
    }

    return StrategyCRobustnessResult(candidate: candidate, windows: windows);
  }

  StrategyCEpisodeStats _stats(
    StrategyCCandidateDefinition candidate,
    Iterable<StrategyCEpisodeSample> episodes,
  ) {
    final stats = StrategyCEpisodeStats(
      candidate.id,
      candidate.expectedBullish,
    );

    for (final episode in episodes) {
      stats.episodes++;

      void add(double? value, void Function(bool success) sink) {
        if (value == null || value == 0) return;
        final success = candidate.expectedBullish ? value > 0 : value < 0;
        sink(success);
      }

      add(episode.return12, (success) {
        stats.resolved12++;
        if (success) stats.success12++;
      });
      add(episode.return24, (success) {
        stats.resolved24++;
        if (success) stats.success24++;
      });
      add(episode.return48, (success) {
        stats.resolved48++;
        if (success) stats.success48++;
      });

      if (episode.mfe48 != null && episode.mae48 != null) {
        stats.mfeSum += candidate.expectedBullish
            ? episode.mfe48!
            : episode.mae48!;
        stats.maeSum += candidate.expectedBullish
            ? episode.mae48!
            : episode.mfe48!;
        stats.excursionCount++;
      }
    }
    return stats;
  }
}
