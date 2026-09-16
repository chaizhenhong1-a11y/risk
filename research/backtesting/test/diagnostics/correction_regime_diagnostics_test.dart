import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  group('CorrectionRegimeDiagnostics', () {
    test('ignores non-correction regimes and closes active episode', () {
      final diagnostics = CorrectionRegimeDiagnostics();

      diagnostics.observe(
        regimeAnalysis: _correction(MarketRegimeDirection.bullish),
        m15Structure: MarketStructure.bullish,
        levelLiquidityAnalysis: _emptyLiquidity(),
      );
      diagnostics.observe(
        regimeAnalysis: _trend(MarketRegimeDirection.bullish),
        m15Structure: MarketStructure.bullish,
        levelLiquidityAnalysis: _emptyLiquidity(),
      );

      expect(diagnostics.observations, 1);
      expect(diagnostics.episodes, 1);
      expect(diagnostics.maximumEpisodeM5, 1);
    });

    test('separates direction episodes and classifies M15 relationship', () {
      final diagnostics = CorrectionRegimeDiagnostics();

      diagnostics.observe(
        regimeAnalysis: _correction(MarketRegimeDirection.bullish),
        m15Structure: MarketStructure.bullish,
        levelLiquidityAnalysis: _emptyLiquidity(),
      );
      diagnostics.observe(
        regimeAnalysis: _correction(MarketRegimeDirection.bullish),
        m15Structure: MarketStructure.bearish,
        levelLiquidityAnalysis: _emptyLiquidity(),
      );
      diagnostics.observe(
        regimeAnalysis: _correction(MarketRegimeDirection.bearish),
        m15Structure: MarketStructure.neutral,
        levelLiquidityAnalysis: _emptyLiquidity(),
      );
      diagnostics.finish();

      expect(diagnostics.observations, 3);
      expect(diagnostics.bullishObservations, 2);
      expect(diagnostics.bearishObservations, 1);
      expect(diagnostics.episodes, 2);
      expect(diagnostics.bullishEpisodes, 1);
      expect(diagnostics.bearishEpisodes, 1);
      expect(diagnostics.maximumEpisodeM5, 2);
      expect(diagnostics.m15AlignedWithH4, 1);
      expect(diagnostics.m15OpposedToH4, 1);
      expect(diagnostics.m15NeutralOrUnknown, 1);
    });

    test('share is zero with no correction observations', () {
      expect(CorrectionRegimeDiagnostics().share(1), 0);
    });
  });
}

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

MarketRegimeAnalysis _trend(MarketRegimeDirection direction) =>
    MarketRegimeAnalysis(
      regime: MarketRegime.trendAligned,
      direction: direction,
      h4Structure: direction == MarketRegimeDirection.bullish
          ? MarketStructure.bullish
          : MarketStructure.bearish,
      h1Structure: direction == MarketRegimeDirection.bullish
          ? MarketStructure.bullish
          : MarketStructure.bearish,
      rangeEvidencePresent: false,
    );

LevelLiquidityAnalysis _emptyLiquidity() => LevelLiquidityAnalysis(
  keyLevels: const [],
  liquidityPools: const [],
  levelSweeps: const [],
  poolSweeps: const [],
);
