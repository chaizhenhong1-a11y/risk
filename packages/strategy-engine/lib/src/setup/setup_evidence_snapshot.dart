import 'd1_context_evidence.dart';
import 'key_level_quality_evidence.dart';
import 'setup_evaluation.dart';

/// Immutable, structured snapshot of all strategy facts currently used by the
/// setup layer.
///
/// This object intentionally contains no weights, score, grade, probability,
/// Entry, SL, TP, or final signal decision. It is the stable data boundary that
/// later scoring and backtesting can consume without rewriting the evidence
/// collectors.
final class SetupEvidenceSnapshot {
  SetupEvidenceSnapshot({
    required this.eligibility,
    required this.blockReason,
    required Iterable<SetupEvidence> evidence,
    required this.d1ContextAlignment,
    required this.keyLevelQuality,
  }) : evidence = List.unmodifiable(evidence);

  factory SetupEvidenceSnapshot.fromEvaluation({
    required SetupEvaluation evaluation,
    D1ContextEvidence? d1ContextEvidence,
    KeyLevelQualityEvidence? keyLevelQualityEvidence,
  }) {
    return SetupEvidenceSnapshot(
      eligibility: evaluation.eligibility,
      blockReason: evaluation.blockReason,
      evidence: evaluation.evidence,
      d1ContextAlignment:
          d1ContextEvidence?.alignment ?? D1ContextAlignment.unavailable,
      keyLevelQuality:
          keyLevelQualityEvidence?.quality ?? KeyLevelQuality.unavailable,
    );
  }

  final SetupEligibility eligibility;
  final SetupBlockReason? blockReason;
  final List<SetupEvidence> evidence;

  /// Preserves aligned / neutral / opposed / unavailable instead of collapsing
  /// D1 context into a single boolean.
  final D1ContextAlignment d1ContextAlignment;

  /// Preserves weak / established / wellTested / unavailable for later
  /// backtest-driven weighting or Gate promotion.
  final KeyLevelQuality keyLevelQuality;

  bool get isEligible => eligibility == SetupEligibility.eligible;

  bool hasEvidence(SetupEvidenceType type) =>
      evidence.any((item) => item.type == type && item.present);

  bool isEvidencePresent(SetupEvidenceType type) => hasEvidence(type);

  int get presentEvidenceCount => evidence.where((item) => item.present).length;

  Map<SetupEvidenceType, bool> get evidencePresence =>
      Map.unmodifiable({for (final item in evidence) item.type: item.present});
}
