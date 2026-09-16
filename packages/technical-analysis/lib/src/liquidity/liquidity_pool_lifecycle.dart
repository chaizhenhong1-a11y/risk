import 'package:market_models/market_models.dart';

import 'equal_swing_liquidity_detector.dart';

enum LiquidityPoolStatus { active, swept, broken }

final class LiquidityPoolState {
  const LiquidityPoolState({
    required this.pool,
    this.status = LiquidityPoolStatus.active,
  });

  final LiquidityPool pool;
  final LiquidityPoolStatus status;

  bool get isActive => status == LiquidityPoolStatus.active;
}

final class LiquidityPoolLifecycle {
  const LiquidityPoolLifecycle();

  LiquidityPoolState evaluate({
    required LiquidityPoolState state,
    required Candle candle,
  }) {
    if (!state.isActive) {
      return state;
    }

    final pool = state.pool;

    switch (pool.type) {
      case LiquidityPoolType.equalHighs:
        if (candle.close > pool.upperBound) {
          return LiquidityPoolState(
            pool: pool,
            status: LiquidityPoolStatus.broken,
          );
        }
        if (candle.high > pool.upperBound && candle.close <= pool.upperBound) {
          return LiquidityPoolState(
            pool: pool,
            status: LiquidityPoolStatus.swept,
          );
        }

      case LiquidityPoolType.equalLows:
        if (candle.close < pool.lowerBound) {
          return LiquidityPoolState(
            pool: pool,
            status: LiquidityPoolStatus.broken,
          );
        }
        if (candle.low < pool.lowerBound && candle.close >= pool.lowerBound) {
          return LiquidityPoolState(
            pool: pool,
            status: LiquidityPoolStatus.swept,
          );
        }
    }

    return state;
  }
}
