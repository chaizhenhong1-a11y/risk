import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/diagnostics/strategy_c_hypothesis_validation.dart';

void main() {
  test('matches the three frozen increment 104 hypotheses', () {
    expect(
      StrategyCHypothesisValidation.matches(
        id: StrategyCHypothesisId.c1BullishTrendRecovery,
        h4: MarketStructure.bullish,
        h1: MarketStructure.neutral,
        m15: MarketStructure.bullish,
        supportSweep: false,
        resistanceSweep: false,
        equalLowSweep: false,
        equalHighSweep: false,
      ),
      isTrue,
    );

    expect(
      StrategyCHypothesisValidation.matches(
        id: StrategyCHypothesisId.c2BearishTrendRecovery,
        h4: MarketStructure.bearish,
        h1: MarketStructure.neutral,
        m15: MarketStructure.bearish,
        supportSweep: true,
        resistanceSweep: true,
        equalLowSweep: false,
        equalHighSweep: false,
      ),
      isTrue,
    );

    expect(
      StrategyCHypothesisValidation.matches(
        id: StrategyCHypothesisId.c3BearishCorrectionContinuation,
        h4: MarketStructure.bearish,
        h1: MarketStructure.neutral,
        m15: MarketStructure.bullish,
        supportSweep: false,
        resistanceSweep: false,
        equalLowSweep: false,
        equalHighSweep: false,
      ),
      isTrue,
    );
  });
}
