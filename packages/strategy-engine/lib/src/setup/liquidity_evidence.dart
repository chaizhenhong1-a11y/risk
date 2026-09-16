import 'package:technical_analysis/technical_analysis.dart';

import '../bias/multi_timeframe_bias.dart';

enum LiquidityEvidenceType { directionalLevelSweep, directionalPoolSweep }

final class LiquidityEvidence {
  const LiquidityEvidence({required this.type, required this.present});

  final LiquidityEvidenceType type;
  final bool present;
}

/// Converts Phase 3 liquidity facts into strategy evidence.
///
/// Liquidity is deliberately SOFT evidence here:
/// - BUY benefits from a sweep below support or below equal lows.
/// - SELL benefits from a sweep above resistance or above equal highs.
/// - Missing liquidity evidence never blocks an otherwise eligible setup.
final class LiquidityEvidenceEvaluator {
  const LiquidityEvidenceEvaluator();

  List<LiquidityEvidence> evaluate({
    required TradingBias bias,
    required LevelLiquidityAnalysis analysis,
  }) {
    if (bias == TradingBias.noTrade) {
      return const [
        LiquidityEvidence(
          type: LiquidityEvidenceType.directionalLevelSweep,
          present: false,
        ),
        LiquidityEvidence(
          type: LiquidityEvidenceType.directionalPoolSweep,
          present: false,
        ),
      ];
    }

    final levelDirection = bias == TradingBias.buy
        ? LiquiditySweepDirection.belowSupport
        : LiquiditySweepDirection.aboveResistance;
    final poolDirection = bias == TradingBias.buy
        ? LiquidityPoolSweepDirection.belowEqualLows
        : LiquidityPoolSweepDirection.aboveEqualHighs;

    return List.unmodifiable([
      LiquidityEvidence(
        type: LiquidityEvidenceType.directionalLevelSweep,
        present: analysis.levelSweeps.any(
          (sweep) => sweep.direction == levelDirection,
        ),
      ),
      LiquidityEvidence(
        type: LiquidityEvidenceType.directionalPoolSweep,
        present: analysis.poolSweeps.any(
          (sweep) => sweep.direction == poolDirection,
        ),
      ),
    ]);
  }
}
