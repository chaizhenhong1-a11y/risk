import 'package:market_models/market_models.dart';

import 'equal_swing_liquidity_detector.dart';

enum LiquidityPoolSweepDirection { aboveEqualHighs, belowEqualLows }

final class LiquidityPoolSweep {
  const LiquidityPoolSweep({
    required this.direction,
    required this.pool,
    required this.extremePrice,
    required this.closePrice,
  });

  final LiquidityPoolSweepDirection direction;
  final LiquidityPool pool;
  final double extremePrice;
  final double closePrice;
}

/// Detects a baseline single-candle raid of an equal-high/equal-low liquidity
/// pool followed by a close back inside the pool or beyond its protected side.
///
/// This is deterministic market evidence only and never produces BUY/SELL.
final class LiquidityPoolSweepDetector {
  const LiquidityPoolSweepDetector();

  LiquidityPoolSweep? detect({
    required Candle candle,
    required LiquidityPool pool,
  }) {
    return switch (pool.type) {
      LiquidityPoolType.equalHighs => _equalHighSweep(candle, pool),
      LiquidityPoolType.equalLows => _equalLowSweep(candle, pool),
    };
  }

  LiquidityPoolSweep? _equalHighSweep(Candle candle, LiquidityPool pool) {
    final raided = candle.high > pool.upperBound;
    final reclaimed = candle.close <= pool.upperBound;

    if (!raided || !reclaimed) {
      return null;
    }

    return LiquidityPoolSweep(
      direction: LiquidityPoolSweepDirection.aboveEqualHighs,
      pool: pool,
      extremePrice: candle.high,
      closePrice: candle.close,
    );
  }

  LiquidityPoolSweep? _equalLowSweep(Candle candle, LiquidityPool pool) {
    final raided = candle.low < pool.lowerBound;
    final reclaimed = candle.close >= pool.lowerBound;

    if (!raided || !reclaimed) {
      return null;
    }

    return LiquidityPoolSweep(
      direction: LiquidityPoolSweepDirection.belowEqualLows,
      pool: pool,
      extremePrice: candle.low,
      closePrice: candle.close,
    );
  }
}
