import 'package:technical_analysis/technical_analysis.dart';

import '../bias/multi_timeframe_bias.dart';
import '../regime/market_regime.dart';

/// Why Strategy B did or did not produce a research candidate.
///
/// Increment 087 deliberately stops at candidate eligibility. Entry, SL, TP,
/// RR and lifecycle remain separate later research stages.
enum CorrectionContinuationReason {
  eligibleBullishRealignment,
  eligibleBearishRealignment,
  wrongRegime,
  missingDirectionalRegime,
  m15NotRealigned,
}

/// Immutable Strategy B v1 candidate analysis.
///
/// Frozen research hypothesis from Increment 086:
/// H4 trend + opposing H1 correction -> M15 transitions from not aligned with
/// H4 to aligned with H4. A directional sweep is retained as soft evidence and
/// is NOT a hard requirement.
final class CorrectionContinuationAnalysis {
  const CorrectionContinuationAnalysis({
    required this.bias,
    required this.reason,
    required this.regimeDirection,
    required this.previousM15Structure,
    required this.currentM15Structure,
    required this.directionalSweepEvidencePresent,
  });

  final TradingBias bias;
  final CorrectionContinuationReason reason;
  final MarketRegimeDirection regimeDirection;
  final MarketStructure previousM15Structure;
  final MarketStructure currentM15Structure;
  final bool directionalSweepEvidencePresent;

  bool get isEligible => bias != TradingBias.noTrade;
}

/// Strategy B v1 specification boundary: Correction Continuation.
///
/// Hard requirements:
/// 1. regime is H4 trend / H1 correction;
/// 2. regime retains a bullish or bearish H4 direction;
/// 3. M15 has JUST realigned with that H4 direction.
///
/// `directionalSweepEvidencePresent` is descriptive soft evidence only. The
/// Increment 086 outcome research did not justify promoting sweep to a gate.
final class CorrectionContinuationAnalyzer {
  const CorrectionContinuationAnalyzer();

  CorrectionContinuationAnalysis analyze({
    required MarketRegimeAnalysis regimeAnalysis,
    required MarketRegime? previousRegime,
    required MarketStructure previousM15Structure,
    required MarketStructure currentM15Structure,
    bool directionalSweepEvidencePresent = false,
  }) {
    if (regimeAnalysis.regime !=
        MarketRegime.higherTimeframeTrendLowerTimeframeCorrection) {
      return CorrectionContinuationAnalysis(
        bias: TradingBias.noTrade,
        reason: CorrectionContinuationReason.wrongRegime,
        regimeDirection: regimeAnalysis.direction,
        previousM15Structure: previousM15Structure,
        currentM15Structure: currentM15Structure,
        directionalSweepEvidencePresent: directionalSweepEvidencePresent,
      );
    }

    final direction = regimeAnalysis.direction;
    if (direction == MarketRegimeDirection.none) {
      return CorrectionContinuationAnalysis(
        bias: TradingBias.noTrade,
        reason: CorrectionContinuationReason.missingDirectionalRegime,
        regimeDirection: direction,
        previousM15Structure: previousM15Structure,
        currentM15Structure: currentM15Structure,
        directionalSweepEvidencePresent: directionalSweepEvidencePresent,
      );
    }

    final wasAlreadyAlignedInSameCorrection =
        previousRegime ==
            MarketRegime.higherTimeframeTrendLowerTimeframeCorrection &&
        _isAligned(previousM15Structure, direction);
    final isAligned = _isAligned(currentM15Structure, direction);
    if (wasAlreadyAlignedInSameCorrection || !isAligned) {
      return CorrectionContinuationAnalysis(
        bias: TradingBias.noTrade,
        reason: CorrectionContinuationReason.m15NotRealigned,
        regimeDirection: direction,
        previousM15Structure: previousM15Structure,
        currentM15Structure: currentM15Structure,
        directionalSweepEvidencePresent: directionalSweepEvidencePresent,
      );
    }

    return CorrectionContinuationAnalysis(
      bias: direction == MarketRegimeDirection.bullish
          ? TradingBias.buy
          : TradingBias.sell,
      reason: direction == MarketRegimeDirection.bullish
          ? CorrectionContinuationReason.eligibleBullishRealignment
          : CorrectionContinuationReason.eligibleBearishRealignment,
      regimeDirection: direction,
      previousM15Structure: previousM15Structure,
      currentM15Structure: currentM15Structure,
      directionalSweepEvidencePresent: directionalSweepEvidencePresent,
    );
  }

  bool _isAligned(MarketStructure structure, MarketRegimeDirection direction) =>
      (direction == MarketRegimeDirection.bullish &&
          structure == MarketStructure.bullish) ||
      (direction == MarketRegimeDirection.bearish &&
          structure == MarketStructure.bearish);
}
