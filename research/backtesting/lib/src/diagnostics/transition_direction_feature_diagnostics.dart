import 'package:technical_analysis/technical_analysis.dart';

enum TransitionResearchExit { trendAligned, correction, other }

final class TransitionDirectionFeatureDiagnostics {
  final Map<_FeatureKey, _MutableOutcome> _outcomes = {};
  _Episode? _active;

  void observeTransition({
    required MarketStructure h4,
    required MarketStructure h1,
    required MarketStructure m15,
    required bool directionalSweepEvidencePresent,
  }) {
    final key = _FeatureKey(
      h4: h4,
      h1: h1,
      m15: m15,
      directionalSweepEvidencePresent: directionalSweepEvidencePresent,
    );

    if (_active == null || _active!.key != key) {
      _active = _Episode(key: key);
    }
    _active!.length++;
  }

  void observeNonTransition({required String regimeName}) {
    final episode = _active;
    if (episode == null) return;

    final exit = switch (regimeName) {
      'trendAligned' => TransitionResearchExit.trendAligned,
      'higherTimeframeTrendLowerTimeframeCorrection' =>
        TransitionResearchExit.correction,
      _ => TransitionResearchExit.other,
    };

    final outcome = _outcomes.putIfAbsent(episode.key, _MutableOutcome.new);
    outcome.samples++;
    outcome.waitObservations += episode.length;
    switch (exit) {
      case TransitionResearchExit.trendAligned:
        outcome.trendAligned++;
      case TransitionResearchExit.correction:
        outcome.correction++;
      case TransitionResearchExit.other:
        outcome.other++;
    }
    _active = null;
  }

  TransitionDirectionFeatureReport finish() {
    final rows =
        _outcomes.entries
            .map(
              (entry) => TransitionDirectionFeatureRow(
                h4: entry.key.h4,
                h1: entry.key.h1,
                m15: entry.key.m15,
                directionalSweepEvidencePresent:
                    entry.key.directionalSweepEvidencePresent,
                samples: entry.value.samples,
                trendAligned: entry.value.trendAligned,
                correction: entry.value.correction,
                other: entry.value.other,
                averageWaitObservations: entry.value.samples == 0
                    ? 0
                    : entry.value.waitObservations / entry.value.samples,
              ),
            )
            .toList()
          ..sort((a, b) => b.samples.compareTo(a.samples));
    return TransitionDirectionFeatureReport(rows);
  }
}

final class TransitionDirectionFeatureReport {
  const TransitionDirectionFeatureReport(this.rows);

  final List<TransitionDirectionFeatureRow> rows;
}

final class TransitionDirectionFeatureRow {
  const TransitionDirectionFeatureRow({
    required this.h4,
    required this.h1,
    required this.m15,
    required this.directionalSweepEvidencePresent,
    required this.samples,
    required this.trendAligned,
    required this.correction,
    required this.other,
    required this.averageWaitObservations,
  });

  final MarketStructure h4;
  final MarketStructure h1;
  final MarketStructure m15;
  final bool directionalSweepEvidencePresent;
  final int samples;
  final int trendAligned;
  final int correction;
  final int other;
  final double averageWaitObservations;

  int get resolvedDirectional => trendAligned + correction;

  double get trendShare =>
      resolvedDirectional == 0 ? 0 : trendAligned / resolvedDirectional;

  double get correctionShare =>
      resolvedDirectional == 0 ? 0 : correction / resolvedDirectional;
}

final class _FeatureKey {
  const _FeatureKey({
    required this.h4,
    required this.h1,
    required this.m15,
    required this.directionalSweepEvidencePresent,
  });

  final MarketStructure h4;
  final MarketStructure h1;
  final MarketStructure m15;
  final bool directionalSweepEvidencePresent;

  @override
  bool operator ==(Object other) =>
      other is _FeatureKey &&
      other.h4 == h4 &&
      other.h1 == h1 &&
      other.m15 == m15 &&
      other.directionalSweepEvidencePresent == directionalSweepEvidencePresent;

  @override
  int get hashCode => Object.hash(h4, h1, m15, directionalSweepEvidencePresent);
}

final class _Episode {
  _Episode({required this.key});
  final _FeatureKey key;
  int length = 0;
}

final class _MutableOutcome {
  int samples = 0;
  int trendAligned = 0;
  int correction = 0;
  int other = 0;
  int waitObservations = 0;
}
