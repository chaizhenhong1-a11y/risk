import 'package:technical_analysis/technical_analysis.dart';

enum TransitionFeatureExit { trendAligned, correction, other }

final class TransitionFeatureDiscovery {
  final Map<_Key, _Outcome> _outcomes = {};
  _Episode? _active;

  void observeTransition({
    required MarketStructure h4,
    required MarketStructure h1,
    required MarketStructure m15,
    required bool supportSweep,
    required bool resistanceSweep,
    required bool equalLowSweep,
    required bool equalHighSweep,
  }) {
    final key = _Key(
      h4: h4,
      h1: h1,
      m15: m15,
      supportSweep: supportSweep,
      resistanceSweep: resistanceSweep,
      equalLowSweep: equalLowSweep,
      equalHighSweep: equalHighSweep,
    );

    if (_active == null || _active!.key != key) {
      _active = _Episode(key);
    }
    _active!.observations++;
  }

  void observeExit(String regimeName) {
    final episode = _active;
    if (episode == null) return;

    final outcome = _outcomes.putIfAbsent(episode.key, _Outcome.new);
    outcome.samples++;
    outcome.waitM5 += episode.observations;

    if (regimeName == 'trendAligned') {
      outcome.trend++;
    } else if (regimeName == 'higherTimeframeTrendLowerTimeframeCorrection') {
      outcome.correction++;
    } else {
      outcome.other++;
    }
    _active = null;
  }

  TransitionFeatureDiscoveryReport finish() {
    final rows = _outcomes.entries.map((entry) {
      final o = entry.value;
      return TransitionFeatureDiscoveryRow(
        h4: entry.key.h4,
        h1: entry.key.h1,
        m15: entry.key.m15,
        supportSweep: entry.key.supportSweep,
        resistanceSweep: entry.key.resistanceSweep,
        equalLowSweep: entry.key.equalLowSweep,
        equalHighSweep: entry.key.equalHighSweep,
        samples: o.samples,
        trend: o.trend,
        correction: o.correction,
        other: o.other,
        averageWaitM5: o.samples == 0 ? 0 : o.waitM5 / o.samples,
      );
    }).toList()..sort((a, b) => b.samples.compareTo(a.samples));

    return TransitionFeatureDiscoveryReport(List.unmodifiable(rows));
  }
}

final class TransitionFeatureDiscoveryReport {
  const TransitionFeatureDiscoveryReport(this.rows);
  final List<TransitionFeatureDiscoveryRow> rows;
}

final class TransitionFeatureDiscoveryRow {
  const TransitionFeatureDiscoveryRow({
    required this.h4,
    required this.h1,
    required this.m15,
    required this.supportSweep,
    required this.resistanceSweep,
    required this.equalLowSweep,
    required this.equalHighSweep,
    required this.samples,
    required this.trend,
    required this.correction,
    required this.other,
    required this.averageWaitM5,
  });

  final MarketStructure h4;
  final MarketStructure h1;
  final MarketStructure m15;
  final bool supportSweep;
  final bool resistanceSweep;
  final bool equalLowSweep;
  final bool equalHighSweep;
  final int samples;
  final int trend;
  final int correction;
  final int other;
  final double averageWaitM5;

  int get resolved => trend + correction;
  double get trendShare => resolved == 0 ? 0 : trend / resolved;
  double get correctionShare => resolved == 0 ? 0 : correction / resolved;

  String get sweepLabel {
    final values = <String>[
      if (supportSweep) 'support',
      if (resistanceSweep) 'resistance',
      if (equalLowSweep) 'equalLow',
      if (equalHighSweep) 'equalHigh',
    ];
    return values.isEmpty ? 'none' : values.join('+');
  }
}

final class _Key {
  const _Key({
    required this.h4,
    required this.h1,
    required this.m15,
    required this.supportSweep,
    required this.resistanceSweep,
    required this.equalLowSweep,
    required this.equalHighSweep,
  });

  final MarketStructure h4;
  final MarketStructure h1;
  final MarketStructure m15;
  final bool supportSweep;
  final bool resistanceSweep;
  final bool equalLowSweep;
  final bool equalHighSweep;

  @override
  bool operator ==(Object other) =>
      other is _Key &&
      h4 == other.h4 &&
      h1 == other.h1 &&
      m15 == other.m15 &&
      supportSweep == other.supportSweep &&
      resistanceSweep == other.resistanceSweep &&
      equalLowSweep == other.equalLowSweep &&
      equalHighSweep == other.equalHighSweep;

  @override
  int get hashCode => Object.hash(
    h4,
    h1,
    m15,
    supportSweep,
    resistanceSweep,
    equalLowSweep,
    equalHighSweep,
  );
}

final class _Episode {
  _Episode(this.key);
  final _Key key;
  int observations = 0;
}

final class _Outcome {
  int samples = 0;
  int trend = 0;
  int correction = 0;
  int other = 0;
  int waitM5 = 0;
}
