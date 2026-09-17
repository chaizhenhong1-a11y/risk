import 'dart:convert';

final class StrategyCEpisodeSample {
  const StrategyCEpisodeSample({
    required this.time,
    required this.h4,
    required this.h1,
    required this.m15,
    required this.sweep,
    required this.return12,
    required this.return24,
    required this.return48,
    required this.mfe48,
    required this.mae48,
  });

  final DateTime time;
  final String h4;
  final String h1;
  final String m15;
  final String sweep;
  final double? return12;
  final double? return24;
  final double? return48;
  final double? mfe48;
  final double? mae48;

  String get stateKey => '$h4|$h1|$m15|$sweep';

  factory StrategyCEpisodeSample.fromJsonLine(String line) {
    final json = jsonDecode(line) as Map<String, dynamic>;
    final sweeps = <String>[
      if (json['supportSweep'] == true) 'support',
      if (json['resistanceSweep'] == true) 'resistance',
      if (json['equalLowSweep'] == true) 'equalLow',
      if (json['equalHighSweep'] == true) 'equalHigh',
    ];

    double? number(String key) => (json[key] as num?)?.toDouble();

    return StrategyCEpisodeSample(
      time: DateTime.parse(json['time'] as String),
      h4: json['h4Structure'] as String,
      h1: json['h1Structure'] as String,
      m15: json['m15Structure'] as String,
      sweep: sweeps.isEmpty ? 'none' : sweeps.join('+'),
      return12: number('return12'),
      return24: number('return24'),
      return48: number('return48'),
      mfe48: number('mfe48'),
      mae48: number('mae48'),
    );
  }
}

final class StrategyCCandidateDefinition {
  const StrategyCCandidateDefinition({
    required this.id,
    required this.h4,
    required this.h1,
    required this.m15,
    required this.sweep,
    required this.expectedBullish,
  });

  final String id;
  final String h4;
  final String h1;
  final String m15;
  final String sweep;
  final bool expectedBullish;

  bool matches(StrategyCEpisodeSample sample) =>
      sample.h4 == h4 &&
      sample.h1 == h1 &&
      sample.m15 == m15 &&
      sample.sweep == sweep;
}

final class StrategyCEpisodeStats {
  StrategyCEpisodeStats(this.id, this.expectedBullish);

  final String id;
  final bool expectedBullish;
  int episodes = 0;
  int resolved12 = 0;
  int success12 = 0;
  int resolved24 = 0;
  int success24 = 0;
  int resolved48 = 0;
  int success48 = 0;
  double mfeSum = 0;
  double maeSum = 0;
  int excursionCount = 0;

  double rate(int success, int resolved) =>
      resolved == 0 ? 0 : success / resolved;

  double get avgMfe => excursionCount == 0 ? 0 : mfeSum / excursionCount;
  double get avgMae => excursionCount == 0 ? 0 : maeSum / excursionCount;
}

final class StrategyCEpisodeValidationResult {
  const StrategyCEpisodeValidationResult({
    required this.discovery,
    required this.holdout,
  });

  final StrategyCEpisodeStats discovery;
  final StrategyCEpisodeStats holdout;
}

final class StrategyCEpisodeValidator {
  const StrategyCEpisodeValidator({this.discoveryFraction = 0.70});

  final double discoveryFraction;

  List<StrategyCEpisodeSample> episodeStarts(
    List<StrategyCEpisodeSample> rows,
    StrategyCCandidateDefinition candidate,
  ) {
    final result = <StrategyCEpisodeSample>[];
    var previousMatched = false;

    for (final row in rows) {
      final matched = candidate.matches(row);
      if (matched && !previousMatched) result.add(row);
      previousMatched = matched;
    }
    return result;
  }

  StrategyCEpisodeValidationResult validate(
    List<StrategyCEpisodeSample> rows,
    StrategyCCandidateDefinition candidate,
  ) {
    final episodes = episodeStarts(rows, candidate);
    final split = (episodes.length * discoveryFraction).floor();
    return StrategyCEpisodeValidationResult(
      discovery: _stats(candidate, episodes.take(split)),
      holdout: _stats(candidate, episodes.skip(split)),
    );
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
        // Dataset excursions are stored in absolute upward/downward terms.
        // Swap them for bearish hypotheses so favorable/adverse remain
        // direction-relative.
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
