import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const analyzer = CorrectionContinuationAnalyzer();

  MarketRegimeAnalysis correction(MarketRegimeDirection direction) {
    return MarketRegimeAnalysis(
      regime: MarketRegime.higherTimeframeTrendLowerTimeframeCorrection,
      direction: direction,
      h4Structure: direction == MarketRegimeDirection.bullish
          ? MarketStructure.bullish
          : MarketStructure.bearish,
      h1Structure: direction == MarketRegimeDirection.bullish
          ? MarketStructure.bearish
          : MarketStructure.bullish,
      rangeEvidencePresent: false,
    );
  }

  test('bullish correction becomes BUY only on fresh M15 realignment', () {
    final result = analyzer.analyze(
      regimeAnalysis: correction(MarketRegimeDirection.bullish),
      previousRegime: MarketRegime.higherTimeframeTrendLowerTimeframeCorrection,
      previousM15Structure: MarketStructure.bearish,
      currentM15Structure: MarketStructure.bullish,
    );

    expect(result.isEligible, isTrue);
    expect(result.bias, TradingBias.buy);
    expect(
      result.reason,
      CorrectionContinuationReason.eligibleBullishRealignment,
    );
  });

  test('bearish correction becomes SELL only on fresh M15 realignment', () {
    final result = analyzer.analyze(
      regimeAnalysis: correction(MarketRegimeDirection.bearish),
      previousRegime: MarketRegime.higherTimeframeTrendLowerTimeframeCorrection,
      previousM15Structure: MarketStructure.neutral,
      currentM15Structure: MarketStructure.bearish,
    );

    expect(result.isEligible, isTrue);
    expect(result.bias, TradingBias.sell);
  });

  test('persistent M15 alignment is not repeatedly eligible', () {
    final result = analyzer.analyze(
      regimeAnalysis: correction(MarketRegimeDirection.bullish),
      previousRegime: MarketRegime.higherTimeframeTrendLowerTimeframeCorrection,
      previousM15Structure: MarketStructure.bullish,
      currentM15Structure: MarketStructure.bullish,
    );

    expect(result.isEligible, isFalse);
    expect(result.reason, CorrectionContinuationReason.m15NotRealigned);
  });

  test('M15 still opposing H4 remains blocked', () {
    final result = analyzer.analyze(
      regimeAnalysis: correction(MarketRegimeDirection.bullish),
      previousRegime: MarketRegime.higherTimeframeTrendLowerTimeframeCorrection,
      previousM15Structure: MarketStructure.neutral,
      currentM15Structure: MarketStructure.bearish,
    );

    expect(result.isEligible, isFalse);
  });

  test('sweep is retained as soft evidence and is not a gate', () {
    final withoutSweep = analyzer.analyze(
      regimeAnalysis: correction(MarketRegimeDirection.bullish),
      previousRegime: MarketRegime.higherTimeframeTrendLowerTimeframeCorrection,
      previousM15Structure: MarketStructure.neutral,
      currentM15Structure: MarketStructure.bullish,
    );
    final withSweep = analyzer.analyze(
      regimeAnalysis: correction(MarketRegimeDirection.bullish),
      previousRegime: MarketRegime.higherTimeframeTrendLowerTimeframeCorrection,
      previousM15Structure: MarketStructure.neutral,
      currentM15Structure: MarketStructure.bullish,
      directionalSweepEvidencePresent: true,
    );

    expect(withoutSweep.isEligible, isTrue);
    expect(withSweep.isEligible, isTrue);
    expect(withoutSweep.directionalSweepEvidencePresent, isFalse);
    expect(withSweep.directionalSweepEvidencePresent, isTrue);
  });

  test(
    'correction episode entry may qualify when M15 is already H4-aligned',
    () {
      final result = analyzer.analyze(
        regimeAnalysis: correction(MarketRegimeDirection.bullish),
        previousRegime: MarketRegime.transition,
        previousM15Structure: MarketStructure.bullish,
        currentM15Structure: MarketStructure.bullish,
      );

      expect(result.isEligible, isTrue);
      expect(result.bias, TradingBias.buy);
    },
  );

  test('non-correction regime cannot enter Strategy B', () {
    final result = analyzer.analyze(
      regimeAnalysis: const MarketRegimeAnalysis(
        regime: MarketRegime.trendAligned,
        direction: MarketRegimeDirection.bullish,
        h4Structure: MarketStructure.bullish,
        h1Structure: MarketStructure.bullish,
        rangeEvidencePresent: false,
      ),
      previousRegime: MarketRegime.trendAligned,
      previousM15Structure: MarketStructure.neutral,
      currentM15Structure: MarketStructure.bullish,
    );

    expect(result.isEligible, isFalse);
    expect(result.reason, CorrectionContinuationReason.wrongRegime);
  });
}
