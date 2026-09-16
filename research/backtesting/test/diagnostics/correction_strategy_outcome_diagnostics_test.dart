import 'package:market_models/market_models.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  group('CorrectionStrategyOutcomeDiagnostics', () {
    test('tracks later candles and excludes the trigger candle', () {
      final diagnostics = CorrectionStrategyOutcomeDiagnostics(horizonsM5: [2]);

      diagnostics.observe(
        currentM5Candle: _candle(0, 100, 105, 95, 100),
        regimeAnalysis: _correction(MarketRegimeDirection.bullish),
        m15Structure: MarketStructure.bullish,
        levelLiquidityAnalysis: _emptyLiquidity(),
        m15Atr: 1,
      );

      final summary = diagnostics
          .summaries[CorrectionOutcomeHypothesis.m15RealignedWithH4]![2]!;
      expect(summary.triggers, 1);
      expect(summary.resolved, 0);

      diagnostics.observe(
        currentM5Candle: _candle(1, 100, 101.2, 99.8, 101),
        regimeAnalysis: _correction(MarketRegimeDirection.bullish),
        m15Structure: MarketStructure.bullish,
        levelLiquidityAnalysis: _emptyLiquidity(),
        m15Atr: 1,
      );
      diagnostics.observe(
        currentM5Candle: _candle(2, 101, 102.2, 100.5, 102),
        regimeAnalysis: _correction(MarketRegimeDirection.bullish),
        m15Structure: MarketStructure.bullish,
        levelLiquidityAnalysis: _emptyLiquidity(),
        m15Atr: 1,
      );

      expect(summary.resolved, 1);
      expect(summary.averageMfeAtr, closeTo(2.2, 1e-9));
      expect(summary.averageMaeAtr, closeTo(0.2, 1e-9));
      expect(summary.favorableOneAtrFirst, 1);
      expect(summary.favorableTwoAtrBeforeAdverseOneAtr, 1);
    });

    test('does not retrigger a persistent aligned condition', () {
      final diagnostics = CorrectionStrategyOutcomeDiagnostics(horizonsM5: [1]);

      for (var index = 0; index < 3; index++) {
        diagnostics.observe(
          currentM5Candle: _candle(index, 100, 100.5, 99.5, 100),
          regimeAnalysis: _correction(MarketRegimeDirection.bullish),
          m15Structure: MarketStructure.bullish,
          levelLiquidityAnalysis: _emptyLiquidity(),
          m15Atr: 1,
        );
      }

      expect(
        diagnostics
            .summaries[CorrectionOutcomeHypothesis.m15RealignedWithH4]![1]!
            .triggers,
        1,
      );
    });
  });
}

Candle _candle(int index, double open, double high, double low, double close) =>
    Candle(
      openTime: DateTime(2026, 1, 1).add(Duration(minutes: index * 5)),
      closeTime: DateTime(2026, 1, 1).add(Duration(minutes: index * 5 + 5)),
      open: open,
      high: high,
      low: low,
      close: close,
      volume: 1,
    );

MarketRegimeAnalysis _correction(MarketRegimeDirection direction) =>
    MarketRegimeAnalysis(
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

LevelLiquidityAnalysis _emptyLiquidity() => LevelLiquidityAnalysis(
  keyLevels: const [],
  liquidityPools: const [],
  levelSweeps: const [],
  poolSweeps: const [],
);
