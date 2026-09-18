import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_expectancy_validator.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_validation_matrix.dart';
import 'package:tradeforge_backtesting/src/validation/unified_strategy_expectancy_audit.dart';

void main() {
  StrategyAuditVerdict verdict({
    required AuditedStrategy strategy,
    required bool sample,
    required bool expectancy,
    required bool pf,
    required bool first,
    required bool second,
  }) => StrategyAuditVerdict(
    strategy: strategy,
    report: const StrategyExpectancyReport(
      total: 0,
      resolved: 0,
      wins: 0,
      losses: 0,
      expired: 0,
      ambiguous: 0,
      winRate: 0,
      averageWinR: 0,
      averageLossR: 0,
      grossExpectancyR: 0,
      netExpectancyR: 0,
      profitFactor: 0,
      maxLosingStreak: 0,
      firstHalfNetExpectancyR: 0,
      secondHalfNetExpectancyR: 0,
    ),
    meetsResolvedSampleFloor: sample,
    hasPositiveExpectancy: expectancy,
    hasProfitFactorAboveOne: pf,
    hasPositiveFirstHalf: first,
    hasPositiveSecondHalf: second,
  );

  test(
    'historical pass earns paper-forward eligibility but not unseen pass',
    () {
      final row = StrategyValidationEvidence.fromHistoricalAudit(
        verdict(
          strategy: AuditedStrategy.strategyA,
          sample: true,
          expectancy: true,
          pf: true,
          first: true,
          second: true,
        ),
      );

      expect(row.historicalExpectancy, ValidationEvidenceStatus.pass);
      expect(row.chronologicalStability, ValidationEvidenceStatus.pass);
      expect(row.sampleSufficiency, ValidationEvidenceStatus.pass);
      expect(row.unseenForward, ValidationEvidenceStatus.pending);
      expect(row.hasUnseenForwardPass, isFalse);
      expect(row.eligibility, ProductionEligibility.eligibleForPaperForward);
    },
  );

  test('failed historical evidence remains research only', () {
    final row = StrategyValidationEvidence.fromHistoricalAudit(
      verdict(
        strategy: AuditedStrategy.strategyB,
        sample: false,
        expectancy: false,
        pf: false,
        first: false,
        second: false,
      ),
    );

    expect(row.historicalExpectancy, ValidationEvidenceStatus.fail);
    expect(row.sampleSufficiency, ValidationEvidenceStatus.fail);
    expect(row.eligibility, ProductionEligibility.researchOnly);
  });

  test(
    'cost stress and unseen forward are explicit evidence, never inferred',
    () {
      final row = StrategyValidationEvidence.fromHistoricalAudit(
        verdict(
          strategy: AuditedStrategy.strategyC5,
          sample: true,
          expectancy: true,
          pf: true,
          first: true,
          second: true,
        ),
        costStress: ValidationEvidenceStatus.pass,
        unseenForward: ValidationEvidenceStatus.pending,
      );

      expect(row.costStress, ValidationEvidenceStatus.pass);
      expect(row.unseenForward, ValidationEvidenceStatus.pending);
    },
  );
}
