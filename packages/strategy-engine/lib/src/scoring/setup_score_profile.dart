import '../setup/setup_evaluation.dart';
import 'setup_score.dart';

/// Named, versioned research configuration for setup scoring.
///
/// Profiles are deliberately separate from the scorer so backtesting can
/// compare multiple hypotheses without changing strategy code.
final class SetupScoreProfile {
  SetupScoreProfile({
    required this.id,
    required this.version,
    required this.description,
    required Map<SetupEvidenceType, double> evidenceWeights,
  }) : policy = SetupScorePolicy(evidenceWeights: evidenceWeights) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Profile id must not be empty.');
    }
    if (version.trim().isEmpty) {
      throw ArgumentError.value(
        version,
        'version',
        'Profile version must not be empty.',
      );
    }
    if (description.trim().isEmpty) {
      throw ArgumentError.value(
        description,
        'description',
        'Profile description must not be empty.',
      );
    }
  }

  final String id;
  final String version;
  final String description;
  final SetupScorePolicy policy;

  String get profileKey => '$id@$version';
}

/// Research-only starting profile.
///
/// These values are hypotheses for later backtesting, not validated production
/// weights and not probabilities. Gate facts are intentionally assigned zero
/// here because setup eligibility already handles them separately.
final class SetupScoreProfiles {
  const SetupScoreProfiles._();

  static final SetupScoreProfile baselineResearchV1 = SetupScoreProfile(
    id: 'baseline-research',
    version: 'v1',
    description:
        'Initial research hypothesis for comparing strategy evidence in '
        'backtests. Not production-calibrated.',
    evidenceWeights: const {
      SetupEvidenceType.directionalBias: 0,
      SetupEvidenceType.pullbackAtDirectionalLevel: 0,
      SetupEvidenceType.rejectionConfirmation: 15,
      SetupEvidenceType.directionalLevelSweep: 10,
      SetupEvidenceType.directionalPoolSweep: 10,
      SetupEvidenceType.directionalM15Structure: 20,
      SetupEvidenceType.directionalM5Confirmation: 15,
      SetupEvidenceType.keyLevelQuality: 15,
      SetupEvidenceType.directionalD1Context: 15,
    },
  );
}
