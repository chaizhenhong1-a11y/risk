import 'package:risk_engine/risk_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';

enum SignalCandidateDirection { buy, sell, noTrade }

enum SignalCandidateStatus { blocked, qualified }

enum SignalCandidateBlockReason {
  strategySetupBlocked,
  riskPlanBlocked,
  noDirectionalBias,
}

/// First Phase 6 bridge between Strategy Engine and Risk Engine.
///
/// A candidate is not yet a notification or executable order. It preserves the
/// deterministic setup snapshot, research score, and complete risk plan so the
/// later lifecycle layer can reason from one immutable object.
final class SignalCandidate {
  const SignalCandidate._({
    required this.direction,
    required this.status,
    required this.setupSnapshot,
    required this.setupScore,
    required this.riskPlan,
    this.blockReason,
  });

  const SignalCandidate.qualified({
    required SignalCandidateDirection direction,
    required SetupEvidenceSnapshot setupSnapshot,
    required SetupScoreResult setupScore,
    required RiskPlanAnalysis riskPlan,
  }) : this._(
         direction: direction,
         status: SignalCandidateStatus.qualified,
         setupSnapshot: setupSnapshot,
         setupScore: setupScore,
         riskPlan: riskPlan,
       );

  const SignalCandidate.blocked({
    required SignalCandidateDirection direction,
    required SignalCandidateBlockReason blockReason,
    required SetupEvidenceSnapshot setupSnapshot,
    required SetupScoreResult setupScore,
    required RiskPlanAnalysis riskPlan,
  }) : this._(
         direction: direction,
         status: SignalCandidateStatus.blocked,
         blockReason: blockReason,
         setupSnapshot: setupSnapshot,
         setupScore: setupScore,
         riskPlan: riskPlan,
       );

  final SignalCandidateDirection direction;
  final SignalCandidateStatus status;
  final SignalCandidateBlockReason? blockReason;
  final SetupEvidenceSnapshot setupSnapshot;
  final SetupScoreResult setupScore;
  final RiskPlanAnalysis riskPlan;

  bool get isQualified => status == SignalCandidateStatus.qualified;
}

/// Combines already-computed Phase 4 and Phase 5 outputs.
///
/// Hard requirements remain authoritative:
/// - blocked strategy setup -> blocked candidate
/// - blocked risk plan -> blocked candidate
/// - no directional bias -> blocked candidate
///
/// The research score is retained for ranking/backtesting but deliberately does
/// not become a new hard gate in this increment.
final class SignalCandidateBuilder {
  const SignalCandidateBuilder();

  SignalCandidate build({
    required TradingBias bias,
    required SetupEvidenceSnapshot setupSnapshot,
    required SetupScoreResult setupScore,
    required RiskPlanAnalysis riskPlan,
  }) {
    final direction = _directionFor(bias);

    if (!setupSnapshot.isEligible) {
      return SignalCandidate.blocked(
        direction: direction,
        blockReason: SignalCandidateBlockReason.strategySetupBlocked,
        setupSnapshot: setupSnapshot,
        setupScore: setupScore,
        riskPlan: riskPlan,
      );
    }

    if (!riskPlan.isEligible) {
      return SignalCandidate.blocked(
        direction: direction,
        blockReason: SignalCandidateBlockReason.riskPlanBlocked,
        setupSnapshot: setupSnapshot,
        setupScore: setupScore,
        riskPlan: riskPlan,
      );
    }

    if (bias == TradingBias.noTrade) {
      return SignalCandidate.blocked(
        direction: direction,
        blockReason: SignalCandidateBlockReason.noDirectionalBias,
        setupSnapshot: setupSnapshot,
        setupScore: setupScore,
        riskPlan: riskPlan,
      );
    }

    return SignalCandidate.qualified(
      direction: direction,
      setupSnapshot: setupSnapshot,
      setupScore: setupScore,
      riskPlan: riskPlan,
    );
  }

  SignalCandidateDirection _directionFor(TradingBias bias) => switch (bias) {
    TradingBias.buy => SignalCandidateDirection.buy,
    TradingBias.sell => SignalCandidateDirection.sell,
    TradingBias.noTrade => SignalCandidateDirection.noTrade,
  };
}
