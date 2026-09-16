import 'package:market_models/market_models.dart';

import '../levels/key_level.dart';
import '../levels/key_level_factory.dart';
import '../levels/key_level_merger.dart';
import '../liquidity/equal_swing_liquidity_detector.dart';
import '../liquidity/liquidity_pool_sweep_detector.dart';
import '../liquidity/liquidity_sweep_detector.dart';
import '../market_structure/swing_point.dart';

final class LevelLiquidityAnalysis {
  LevelLiquidityAnalysis({
    required List<KeyLevel> keyLevels,
    required List<LiquidityPool> liquidityPools,
    required List<LiquiditySweep> levelSweeps,
    required List<LiquidityPoolSweep> poolSweeps,
  }) : keyLevels = List.unmodifiable(keyLevels),
       liquidityPools = List.unmodifiable(liquidityPools),
       levelSweeps = List.unmodifiable(levelSweeps),
       poolSweeps = List.unmodifiable(poolSweeps);

  final List<KeyLevel> keyLevels;
  final List<LiquidityPool> liquidityPools;
  final List<LiquiditySweep> levelSweeps;
  final List<LiquidityPoolSweep> poolSweeps;
}

/// Integrates the Phase 3 level/liquidity primitives into one deterministic
/// snapshot for a single closed candle.
///
/// It does not decide trend, setup quality, or BUY/SELL. Strategy code can
/// consume this snapshot later without rebuilding lower-level analysis.
final class LevelLiquidityAnalyzer {
  const LevelLiquidityAnalyzer({
    this.keyLevelFactory = const KeyLevelFactory(),
    this.keyLevelMerger = const KeyLevelMerger(),
    this.equalSwingLiquidityDetector = const EqualSwingLiquidityDetector(),
    this.liquiditySweepDetector = const LiquiditySweepDetector(),
    this.liquidityPoolSweepDetector = const LiquidityPoolSweepDetector(),
  });

  final KeyLevelFactory keyLevelFactory;
  final KeyLevelMerger keyLevelMerger;
  final EqualSwingLiquidityDetector equalSwingLiquidityDetector;
  final LiquiditySweepDetector liquiditySweepDetector;
  final LiquidityPoolSweepDetector liquidityPoolSweepDetector;

  LevelLiquidityAnalysis analyze({
    required Iterable<SwingPoint> confirmedSwings,
    required Candle closedCandle,
    required double zoneHalfWidth,
    required double levelMergeMaxGap,
    required double equalityTolerance,
  }) {
    _validateNonNegativeFinite(zoneHalfWidth, 'zoneHalfWidth');
    _validateNonNegativeFinite(levelMergeMaxGap, 'levelMergeMaxGap');
    _validateNonNegativeFinite(equalityTolerance, 'equalityTolerance');

    final swings = confirmedSwings.toList(growable: false);

    final rawLevels = keyLevelFactory.fromSwings(
      swings,
      zoneHalfWidth: zoneHalfWidth,
    );
    final keyLevels = keyLevelMerger.merge(rawLevels, maxGap: levelMergeMaxGap);
    final liquidityPools = equalSwingLiquidityDetector.detect(
      swings,
      equalityTolerance: equalityTolerance,
    );

    final levelSweeps = <LiquiditySweep>[
      for (final level in keyLevels)
        if (liquiditySweepDetector.detect(candle: closedCandle, level: level)
            case final sweep?)
          sweep,
    ];

    final poolSweeps = <LiquidityPoolSweep>[
      for (final pool in liquidityPools)
        if (liquidityPoolSweepDetector.detect(candle: closedCandle, pool: pool)
            case final sweep?)
          sweep,
    ];

    return LevelLiquidityAnalysis(
      keyLevels: keyLevels,
      liquidityPools: liquidityPools,
      levelSweeps: levelSweeps,
      poolSweeps: poolSweeps,
    );
  }

  void _validateNonNegativeFinite(double value, String name) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(value, name, 'must be finite and non-negative');
    }
  }
}
