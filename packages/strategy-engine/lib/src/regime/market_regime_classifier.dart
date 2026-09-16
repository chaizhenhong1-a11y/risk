import 'package:technical_analysis/technical_analysis.dart';

import 'market_regime.dart';

/// Deterministic higher-timeframe market-regime foundation.
///
/// Increment 080 classifies structure context only. It does not route a
/// strategy, emit a trade direction, or change Strategy A eligibility.
final class MarketRegimeClassifier {
  const MarketRegimeClassifier();

  MarketRegimeAnalysis classify({
    required MarketStructure h4Structure,
    required MarketStructure h1Structure,
    bool rangeEvidencePresent = false,
  }) {
    if (h4Structure == MarketStructure.unknown ||
        h1Structure == MarketStructure.unknown) {
      return _analysis(
        regime: MarketRegime.unknown,
        direction: MarketRegimeDirection.none,
        h4Structure: h4Structure,
        h1Structure: h1Structure,
        rangeEvidencePresent: rangeEvidencePresent,
      );
    }

    if (h4Structure == MarketStructure.bullish &&
        h1Structure == MarketStructure.bullish) {
      return _analysis(
        regime: MarketRegime.trendAligned,
        direction: MarketRegimeDirection.bullish,
        h4Structure: h4Structure,
        h1Structure: h1Structure,
        rangeEvidencePresent: rangeEvidencePresent,
      );
    }

    if (h4Structure == MarketStructure.bearish &&
        h1Structure == MarketStructure.bearish) {
      return _analysis(
        regime: MarketRegime.trendAligned,
        direction: MarketRegimeDirection.bearish,
        h4Structure: h4Structure,
        h1Structure: h1Structure,
        rangeEvidencePresent: rangeEvidencePresent,
      );
    }

    if (h4Structure == MarketStructure.bullish &&
        h1Structure == MarketStructure.bearish) {
      return _analysis(
        regime: MarketRegime.higherTimeframeTrendLowerTimeframeCorrection,
        direction: MarketRegimeDirection.bullish,
        h4Structure: h4Structure,
        h1Structure: h1Structure,
        rangeEvidencePresent: rangeEvidencePresent,
      );
    }

    if (h4Structure == MarketStructure.bearish &&
        h1Structure == MarketStructure.bullish) {
      return _analysis(
        regime: MarketRegime.higherTimeframeTrendLowerTimeframeCorrection,
        direction: MarketRegimeDirection.bearish,
        h4Structure: h4Structure,
        h1Structure: h1Structure,
        rangeEvidencePresent: rangeEvidencePresent,
      );
    }

    return _analysis(
      regime: rangeEvidencePresent
          ? MarketRegime.range
          : MarketRegime.transition,
      direction: MarketRegimeDirection.none,
      h4Structure: h4Structure,
      h1Structure: h1Structure,
      rangeEvidencePresent: rangeEvidencePresent,
    );
  }

  MarketRegimeAnalysis _analysis({
    required MarketRegime regime,
    required MarketRegimeDirection direction,
    required MarketStructure h4Structure,
    required MarketStructure h1Structure,
    required bool rangeEvidencePresent,
  }) {
    return MarketRegimeAnalysis(
      regime: regime,
      direction: direction,
      h4Structure: h4Structure,
      h1Structure: h1Structure,
      rangeEvidencePresent: rangeEvidencePresent,
    );
  }
}
