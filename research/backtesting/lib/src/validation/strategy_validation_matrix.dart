import 'unified_strategy_expectancy_audit.dart';

enum ValidationEvidenceStatus { pass, fail, pending, notEvaluated }

enum ProductionEligibility { eligibleForPaperForward, researchOnly }

final class StrategyValidationEvidence {
  const StrategyValidationEvidence({
    required this.strategy,
    required this.historicalExpectancy,
    required this.chronologicalStability,
    required this.sampleSufficiency,
    this.costStress = ValidationEvidenceStatus.notEvaluated,
    this.unseenForward = ValidationEvidenceStatus.pending,
  });

  factory StrategyValidationEvidence.fromHistoricalAudit(
    StrategyAuditVerdict verdict, {
    ValidationEvidenceStatus costStress = ValidationEvidenceStatus.notEvaluated,
    ValidationEvidenceStatus unseenForward = ValidationEvidenceStatus.pending,
  }) {
    return StrategyValidationEvidence(
      strategy: verdict.strategy,
      historicalExpectancy:
          verdict.hasPositiveExpectancy && verdict.hasProfitFactorAboveOne
          ? ValidationEvidenceStatus.pass
          : ValidationEvidenceStatus.fail,
      chronologicalStability:
          verdict.hasPositiveFirstHalf && verdict.hasPositiveSecondHalf
          ? ValidationEvidenceStatus.pass
          : ValidationEvidenceStatus.fail,
      sampleSufficiency: verdict.meetsResolvedSampleFloor
          ? ValidationEvidenceStatus.pass
          : ValidationEvidenceStatus.fail,
      costStress: costStress,
      unseenForward: unseenForward,
    );
  }

  final AuditedStrategy strategy;
  final ValidationEvidenceStatus historicalExpectancy;
  final ValidationEvidenceStatus chronologicalStability;
  final ValidationEvidenceStatus sampleSufficiency;
  final ValidationEvidenceStatus costStress;
  final ValidationEvidenceStatus unseenForward;

  /// Historical success can only earn paper/forward observation.
  /// Production/live-money eligibility is intentionally not represented here.
  ProductionEligibility get eligibility {
    final historicalPass =
        historicalExpectancy == ValidationEvidenceStatus.pass &&
        chronologicalStability == ValidationEvidenceStatus.pass &&
        sampleSufficiency == ValidationEvidenceStatus.pass;

    return historicalPass
        ? ProductionEligibility.eligibleForPaperForward
        : ProductionEligibility.researchOnly;
  }

  bool get hasUnseenForwardPass =>
      unseenForward == ValidationEvidenceStatus.pass;
}

final class StrategyValidationMatrix {
  const StrategyValidationMatrix(this.rows);

  final List<StrategyValidationEvidence> rows;

  StrategyValidationEvidence forStrategy(AuditedStrategy strategy) =>
      rows.singleWhere((row) => row.strategy == strategy);
}
