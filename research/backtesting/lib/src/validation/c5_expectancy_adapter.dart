import '../dataset/strategy_c_structural_lifecycle_validation.dart';
import 'strategy_expectancy_validator.dart';

/// Adapts the already-frozen C5 structural lifecycle (structural support,
/// M15 ATR14 x 0.50 buffered stop, 2R target) to the common audit model.
///
/// Expiry is deliberately unresolved here. The unified validator's expectancy
/// is based on resolved target/stop trades; expiry mark-to-market remains a
/// separate C5 research diagnostic and is not silently converted into a win
/// or loss.
final class C5ExpectancyAdapter {
  const C5ExpectancyAdapter({this.rewardMultiple = 2.0});

  final double rewardMultiple;

  StrategyTradeResult convert(
    C5StructuralCase sample,
    C5StructuralSettlement settlement, {
    double costR = 0,
  }) {
    final resolution = switch (settlement.outcome) {
      C5StructuralOutcome.target => TradeResolution.win,
      C5StructuralOutcome.stop => TradeResolution.loss,
      C5StructuralOutcome.expiry => TradeResolution.expired,
      C5StructuralOutcome.ambiguous => TradeResolution.ambiguous,
    };

    return StrategyTradeResult(
      observedAt: sample.risk.time,
      resolution: resolution,
      rewardRisk: rewardMultiple,
      costR: costR,
    );
  }
}
