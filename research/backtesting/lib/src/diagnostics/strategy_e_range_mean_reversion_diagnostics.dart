enum RangeReversionSide { lowerExtreme, upperExtreme }

final class RangeReversionSample {
  const RangeReversionSample({
    required this.time,
    required this.side,
    required this.rangePosition,
    required this.rangeWidthAtr,
    required this.return12,
    required this.return24,
    required this.return48,
  });

  final DateTime time;
  final RangeReversionSide side;
  final double rangePosition;
  final double rangeWidthAtr;
  final double return12;
  final double return24;
  final double return48;

  bool reverted(double value) => switch (side) {
    RangeReversionSide.lowerExtreme => value > 0,
    RangeReversionSide.upperExtreme => value < 0,
  };
}

final class RangeReversionSummary {
  const RangeReversionSummary({
    required this.label,
    required this.samples,
    required this.reversion12,
    required this.reversion24,
    required this.reversion48,
  });

  final String label;
  final int samples;
  final double reversion12;
  final double reversion24;
  final double reversion48;
}

/// Strategy E discovery only.
///
/// Uses pre-declared range-location/width buckets. These results are
/// directional mean-reversion rates, not trade win rates or production rules.
final class StrategyERangeMeanReversionDiagnostics {
  const StrategyERangeMeanReversionDiagnostics();

  List<RangeReversionSummary> summarize(
    Iterable<RangeReversionSample> samples,
  ) {
    final input = samples.toList(growable: false);
    final buckets = <String, bool Function(RangeReversionSample)>{
      'all extremes': (_) => true,
      'outer 20%': (s) => s.rangePosition <= .20 || s.rangePosition >= .80,
      'outer 15%': (s) => s.rangePosition <= .15 || s.rangePosition >= .85,
      'outer 10%': (s) => s.rangePosition <= .10 || s.rangePosition >= .90,
      'outer 20% & width>=2ATR': (s) =>
          (s.rangePosition <= .20 || s.rangePosition >= .80) &&
          s.rangeWidthAtr >= 2,
      'outer 15% & width>=3ATR': (s) =>
          (s.rangePosition <= .15 || s.rangePosition >= .85) &&
          s.rangeWidthAtr >= 3,
    };

    return [
      for (final bucket in buckets.entries)
        _summary(bucket.key, input.where(bucket.value).toList(growable: false)),
    ];
  }

  RangeReversionSummary _summary(
    String label,
    List<RangeReversionSample> samples,
  ) {
    if (samples.isEmpty) {
      return RangeReversionSummary(
        label: label,
        samples: 0,
        reversion12: 0,
        reversion24: 0,
        reversion48: 0,
      );
    }

    double rate(double Function(RangeReversionSample) value) =>
        samples.where((s) => s.reverted(value(s))).length / samples.length;

    return RangeReversionSummary(
      label: label,
      samples: samples.length,
      reversion12: rate((s) => s.return12),
      reversion24: rate((s) => s.return24),
      reversion48: rate((s) => s.return48),
    );
  }
}
