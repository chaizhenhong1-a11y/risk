import 'package:strategy_engine/strategy_engine.dart';
import 'package:test/test.dart';

void main() {
  group('SetupEvidenceSnapshot', () {
    test('captures eligibility, evidence, and detailed quality states', () {
      final evaluation = SetupEvaluation(
        eligibility: SetupEligibility.eligible,
        blockReason: null,
        evidence: const [
          SetupEvidence(type: SetupEvidenceType.directionalBias, present: true),
          SetupEvidence(
            type: SetupEvidenceType.directionalM15Structure,
            present: true,
          ),
          SetupEvidence(
            type: SetupEvidenceType.directionalM5Confirmation,
            present: false,
          ),
        ],
      );

      final snapshot = SetupEvidenceSnapshot.fromEvaluation(
        evaluation: evaluation,
        d1ContextEvidence: const D1ContextEvidence(
          alignment: D1ContextAlignment.opposed,
        ),
        keyLevelQualityEvidence: const KeyLevelQualityEvidence(
          quality: KeyLevelQuality.wellTested,
        ),
      );

      expect(snapshot.isEligible, isTrue);
      expect(snapshot.blockReason, isNull);
      expect(snapshot.d1ContextAlignment, D1ContextAlignment.opposed);
      expect(snapshot.keyLevelQuality, KeyLevelQuality.wellTested);
      expect(
        snapshot.hasEvidence(SetupEvidenceType.directionalM15Structure),
        isTrue,
      );
      expect(
        snapshot.hasEvidence(SetupEvidenceType.directionalM5Confirmation),
        isFalse,
      );
      expect(snapshot.presentEvidenceCount, 2);
    });

    test(
      'uses explicit unavailable states when detailed evidence is absent',
      () {
        final evaluation = SetupEvaluation(
          eligibility: SetupEligibility.blocked,
          blockReason: SetupBlockReason.noTradeBias,
          evidence: const [],
        );

        final snapshot = SetupEvidenceSnapshot.fromEvaluation(
          evaluation: evaluation,
        );

        expect(snapshot.isEligible, isFalse);
        expect(snapshot.blockReason, SetupBlockReason.noTradeBias);
        expect(snapshot.d1ContextAlignment, D1ContextAlignment.unavailable);
        expect(snapshot.keyLevelQuality, KeyLevelQuality.unavailable);
      },
    );

    test(
      'copies evidence so later source-list mutation cannot alter snapshot',
      () {
        final source = <SetupEvidence>[
          const SetupEvidence(
            type: SetupEvidenceType.directionalBias,
            present: true,
          ),
        ];

        final snapshot = SetupEvidenceSnapshot(
          eligibility: SetupEligibility.eligible,
          blockReason: null,
          evidence: source,
          d1ContextAlignment: D1ContextAlignment.aligned,
          keyLevelQuality: KeyLevelQuality.established,
        );

        source.add(
          const SetupEvidence(
            type: SetupEvidenceType.rejectionConfirmation,
            present: true,
          ),
        );

        expect(snapshot.evidence, hasLength(1));
        expect(snapshot.presentEvidenceCount, 1);
      },
    );

    test('snapshot evidence list is immutable', () {
      final snapshot = SetupEvidenceSnapshot(
        eligibility: SetupEligibility.eligible,
        blockReason: null,
        evidence: const [
          SetupEvidence(type: SetupEvidenceType.directionalBias, present: true),
        ],
        d1ContextAlignment: D1ContextAlignment.aligned,
        keyLevelQuality: KeyLevelQuality.established,
      );

      expect(
        () => snapshot.evidence.add(
          const SetupEvidence(
            type: SetupEvidenceType.rejectionConfirmation,
            present: true,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('evidence presence map is immutable and preserves false states', () {
      final snapshot = SetupEvidenceSnapshot(
        eligibility: SetupEligibility.eligible,
        blockReason: null,
        evidence: const [
          SetupEvidence(type: SetupEvidenceType.directionalBias, present: true),
          SetupEvidence(
            type: SetupEvidenceType.directionalM5Confirmation,
            present: false,
          ),
        ],
        d1ContextAlignment: D1ContextAlignment.neutral,
        keyLevelQuality: KeyLevelQuality.weak,
      );

      final presence = snapshot.evidencePresence;

      expect(presence[SetupEvidenceType.directionalBias], isTrue);
      expect(presence[SetupEvidenceType.directionalM5Confirmation], isFalse);
      expect(
        () => presence[SetupEvidenceType.rejectionConfirmation] = true,
        throwsUnsupportedError,
      );
    });
  });
}
