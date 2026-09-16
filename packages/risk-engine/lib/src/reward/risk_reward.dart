import 'package:strategy_engine/strategy_engine.dart';

enum RiskRewardStatus { invalid, valid }

enum RiskRewardInvalidReason {
  noDirectionalBias,
  invalidBuyStop,
  invalidBuyTarget,
  invalidSellStop,
  invalidSellTarget,
}

/// Deterministic risk/reward measurement for one explicit entry price.
///
/// `ratio` means reward divided by risk. For example, 2.0 means the available
/// reward is twice the price risk.
///
/// This object measures geometry only. It does not decide whether a setup is
/// acceptable and does not imply win probability.
final class RiskReward {
  const RiskReward({
    required this.entryPrice,
    required this.stopPrice,
    required this.targetPrice,
    required this.riskDistance,
    required this.rewardDistance,
    required this.ratio,
    required this.bias,
  });

  final double entryPrice;
  final double stopPrice;
  final double targetPrice;
  final double riskDistance;
  final double rewardDistance;
  final double ratio;
  final TradingBias bias;
}

final class RiskRewardAnalysis {
  const RiskRewardAnalysis._({
    required this.status,
    this.riskReward,
    this.invalidReason,
  });

  const RiskRewardAnalysis.valid(RiskReward riskReward)
    : this._(status: RiskRewardStatus.valid, riskReward: riskReward);

  const RiskRewardAnalysis.invalid(RiskRewardInvalidReason reason)
    : this._(status: RiskRewardStatus.invalid, invalidReason: reason);

  final RiskRewardStatus status;
  final RiskReward? riskReward;
  final RiskRewardInvalidReason? invalidReason;

  bool get isValid => status == RiskRewardStatus.valid;
}

/// Calculates price-based risk/reward from explicit Entry, SL and TP prices.
///
/// BUY:
///   risk   = entry - stop
///   reward = target - entry
///
/// SELL:
///   risk   = stop - entry
///   reward = entry - target
///
/// No minimum-RR Gate or preferred entry-price policy is applied here.
final class RiskRewardCalculator {
  const RiskRewardCalculator();

  RiskRewardAnalysis calculate({
    required TradingBias bias,
    required double entryPrice,
    required double stopPrice,
    required double targetPrice,
  }) {
    _requireFinite(entryPrice, 'entryPrice');
    _requireFinite(stopPrice, 'stopPrice');
    _requireFinite(targetPrice, 'targetPrice');

    if (bias == TradingBias.noTrade) {
      return const RiskRewardAnalysis.invalid(
        RiskRewardInvalidReason.noDirectionalBias,
      );
    }

    final double riskDistance;
    final double rewardDistance;

    if (bias == TradingBias.buy) {
      if (stopPrice >= entryPrice) {
        return const RiskRewardAnalysis.invalid(
          RiskRewardInvalidReason.invalidBuyStop,
        );
      }
      if (targetPrice <= entryPrice) {
        return const RiskRewardAnalysis.invalid(
          RiskRewardInvalidReason.invalidBuyTarget,
        );
      }

      riskDistance = entryPrice - stopPrice;
      rewardDistance = targetPrice - entryPrice;
    } else {
      if (stopPrice <= entryPrice) {
        return const RiskRewardAnalysis.invalid(
          RiskRewardInvalidReason.invalidSellStop,
        );
      }
      if (targetPrice >= entryPrice) {
        return const RiskRewardAnalysis.invalid(
          RiskRewardInvalidReason.invalidSellTarget,
        );
      }

      riskDistance = stopPrice - entryPrice;
      rewardDistance = entryPrice - targetPrice;
    }

    return RiskRewardAnalysis.valid(
      RiskReward(
        entryPrice: entryPrice,
        stopPrice: stopPrice,
        targetPrice: targetPrice,
        riskDistance: riskDistance,
        rewardDistance: rewardDistance,
        ratio: rewardDistance / riskDistance,
        bias: bias,
      ),
    );
  }

  void _requireFinite(double value, String name) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, name, '$name must be finite.');
    }
  }
}
