import '../bias/multi_timeframe_bias.dart';
import '../confirmation/pullback_confirmation.dart';
import '../pullback/pullback_detector.dart';
import 'd1_context_evidence.dart';
import 'entry_confirmation_evidence.dart';
import 'key_level_quality_evidence.dart';
import 'liquidity_evidence.dart';
import 'market_structure_evidence.dart';

enum SetupEligibility { blocked, eligible }

enum SetupBlockReason { noTradeBias, pullbackNotPresent }

enum SetupEvidenceType {
  directionalBias,
  pullbackAtDirectionalLevel,
  rejectionConfirmation,
  directionalLevelSweep,
  directionalPoolSweep,
  directionalM15Structure,
  directionalM5Confirmation,
  keyLevelQuality,
  directionalD1Context,
}

final class SetupEvidence {
  const SetupEvidence({required this.type, required this.present});

  final SetupEvidenceType type;
  final bool present;
}

final class SetupEvaluation {
  SetupEvaluation({
    required this.eligibility,
    required this.blockReason,
    required Iterable<SetupEvidence> evidence,
  }) : evidence = List.unmodifiable(evidence);

  final SetupEligibility eligibility;
  final SetupBlockReason? blockReason;
  final List<SetupEvidence> evidence;

  bool get isEligible => eligibility == SetupEligibility.eligible;

  bool hasEvidence(SetupEvidenceType type) =>
      evidence.any((item) => item.type == type && item.present);

  int get presentEvidenceCount => evidence.where((item) => item.present).length;
}

/// Keeps eligibility gates separate from quality evidence.
///
/// Current hard requirements:
/// - directional BUY/SELL bias;
/// - valid directional pullback.
///
/// Rejection, liquidity, M15 structure, M5 confirmation, key-level quality,
/// and D1 context are soft evidence and can later be reclassified by backtests.
final class SetupEvaluator {
  const SetupEvaluator();

  SetupEvaluation evaluate({
    required TradingBias bias,
    required PullbackAnalysis pullback,
    required PullbackConfirmation confirmation,
    Iterable<LiquidityEvidence> liquidityEvidence = const [],
    MarketStructureEvidence? marketStructureEvidence,
    EntryConfirmationEvidence? entryConfirmationEvidence,
    KeyLevelQualityEvidence? keyLevelQualityEvidence,
    D1ContextEvidence? d1ContextEvidence,
  }) {
    final directionalBias = bias != TradingBias.noTrade;
    final pullbackPresent = pullback.hasPullback;
    final rejectionConfirmed = confirmation.isConfirmed;
    final liquidity = liquidityEvidence.toList(growable: false);

    bool liquidityPresent(LiquidityEvidenceType type) =>
        liquidity.any((item) => item.type == type && item.present);

    final evidence = [
      SetupEvidence(
        type: SetupEvidenceType.directionalBias,
        present: directionalBias,
      ),
      SetupEvidence(
        type: SetupEvidenceType.pullbackAtDirectionalLevel,
        present: pullbackPresent,
      ),
      SetupEvidence(
        type: SetupEvidenceType.rejectionConfirmation,
        present: rejectionConfirmed,
      ),
      SetupEvidence(
        type: SetupEvidenceType.directionalLevelSweep,
        present: liquidityPresent(LiquidityEvidenceType.directionalLevelSweep),
      ),
      SetupEvidence(
        type: SetupEvidenceType.directionalPoolSweep,
        present: liquidityPresent(LiquidityEvidenceType.directionalPoolSweep),
      ),
      SetupEvidence(
        type: SetupEvidenceType.directionalM15Structure,
        present: marketStructureEvidence?.present ?? false,
      ),
      SetupEvidence(
        type: SetupEvidenceType.directionalM5Confirmation,
        present: entryConfirmationEvidence?.present ?? false,
      ),
      SetupEvidence(
        type: SetupEvidenceType.keyLevelQuality,
        present: keyLevelQualityEvidence?.present ?? false,
      ),
      SetupEvidence(
        type: SetupEvidenceType.directionalD1Context,
        present: d1ContextEvidence?.present ?? false,
      ),
    ];

    if (!directionalBias) {
      return SetupEvaluation(
        eligibility: SetupEligibility.blocked,
        blockReason: SetupBlockReason.noTradeBias,
        evidence: evidence,
      );
    }

    if (!pullbackPresent) {
      return SetupEvaluation(
        eligibility: SetupEligibility.blocked,
        blockReason: SetupBlockReason.pullbackNotPresent,
        evidence: evidence,
      );
    }

    return SetupEvaluation(
      eligibility: SetupEligibility.eligible,
      blockReason: null,
      evidence: evidence,
    );
  }
}
