import 'strategy_expectancy_validator.dart';
import 'strategy_validation_standard.dart';

enum AuditedStrategy { strategyA, strategyB, strategyC5 }

final class StrategyAuditInput {
  const StrategyAuditInput({required this.strategy, required this.trades});

  final AuditedStrategy strategy;
  final List<StrategyTradeResult> trades;
}

final class StrategyAuditVerdict {
  const StrategyAuditVerdict({
    required this.strategy,
    required this.report,
    required this.meetsResolvedSampleFloor,
    required this.hasPositiveExpectancy,
    required this.hasProfitFactorAboveOne,
    required this.hasPositiveFirstHalf,
    required this.hasPositiveSecondHalf,
  });

  final AuditedStrategy strategy;
  final StrategyExpectancyReport report;
  final bool meetsResolvedSampleFloor;
  final bool hasPositiveExpectancy;
  final bool hasProfitFactorAboveOne;
  final bool hasPositiveFirstHalf;
  final bool hasPositiveSecondHalf;

  bool get passes =>
      meetsResolvedSampleFloor &&
      hasPositiveExpectancy &&
      hasProfitFactorAboveOne &&
      hasPositiveFirstHalf &&
      hasPositiveSecondHalf;
}

/// Applies exactly the same expectancy criteria to A, B and C5.
///
/// This class deliberately does not know how a strategy creates an entry,
/// stop or target. Those rules stay owned by each strategy. The audit layer
/// only evaluates completed lifecycle results, preventing the research
/// harness from silently changing production strategy geometry.
final class UnifiedStrategyExpectancyAudit {
  const UnifiedStrategyExpectancyAudit({
    this.standard = const StrategyValidationStandard(),
    this.validator = const StrategyExpectancyValidator(),
  });

  final StrategyValidationStandard standard;
  final StrategyExpectancyValidator validator;

  List<StrategyAuditVerdict> evaluate(Iterable<StrategyAuditInput> inputs) {
    return [for (final input in inputs) _evaluateOne(input)];
  }

  StrategyAuditVerdict _evaluateOne(StrategyAuditInput input) {
    final report = validator.evaluate(input.trades);

    return StrategyAuditVerdict(
      strategy: input.strategy,
      report: report,
      meetsResolvedSampleFloor:
          report.resolved >= standard.minimumResolvedTrades,
      hasPositiveExpectancy:
          !standard.requirePositiveNetExpectancy || report.netExpectancyR > 0,
      hasProfitFactorAboveOne:
          !standard.requireProfitFactorAboveOne || report.profitFactor > 1,
      hasPositiveFirstHalf:
          !standard.requirePositiveFirstHalf ||
          report.firstHalfNetExpectancyR > 0,
      hasPositiveSecondHalf:
          !standard.requirePositiveSecondHalf ||
          report.secondHalfNetExpectancyR > 0,
    );
  }
}
