import '../setup/setup_evaluation.dart';
import '../setup/setup_evidence_snapshot.dart';

/// Configurable scoring policy.
///
/// Weights are data, not strategy branching logic. Backtesting can therefore
/// replace them without rewriting evidence collection or setup eligibility.
final class SetupScorePolicy {
  SetupScorePolicy({required Map<SetupEvidenceType, double> evidenceWeights})
    : evidenceWeights = Map.unmodifiable(evidenceWeights) {
    for (final entry in this.evidenceWeights.entries) {
      if (!entry.value.isFinite || entry.value < 0) {
        throw ArgumentError.value(
          entry.value,
          'evidenceWeights[${entry.key.name}]',
          'Weight must be finite and non-negative.',
        );
      }
    }
  }

  final Map<SetupEvidenceType, double> evidenceWeights;

  double weightFor(SetupEvidenceType type) => evidenceWeights[type] ?? 0;
}

/// Transparent result of applying a scoring policy to one evidence snapshot.
///
/// `earnedPoints` is not a win probability. No grade or signal threshold is
/// defined at this stage.
final class SetupScoreResult {
  SetupScoreResult({
    required this.earnedPoints,
    required this.availablePoints,
    required Map<SetupEvidenceType, double> contributions,
  }) : contributions = Map.unmodifiable(contributions);

  final double earnedPoints;
  final double availablePoints;
  final Map<SetupEvidenceType, double> contributions;

  double contributionFor(SetupEvidenceType type) => contributions[type] ?? 0;
}

/// Deterministic scorer for already-collected evidence.
///
/// Eligibility remains separate: a blocked setup can be scored for research,
/// but scoring never overrides a Gate or turns a blocked setup into eligible.
final class SetupScorer {
  const SetupScorer();

  SetupScoreResult score({
    required SetupEvidenceSnapshot snapshot,
    required SetupScorePolicy policy,
  }) {
    final contributions = <SetupEvidenceType, double>{};
    var earned = 0.0;
    var available = 0.0;

    for (final type in SetupEvidenceType.values) {
      final weight = policy.weightFor(type);
      available += weight;

      final contribution = snapshot.hasEvidence(type) ? weight : 0.0;
      contributions[type] = contribution;
      earned += contribution;
    }

    return SetupScoreResult(
      earnedPoints: earned,
      availablePoints: available,
      contributions: contributions,
    );
  }
}
