import 'strategy_b_candidate_research_diagnostics.dart';
import 'strategy_b_research_snapshot.dart';
import 'strategy_b_v2_hypothesis.dart';

final class StrategyBV2ForwardSummary {
  const StrategyBV2ForwardSummary({
    required this.horizonM5,
    required this.candidates,
    required this.continuation,
    required this.rejection,
    required this.unresolved,
  });

  final int horizonM5;
  final int candidates;
  final int continuation;
  final int rejection;
  final int unresolved;

  int get resolved => continuation + rejection;
  double? get resolvedContinuationRate =>
      resolved == 0 ? null : continuation / resolved;
}

/// Increment 098 validator for the hypothesis frozen in Increment 097.
///
/// This class only classifies fresh replay observations. It never changes
/// Strategy B candidate generation, risk rules, or the frozen body threshold.
final class StrategyBV2Validation {
  const StrategyBV2Validation();

  bool matchesRecord(StrategyBResearchSnapshotRecord record) {
    return record.riskEligible &&
        StrategyBV2Hypothesis.matchesRealignmentBody(
          record.m15RealignmentBodyAtr,
        );
  }

  void assertBaselineIntegrity({
    required int candidateCount,
    required int riskEligibleCount,
  }) {
    if (candidateCount !=
            StrategyBV2ValidationPlan.expectedBaselineCandidates ||
        riskEligibleCount !=
            StrategyBV2ValidationPlan.expectedBaselineRiskEligible) {
      throw StateError(
        'Strategy B baseline integrity failed: '
        'candidates=$candidateCount '
        'riskEligible=$riskEligibleCount; expected '
        '${StrategyBV2ValidationPlan.expectedBaselineCandidates}/'
        '${StrategyBV2ValidationPlan.expectedBaselineRiskEligible}.',
      );
    }
  }

  StrategyBV2ForwardSummary summarize({
    required int horizonM5,
    required List<StrategyBResearchSnapshotRecord> records,
    required List<StrategyBCandidateResearchSample> samples,
  }) {
    if (records.length != samples.length) {
      throw StateError(
        'Fresh replay record/sample alignment failed for $horizonM5 M5: '
        '${records.length} records vs ${samples.length} samples.',
      );
    }
    var candidates = 0;
    var continuation = 0;
    var rejection = 0;
    var unresolved = 0;
    for (var i = 0; i < records.length; i++) {
      if (!matchesRecord(records[i])) continue;
      candidates++;
      switch (samples[i].outcome) {
        case StrategyBCandidateOutcome.continuation:
          continuation++;
        case StrategyBCandidateOutcome.rejection:
          rejection++;
        case StrategyBCandidateOutcome.unresolved:
          unresolved++;
      }
    }
    return StrategyBV2ForwardSummary(
      horizonM5: horizonM5,
      candidates: candidates,
      continuation: continuation,
      rejection: rejection,
      unresolved: unresolved,
    );
  }
}
