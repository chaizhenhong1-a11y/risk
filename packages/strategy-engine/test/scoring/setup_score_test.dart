import 'package:strategy_engine/strategy_engine.dart';
import 'package:test/test.dart';

void main() {
  const scorer = SetupScorer();

  group('SetupScorePolicy', () {
    test('defensively copies configured weights', () {
      final source = <SetupEvidenceType, double>{
        SetupEvidenceType.rejectionConfirmation: 5,
      };
      final policy = SetupScorePolicy(evidenceWeights: source);

      source[SetupEvidenceType.rejectionConfirmation] = 99;

      expect(policy.weightFor(SetupEvidenceType.rejectionConfirmation), 5);
    });

    test('missing weight defaults to zero', () {
      final policy = SetupScorePolicy(evidenceWeights: const {});

      expect(policy.weightFor(SetupEvidenceType.directionalM15Structure), 0);
    });

    test('rejects negative weight', () {
      expect(
        () => SetupScorePolicy(
          evidenceWeights: const {
            SetupEvidenceType.directionalM15Structure: -1,
          },
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-finite weight', () {
      expect(
        () => SetupScorePolicy(
          evidenceWeights: const {
            SetupEvidenceType.directionalM15Structure: double.infinity,
          },
        ),
        throwsArgumentError,
      );
    });
  });

  group('SetupScorer', () {
    test('scores only present evidence using configured weights', () {
      final snapshot = _snapshot(
        evidence: const [
          SetupEvidence(
            type: SetupEvidenceType.directionalM15Structure,
            present: true,
          ),
          SetupEvidence(
            type: SetupEvidenceType.directionalM5Confirmation,
            present: false,
          ),
          SetupEvidence(
            type: SetupEvidenceType.rejectionConfirmation,
            present: true,
          ),
        ],
      );

      final result = scorer.score(
        snapshot: snapshot,
        policy: SetupScorePolicy(
          evidenceWeights: const {
            SetupEvidenceType.directionalM15Structure: 7,
            SetupEvidenceType.directionalM5Confirmation: 3,
            SetupEvidenceType.rejectionConfirmation: 5,
          },
        ),
      );

      expect(result.earnedPoints, 12);
      expect(result.availablePoints, 15);
      expect(
        result.contributionFor(SetupEvidenceType.directionalM15Structure),
        7,
      );
      expect(
        result.contributionFor(SetupEvidenceType.directionalM5Confirmation),
        0,
      );
      expect(
        result.contributionFor(SetupEvidenceType.rejectionConfirmation),
        5,
      );
    });

    test('changing policy changes score without changing snapshot', () {
      final snapshot = _snapshot(
        evidence: const [
          SetupEvidence(
            type: SetupEvidenceType.directionalM15Structure,
            present: true,
          ),
        ],
      );

      final low = scorer.score(
        snapshot: snapshot,
        policy: SetupScorePolicy(
          evidenceWeights: const {SetupEvidenceType.directionalM15Structure: 2},
        ),
      );
      final high = scorer.score(
        snapshot: snapshot,
        policy: SetupScorePolicy(
          evidenceWeights: const {SetupEvidenceType.directionalM15Structure: 9},
        ),
      );

      expect(low.earnedPoints, 2);
      expect(high.earnedPoints, 9);
    });

    test('blocked setup remains blocked and scorer does not override Gate', () {
      final snapshot = SetupEvidenceSnapshot(
        eligibility: SetupEligibility.blocked,
        blockReason: SetupBlockReason.noTradeBias,
        evidence: const [
          SetupEvidence(
            type: SetupEvidenceType.rejectionConfirmation,
            present: true,
          ),
        ],
        d1ContextAlignment: D1ContextAlignment.aligned,
        keyLevelQuality: KeyLevelQuality.wellTested,
      );

      final result = scorer.score(
        snapshot: snapshot,
        policy: SetupScorePolicy(
          evidenceWeights: const {SetupEvidenceType.rejectionConfirmation: 10},
        ),
      );

      expect(snapshot.isEligible, isFalse);
      expect(snapshot.blockReason, SetupBlockReason.noTradeBias);
      expect(result.earnedPoints, 10);
    });

    test('contributions map is immutable', () {
      final result = scorer.score(
        snapshot: _snapshot(evidence: const []),
        policy: SetupScorePolicy(
          evidenceWeights: const {SetupEvidenceType.rejectionConfirmation: 5},
        ),
      );

      expect(
        () =>
            result.contributions[SetupEvidenceType.rejectionConfirmation] = 99,
        throwsUnsupportedError,
      );
    });
  });
}

SetupEvidenceSnapshot _snapshot({required List<SetupEvidence> evidence}) =>
    SetupEvidenceSnapshot(
      eligibility: SetupEligibility.eligible,
      blockReason: null,
      evidence: evidence,
      d1ContextAlignment: D1ContextAlignment.unavailable,
      keyLevelQuality: KeyLevelQuality.unavailable,
    );
