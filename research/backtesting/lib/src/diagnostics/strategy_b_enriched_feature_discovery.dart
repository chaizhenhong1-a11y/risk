import 'strategy_b_candidate_research_diagnostics.dart';
import 'strategy_b_research_snapshot.dart';

enum StrategyBCorrectionExcursionBucket {
  belowOneAtr,
  oneToTwoAtr,
  twoToFourAtr,
  atLeastFourAtr,
  unavailable,
}

enum StrategyBCorrectionDurationBucket {
  oneToTwoBars,
  threeToFiveBars,
  sixToTenBars,
  moreThanTenBars,
  unavailable,
}

enum StrategyBRealignmentBodyBucket {
  belowQuarterAtr,
  quarterToHalfAtr,
  halfToOneAtr,
  atLeastOneAtr,
  unavailable,
}

enum StrategyBDirectionalCloseBucket {
  belowHalf,
  halfToSeventy,
  seventyToEightyFive,
  atLeastEightyFive,
  unavailable,
}

final class StrategyBEnrichedFeatureDiscovery {
  const StrategyBEnrichedFeatureDiscovery();

  StrategyBEnrichedFeatureReport analyze(StrategyBResearchSnapshot snapshot) {
    final sections = <StrategyBEnrichedFeatureSection>[];
    final horizons = snapshot.samplesByHorizon.keys.toList()..sort();
    for (final horizon in horizons) {
      final samples = snapshot.samplesByHorizon[horizon]!;
      if (samples.length != snapshot.records.length) {
        throw StateError(
          'Snapshot record/sample alignment mismatch for $horizon M5.',
        );
      }
      final pairs = List.generate(
        samples.length,
        (i) => _Pair(snapshot.records[i], samples[i]),
        growable: false,
      );
      sections.add(
        StrategyBEnrichedFeatureSection(
          horizonM5: horizon,
          byCorrectionExcursion: _group(
            pairs,
            (p) => _excursion(p.record.h1CorrectionExcursionAtr),
            StrategyBCorrectionExcursionBucket.values,
          ),
          byCorrectionDuration: _group(
            pairs,
            (p) => _duration(p.record.h1CorrectionDurationBars),
            StrategyBCorrectionDurationBucket.values,
          ),
          byRealignmentBody: _group(
            pairs,
            (p) => _body(p.record.m15RealignmentBodyAtr),
            StrategyBRealignmentBodyBucket.values,
          ),
          byDirectionalClose: _group(
            pairs,
            (p) => _close(p.record.m15DirectionalCloseLocation),
            StrategyBDirectionalCloseBucket.values,
          ),
          eligibleByCorrectionExcursion: _group(
            pairs.where((p) => p.sample.riskEligible),
            (p) => _excursion(p.record.h1CorrectionExcursionAtr),
            StrategyBCorrectionExcursionBucket.values,
          ),
          eligibleByCorrectionDuration: _group(
            pairs.where((p) => p.sample.riskEligible),
            (p) => _duration(p.record.h1CorrectionDurationBars),
            StrategyBCorrectionDurationBucket.values,
          ),
          eligibleByRealignmentBody: _group(
            pairs.where((p) => p.sample.riskEligible),
            (p) => _body(p.record.m15RealignmentBodyAtr),
            StrategyBRealignmentBodyBucket.values,
          ),
          eligibleByDirectionalClose: _group(
            pairs.where((p) => p.sample.riskEligible),
            (p) => _close(p.record.m15DirectionalCloseLocation),
            StrategyBDirectionalCloseBucket.values,
          ),
        ),
      );
    }
    return StrategyBEnrichedFeatureReport(
      candidateCount: snapshot.records.length,
      sections: sections,
    );
  }

  Map<T, StrategyBEnrichedFeatureSummary> _group<T>(
    Iterable<_Pair> pairs,
    T Function(_Pair) key,
    Iterable<T> keys,
  ) => {for (final k in keys) k: _summary(pairs.where((p) => key(p) == k))};

  StrategyBEnrichedFeatureSummary _summary(Iterable<_Pair> pairs) {
    var n = 0, eligible = 0, continuation = 0, rejection = 0, unresolved = 0;
    for (final p in pairs) {
      n++;
      if (p.sample.riskEligible) eligible++;
      switch (p.sample.outcome) {
        case StrategyBCandidateOutcome.continuation:
          continuation++;
        case StrategyBCandidateOutcome.rejection:
          rejection++;
        case StrategyBCandidateOutcome.unresolved:
          unresolved++;
      }
    }
    return StrategyBEnrichedFeatureSummary(
      candidates: n,
      eligible: eligible,
      continuation: continuation,
      rejection: rejection,
      unresolved: unresolved,
    );
  }

  StrategyBCorrectionExcursionBucket _excursion(double? v) => v == null
      ? StrategyBCorrectionExcursionBucket.unavailable
      : v < 1
      ? StrategyBCorrectionExcursionBucket.belowOneAtr
      : v < 2
      ? StrategyBCorrectionExcursionBucket.oneToTwoAtr
      : v < 4
      ? StrategyBCorrectionExcursionBucket.twoToFourAtr
      : StrategyBCorrectionExcursionBucket.atLeastFourAtr;
  StrategyBCorrectionDurationBucket _duration(int? v) => v == null
      ? StrategyBCorrectionDurationBucket.unavailable
      : v <= 2
      ? StrategyBCorrectionDurationBucket.oneToTwoBars
      : v <= 5
      ? StrategyBCorrectionDurationBucket.threeToFiveBars
      : v <= 10
      ? StrategyBCorrectionDurationBucket.sixToTenBars
      : StrategyBCorrectionDurationBucket.moreThanTenBars;
  StrategyBRealignmentBodyBucket _body(double? v) => v == null
      ? StrategyBRealignmentBodyBucket.unavailable
      : v < .25
      ? StrategyBRealignmentBodyBucket.belowQuarterAtr
      : v < .5
      ? StrategyBRealignmentBodyBucket.quarterToHalfAtr
      : v < 1
      ? StrategyBRealignmentBodyBucket.halfToOneAtr
      : StrategyBRealignmentBodyBucket.atLeastOneAtr;
  StrategyBDirectionalCloseBucket _close(double? v) => v == null
      ? StrategyBDirectionalCloseBucket.unavailable
      : v < .5
      ? StrategyBDirectionalCloseBucket.belowHalf
      : v < .7
      ? StrategyBDirectionalCloseBucket.halfToSeventy
      : v < .85
      ? StrategyBDirectionalCloseBucket.seventyToEightyFive
      : StrategyBDirectionalCloseBucket.atLeastEightyFive;
}

final class _Pair {
  const _Pair(this.record, this.sample);
  final StrategyBResearchSnapshotRecord record;
  final StrategyBCandidateResearchSample sample;
}

final class StrategyBEnrichedFeatureReport {
  const StrategyBEnrichedFeatureReport({
    required this.candidateCount,
    required this.sections,
  });
  final int candidateCount;
  final List<StrategyBEnrichedFeatureSection> sections;
}

final class StrategyBEnrichedFeatureSection {
  const StrategyBEnrichedFeatureSection({
    required this.horizonM5,
    required this.byCorrectionExcursion,
    required this.byCorrectionDuration,
    required this.byRealignmentBody,
    required this.byDirectionalClose,
    required this.eligibleByCorrectionExcursion,
    required this.eligibleByCorrectionDuration,
    required this.eligibleByRealignmentBody,
    required this.eligibleByDirectionalClose,
  });
  final int horizonM5;
  final Map<StrategyBCorrectionExcursionBucket, StrategyBEnrichedFeatureSummary>
  byCorrectionExcursion,
  eligibleByCorrectionExcursion;
  final Map<StrategyBCorrectionDurationBucket, StrategyBEnrichedFeatureSummary>
  byCorrectionDuration,
  eligibleByCorrectionDuration;
  final Map<StrategyBRealignmentBodyBucket, StrategyBEnrichedFeatureSummary>
  byRealignmentBody,
  eligibleByRealignmentBody;
  final Map<StrategyBDirectionalCloseBucket, StrategyBEnrichedFeatureSummary>
  byDirectionalClose,
  eligibleByDirectionalClose;
}

final class StrategyBEnrichedFeatureSummary {
  const StrategyBEnrichedFeatureSummary({
    required this.candidates,
    required this.eligible,
    required this.continuation,
    required this.rejection,
    required this.unresolved,
  });
  final int candidates, eligible, continuation, rejection, unresolved;
  int get resolved => continuation + rejection;
  double? get continuationRate =>
      resolved == 0 ? null : continuation / resolved;
}
