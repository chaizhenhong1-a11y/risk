import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_audit_snapshot.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_expectancy_validator.dart';
import 'package:tradeforge_backtesting/src/validation/unified_strategy_expectancy_audit.dart';

void main() {
  test('round trips a real audit verdict without losing evidence gates', () {
    final snapshot = StrategyAuditSnapshot(
      verdict: StrategyAuditVerdict(
        strategy: AuditedStrategy.strategyA,
        report: const StrategyExpectancyReport(
          total: 87,
          resolved: 87,
          wins: 35,
          losses: 52,
          expired: 0,
          ambiguous: 0,
          winRate: 35 / 87,
          averageWinR: 2,
          averageLossR: -1,
          grossExpectancyR: 0.455,
          netExpectancyR: 0.455,
          profitFactor: 1.762,
          maxLosingStreak: 6,
          firstHalfNetExpectancyR: 0.248,
          secondHalfNetExpectancyR: 0.658,
        ),
        meetsResolvedSampleFloor: true,
        hasPositiveExpectancy: true,
        hasProfitFactorAboveOne: true,
        hasPositiveFirstHalf: true,
        hasPositiveSecondHalf: true,
      ),
      generatedAt: DateTime.utc(2026, 9, 17),
    );

    final restored = StrategyAuditSnapshot.fromJsonLine(snapshot.toJsonLine());

    expect(restored.verdict.strategy, AuditedStrategy.strategyA);
    expect(restored.verdict.report.resolved, 87);
    expect(restored.verdict.report.netExpectancyR, 0.455);
    expect(restored.verdict.passes, isTrue);
    expect(restored.generatedAt, DateTime.utc(2026, 9, 17));
  });

  test('supports infinite profit factor in JSON', () {
    final snapshot = StrategyAuditSnapshot(
      verdict: StrategyAuditVerdict(
        strategy: AuditedStrategy.strategyC5,
        report: const StrategyExpectancyReport(
          total: 1,
          resolved: 1,
          wins: 1,
          losses: 0,
          expired: 0,
          ambiguous: 0,
          winRate: 1,
          averageWinR: 2,
          averageLossR: 0,
          grossExpectancyR: 2,
          netExpectancyR: 2,
          profitFactor: double.infinity,
          maxLosingStreak: 0,
          firstHalfNetExpectancyR: 2,
          secondHalfNetExpectancyR: 2,
        ),
        meetsResolvedSampleFloor: false,
        hasPositiveExpectancy: true,
        hasProfitFactorAboveOne: true,
        hasPositiveFirstHalf: true,
        hasPositiveSecondHalf: true,
      ),
      generatedAt: DateTime.utc(2026, 9, 17),
    );

    final restored = StrategyAuditSnapshot.fromJsonLine(snapshot.toJsonLine());
    expect(restored.verdict.report.profitFactor, double.infinity);
  });
}
