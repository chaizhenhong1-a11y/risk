import 'dart:convert';

final class C5TriggerEpisode {
  const C5TriggerEpisode({
    required this.bullish,
    required this.reclaimPreviousClose,
    required this.momentum3,
    required this.body,
    required this.range,
    required this.upperWick,
    required this.lowerWick,
    required this.return12,
    required this.return24,
    required this.return48,
    required this.mfe48,
    required this.mae48,
  });

  final bool bullish;
  final bool reclaimPreviousClose;
  final bool momentum3;
  final double body;
  final double range;
  final double upperWick;
  final double lowerWick;
  final double? return12;
  final double? return24;
  final double? return48;
  final double? mfe48;
  final double? mae48;

  double get bodyRatio => range <= 0 ? 0 : body / range;
  double get lowerWickRatio => range <= 0 ? 0 : lowerWick / range;
  double get upperWickRatio => range <= 0 ? 0 : upperWick / range;

  factory C5TriggerEpisode.fromJsonLine(String line) {
    final json = jsonDecode(line) as Map<String, dynamic>;
    double? number(String key) => (json[key] as num?)?.toDouble();

    return C5TriggerEpisode(
      bullish: json['bullish'] == true,
      reclaimPreviousClose: json['reclaimPreviousClose'] == true,
      momentum3: json['momentum3'] == true,
      body: (json['body'] as num).toDouble(),
      range: (json['range'] as num).toDouble(),
      upperWick: (json['upperWick'] as num).toDouble(),
      lowerWick: (json['lowerWick'] as num).toDouble(),
      return12: number('return12'),
      return24: number('return24'),
      return48: number('return48'),
      mfe48: number('mfe48'),
      mae48: number('mae48'),
    );
  }
}

final class C5TriggerDefinition {
  const C5TriggerDefinition(this.id, this.matches);

  final String id;
  final bool Function(C5TriggerEpisode) matches;
}

final class C5TriggerStats {
  C5TriggerStats(this.id);

  final String id;
  int samples = 0;
  int resolved12 = 0;
  int bullish12 = 0;
  int resolved24 = 0;
  int bullish24 = 0;
  int resolved48 = 0;
  int bullish48 = 0;
  double mfeSum = 0;
  double maeSum = 0;
  int excursionCount = 0;

  double rate(int success, int resolved) =>
      resolved == 0 ? 0 : success / resolved;
  double get avgMfe => excursionCount == 0 ? 0 : mfeSum / excursionCount;
  double get avgMae => excursionCount == 0 ? 0 : maeSum / excursionCount;
}

final class C5TriggerDiscovery {
  const C5TriggerDiscovery();

  C5TriggerStats evaluate(
    Iterable<C5TriggerEpisode> episodes,
    C5TriggerDefinition definition,
  ) {
    final stats = C5TriggerStats(definition.id);

    for (final episode in episodes) {
      if (!definition.matches(episode)) continue;
      stats.samples++;

      void add(double? value, void Function(bool bullish) sink) {
        if (value == null || value == 0) return;
        sink(value > 0);
      }

      add(episode.return12, (bullish) {
        stats.resolved12++;
        if (bullish) stats.bullish12++;
      });
      add(episode.return24, (bullish) {
        stats.resolved24++;
        if (bullish) stats.bullish24++;
      });
      add(episode.return48, (bullish) {
        stats.resolved48++;
        if (bullish) stats.bullish48++;
      });

      if (episode.mfe48 != null && episode.mae48 != null) {
        stats.mfeSum += episode.mfe48!;
        stats.maeSum += episode.mae48!;
        stats.excursionCount++;
      }
    }
    return stats;
  }
}

List<C5TriggerDefinition> c5TriggerDefinitions() => [
  C5TriggerDefinition('baseline', (_) => true),
  C5TriggerDefinition('bullish', (e) => e.bullish),
  C5TriggerDefinition('reclaimPreviousClose', (e) => e.reclaimPreviousClose),
  C5TriggerDefinition('momentum3', (e) => e.momentum3),
  C5TriggerDefinition(
    'bullish+reclaim',
    (e) => e.bullish && e.reclaimPreviousClose,
  ),
  C5TriggerDefinition(
    'bullish+body>=0.50',
    (e) => e.bullish && e.bodyRatio >= .50,
  ),
  C5TriggerDefinition(
    'bullish+body>=0.60',
    (e) => e.bullish && e.bodyRatio >= .60,
  ),
  C5TriggerDefinition(
    'bullish+lowerWick>=0.25',
    (e) => e.bullish && e.lowerWickRatio >= .25,
  ),
  C5TriggerDefinition(
    'reclaim+body>=0.50',
    (e) => e.reclaimPreviousClose && e.bodyRatio >= .50,
  ),
  C5TriggerDefinition(
    'reclaim+lowerWick>=0.25',
    (e) => e.reclaimPreviousClose && e.lowerWickRatio >= .25,
  ),
  C5TriggerDefinition(
    'bullish+reclaim+body>=0.50',
    (e) => e.bullish && e.reclaimPreviousClose && e.bodyRatio >= .50,
  ),
  C5TriggerDefinition(
    'bullish+reclaim+lowerWick>=0.25',
    (e) => e.bullish && e.reclaimPreviousClose && e.lowerWickRatio >= .25,
  ),
  C5TriggerDefinition(
    'bullish+upperWick<=0.20',
    (e) => e.bullish && e.upperWickRatio <= .20,
  ),
];
