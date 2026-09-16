import '../market_structure/swing_point.dart';

enum LiquidityPoolType { equalHighs, equalLows }

final class LiquidityPool {
  const LiquidityPool({
    required this.type,
    required this.lowerBound,
    required this.upperBound,
    required this.swingCandleIndexes,
  });

  final LiquidityPoolType type;
  final double lowerBound;
  final double upperBound;
  final List<int> swingCandleIndexes;

  double get midpoint => (lowerBound + upperBound) / 2;
  int get swingCount => swingCandleIndexes.length;
}

/// Detects liquidity pools formed by consecutive confirmed swing highs/lows
/// whose prices remain within an explicit equality tolerance.
///
/// The tolerance is deliberately caller-provided until XAUUSD precision and
/// volatility calibration are available.
final class EqualSwingLiquidityDetector {
  const EqualSwingLiquidityDetector();

  List<LiquidityPool> detect(
    Iterable<SwingPoint> swings, {
    required double equalityTolerance,
  }) {
    if (!equalityTolerance.isFinite || equalityTolerance < 0) {
      throw ArgumentError.value(
        equalityTolerance,
        'equalityTolerance',
        'must be finite and non-negative',
      );
    }

    final ordered = swings.toList()
      ..sort((a, b) => a.candleIndex.compareTo(b.candleIndex));

    final pools = <LiquidityPool>[];
    _detectType(
      ordered.where((swing) => swing.type == SwingType.high).toList(),
      LiquidityPoolType.equalHighs,
      equalityTolerance,
      pools,
    );
    _detectType(
      ordered.where((swing) => swing.type == SwingType.low).toList(),
      LiquidityPoolType.equalLows,
      equalityTolerance,
      pools,
    );

    pools.sort(
      (a, b) =>
          a.swingCandleIndexes.first.compareTo(b.swingCandleIndexes.first),
    );

    return List.unmodifiable(pools);
  }

  void _detectType(
    List<SwingPoint> swings,
    LiquidityPoolType type,
    double tolerance,
    List<LiquidityPool> output,
  ) {
    if (swings.length < 2) {
      return;
    }

    var cluster = <SwingPoint>[swings.first];

    for (var index = 1; index < swings.length; index++) {
      final candidate = swings[index];
      final lower = [
        ...cluster.map((swing) => swing.price),
        candidate.price,
      ].reduce((a, b) => a < b ? a : b);
      final upper = [
        ...cluster.map((swing) => swing.price),
        candidate.price,
      ].reduce((a, b) => a > b ? a : b);

      if (upper - lower <= tolerance) {
        cluster.add(candidate);
        continue;
      }

      _emitCluster(cluster, type, output);
      cluster = <SwingPoint>[candidate];
    }

    _emitCluster(cluster, type, output);
  }

  void _emitCluster(
    List<SwingPoint> cluster,
    LiquidityPoolType type,
    List<LiquidityPool> output,
  ) {
    if (cluster.length < 2) {
      return;
    }

    final prices = cluster.map((swing) => swing.price).toList();
    final lower = prices.reduce((a, b) => a < b ? a : b);
    final upper = prices.reduce((a, b) => a > b ? a : b);

    output.add(
      LiquidityPool(
        type: type,
        lowerBound: lower,
        upperBound: upper,
        swingCandleIndexes: List.unmodifiable(
          cluster.map((swing) => swing.candleIndex).toList(),
        ),
      ),
    );
  }
}
