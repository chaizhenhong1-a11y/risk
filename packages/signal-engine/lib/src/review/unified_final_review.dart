import '../candidate/unified_candidate_pool.dart';

enum FinalReviewDecision { approved, rejected, conflict, noTrade }

enum FinalReviewReason {
  approved,
  candidateConflict,
  invalidEntry,
  invalidStopLoss,
  invalidTakeProfit,
  insufficientRiskReward,
  invalidStructure,
  excessiveVolatilityRisk,
  newsMacroBlocked,
  portfolioRiskBlocked,
}

final class FinalReviewContext {
  const FinalReviewContext({
    this.structureValid = true,
    this.volatilityRiskAcceptable = true,
    this.newsMacroClear = true,
    this.portfolioRiskAcceptable = true,
  });

  final bool structureValid;
  final bool volatilityRiskAcceptable;
  final bool newsMacroClear;
  final bool portfolioRiskAcceptable;
}

final class FinalReviewAnalysis {
  const FinalReviewAnalysis({
    required this.decision,
    required this.reasons,
    required this.poolItem,
  });

  final FinalReviewDecision decision;
  final List<FinalReviewReason> reasons;
  final UnifiedCandidatePoolItem poolItem;

  bool get isApproved => decision == FinalReviewDecision.approved;
}

/// Strategy-neutral final-review foundation.
///
/// This layer does not alter Strategy A/B/C5 rules and does not introduce a
/// daily signal quota. It validates already-formed candidates before they may
/// proceed to notification/paper execution.
///
/// News/macro and portfolio checks are explicit inputs so future integrations
/// can block a candidate without coupling external services to this domain.
final class UnifiedFinalReviewer {
  const UnifiedFinalReviewer({this.minimumRiskReward = 2.0});

  final double minimumRiskReward;

  FinalReviewAnalysis review({
    required UnifiedCandidatePoolItem item,
    FinalReviewContext context = const FinalReviewContext(),
  }) {
    if (item.hasConflict) {
      return FinalReviewAnalysis(
        decision: FinalReviewDecision.conflict,
        reasons: const [FinalReviewReason.candidateConflict],
        poolItem: item,
      );
    }

    if (item.candidates.isEmpty) {
      return FinalReviewAnalysis(
        decision: FinalReviewDecision.noTrade,
        reasons: const [FinalReviewReason.invalidEntry],
        poolItem: item,
      );
    }

    final reasons = <FinalReviewReason>[];

    for (final candidate in item.candidates) {
      if (!candidate.entryPrice.isFinite || candidate.entryPrice <= 0) {
        reasons.add(FinalReviewReason.invalidEntry);
      }
      if (!candidate.stopLoss.isFinite || candidate.stopLoss <= 0) {
        reasons.add(FinalReviewReason.invalidStopLoss);
      }
      if (!candidate.takeProfit.isFinite || candidate.takeProfit <= 0) {
        reasons.add(FinalReviewReason.invalidTakeProfit);
      }
      if (!candidate.riskReward.isFinite ||
          candidate.riskReward < minimumRiskReward) {
        reasons.add(FinalReviewReason.insufficientRiskReward);
      }
    }

    if (!context.structureValid) {
      reasons.add(FinalReviewReason.invalidStructure);
    }
    if (!context.volatilityRiskAcceptable) {
      reasons.add(FinalReviewReason.excessiveVolatilityRisk);
    }
    if (!context.newsMacroClear) {
      reasons.add(FinalReviewReason.newsMacroBlocked);
    }
    if (!context.portfolioRiskAcceptable) {
      reasons.add(FinalReviewReason.portfolioRiskBlocked);
    }

    final uniqueReasons = reasons.toSet().toList(growable: false);
    if (uniqueReasons.isNotEmpty) {
      return FinalReviewAnalysis(
        decision: FinalReviewDecision.rejected,
        reasons: uniqueReasons,
        poolItem: item,
      );
    }

    return FinalReviewAnalysis(
      decision: FinalReviewDecision.approved,
      reasons: const [FinalReviewReason.approved],
      poolItem: item,
    );
  }
}
