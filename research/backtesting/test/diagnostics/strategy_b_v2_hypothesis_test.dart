import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:test/test.dart';

void main() {
  group('Strategy B v2 hypothesis 097', () {
    test('freezes the single M15 body hypothesis selected for validation', () {
      expect(StrategyBV2Hypothesis.id, 'strategy-b-v2-hypothesis-097-v1');
      expect(StrategyBV2Hypothesis.minimumPlannedRiskReward, 2.0);
      expect(StrategyBV2Hypothesis.minimumRealignmentBodyAtr, 0.50);
      expect(StrategyBV2Hypothesis.maximumRealignmentBodyAtr, 1.00);

      expect(StrategyBV2Hypothesis.matchesRealignmentBody(null), isFalse);
      expect(StrategyBV2Hypothesis.matchesRealignmentBody(0.49), isFalse);
      expect(StrategyBV2Hypothesis.matchesRealignmentBody(0.50), isTrue);
      expect(StrategyBV2Hypothesis.matchesRealignmentBody(0.75), isTrue);
      expect(StrategyBV2Hypothesis.matchesRealignmentBody(0.999), isTrue);
      expect(StrategyBV2Hypothesis.matchesRealignmentBody(1.00), isFalse);
      expect(StrategyBV2Hypothesis.matchesRealignmentBody(double.nan), isFalse);
    });

    test('does not promote exploratory 096 features into gates', () {
      expect(StrategyBV2Hypothesis.gateOnVolatilityRegime, isFalse);
      expect(StrategyBV2Hypothesis.gateOnCorrectionDuration, isFalse);
      expect(StrategyBV2Hypothesis.gateOnCorrectionExcursion, isFalse);
      expect(StrategyBV2Hypothesis.gateOnDirectionalCloseLocation, isFalse);
    });

    test('freezes the 098 validation contract and baseline integrity', () {
      expect(StrategyBV2ValidationPlan.forwardHorizonsM5, [12, 24, 48]);
      expect(StrategyBV2ValidationPlan.expectedBaselineCandidates, 203);
      expect(StrategyBV2ValidationPlan.expectedBaselineRiskEligible, 12);
      expect(StrategyBV2ValidationPlan.requireFreshHistoricalReplay, isTrue);
      expect(StrategyBV2ValidationPlan.requireBaselineIntegrityCheck, isTrue);
      expect(StrategyBV2ValidationPlan.requireHypothesisSubsetReport, isTrue);
      expect(StrategyBV2ValidationPlan.requireTerminalLifecycleReport, isTrue);
      expect(
        StrategyBV2ValidationPlan.allowThresholdRetuningDuringValidation,
        isFalse,
      );
    });
  });
}
