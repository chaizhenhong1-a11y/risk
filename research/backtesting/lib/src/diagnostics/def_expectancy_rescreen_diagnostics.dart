enum DefStrategy { dBreakout, eRangeMeanReversion, fLiquiditySweep }

final class DefSetupSample {
  const DefSetupSample({
    required this.strategy,
    required this.observedAt,
    required this.isBuy,
    required this.entry,
    required this.stop,
  });

  final DefStrategy strategy;
  final DateTime observedAt;
  final bool isBuy;
  final double entry;
  final double stop;

  double get risk => (entry - stop).abs();
}
