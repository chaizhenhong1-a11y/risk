import 'package:strategy_engine/strategy_engine.dart';
import 'package:test/test.dart';

void main() {
  group('SetupScoreProfile', () {
    test('requires non-empty identity fields', () {
      expect(
        () => SetupScoreProfile(
          id: '',
          version: 'v1',
          description: 'test',
          evidenceWeights: const {},
        ),
        throwsArgumentError,
      );

      expect(
        () => SetupScoreProfile(
          id: 'test',
          version: '',
          description: 'test',
          evidenceWeights: const {},
        ),
        throwsArgumentError,
      );

      expect(
        () => SetupScoreProfile(
          id: 'test',
          version: 'v1',
          description: '',
          evidenceWeights: const {},
        ),
        throwsArgumentError,
      );
    });

    test('provides stable profile key', () {
      final profile = SetupScoreProfile(
        id: 'structure-heavy',
        version: 'v3',
        description: 'Research candidate',
        evidenceWeights: const {},
      );

      expect(profile.profileKey, 'structure-heavy@v3');
    });

    test('delegates weight validation to SetupScorePolicy', () {
      expect(
        () => SetupScoreProfile(
          id: 'invalid',
          version: 'v1',
          description: 'Invalid research profile',
          evidenceWeights: const {SetupEvidenceType.rejectionConfirmation: -1},
        ),
        throwsArgumentError,
      );
    });
  });

  group('baselineResearchV1', () {
    final profile = SetupScoreProfiles.baselineResearchV1;

    test('is explicitly versioned as research configuration', () {
      expect(profile.profileKey, 'baseline-research@v1');
      expect(profile.description, contains('Not production-calibrated'));
    });

    test('does not double-count current hard requirements', () {
      expect(profile.policy.weightFor(SetupEvidenceType.directionalBias), 0);
      expect(
        profile.policy.weightFor(SetupEvidenceType.pullbackAtDirectionalLevel),
        0,
      );
    });

    test('assigns research weights only to current soft evidence', () {
      expect(
        profile.policy.weightFor(SetupEvidenceType.rejectionConfirmation),
        15,
      );
      expect(
        profile.policy.weightFor(SetupEvidenceType.directionalLevelSweep),
        10,
      );
      expect(
        profile.policy.weightFor(SetupEvidenceType.directionalPoolSweep),
        10,
      );
      expect(
        profile.policy.weightFor(SetupEvidenceType.directionalM15Structure),
        20,
      );
      expect(
        profile.policy.weightFor(SetupEvidenceType.directionalM5Confirmation),
        15,
      );
      expect(profile.policy.weightFor(SetupEvidenceType.keyLevelQuality), 15);
      expect(
        profile.policy.weightFor(SetupEvidenceType.directionalD1Context),
        15,
      );
    });

    test('research profile has a transparent 100-point evidence budget', () {
      final total = SetupEvidenceType.values.fold<double>(
        0,
        (sum, type) => sum + profile.policy.weightFor(type),
      );

      expect(total, 100);
    });
  });
}
