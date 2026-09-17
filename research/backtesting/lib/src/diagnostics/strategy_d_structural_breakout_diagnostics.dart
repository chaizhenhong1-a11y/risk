enum StructuralBreakoutDirection { bullish, bearish }

final class StructuralBreakoutSample {
  const StructuralBreakoutSample({
    required this.time,
    required this.direction,
    required this.breakDistanceAtr,
    required this.rangeAtr,
    required this.bodyAtr,
    required this.return12,
    required this.return24,
    required this.return48,
  });

  final DateTime time;
  final StructuralBreakoutDirection direction;
  final double breakDistanceAtr;
  final double rangeAtr;
  final double bodyAtr;
  final double return12;
  final double return24;
  final double return48;

  bool continuation(double value) => switch (direction) {
    StructuralBreakoutDirection.bullish => value > 0,
    StructuralBreakoutDirection.bearish => value < 0,
  };
}

final class StructuralBreakoutSummary {
  const StructuralBreakoutSummary({
    required this.label,
    required this.samples,
    required this.continuation12,
    required this.continuation24,
    required this.continuation48,
  });

  final String label;
  final int samples;
  final double continuation12;
  final double continuation24;
  final double continuation48;
}

/// Research-only structural-breakout discovery.
///
/// Increment 124 deliberately uses frozen buckets. It does not optimize a
/// production Strategy D and the percentages are not trade win rates.
final class StrategyDStructuralBreakoutDiagnostics {
  const StrategyDStructuralBreakoutDiagnostics();

  List<StructuralBreakoutSummary> summarize(
    Iterable<StructuralBreakoutSample> samples,
  ) {
    final input = samples.toList(growable: false);
    final buckets = <String, bool Function(StructuralBreakoutSample)>{
      'all structural breaks': (_) => true,
      'break>=0.10ATR': (s) => s.breakDistanceAtr >= .10,
      'break>=0.25ATR': (s) => s.breakDistanceAtr >= .25,
      'break>=0.50ATR': (s) => s.breakDistanceAtr >= .50,
      'break>=0.10ATR & range>=1.25ATR': (s) =>
          s.breakDistanceAtr >= .10 && s.rangeAtr >= 1.25,
      'break>=0.10ATR & body>=0.75ATR': (s) =>
          s.breakDistanceAtr >= .10 && s.bodyAtr >= .75,
      'break>=0.25ATR & range>=1.50ATR': (s) =>
          s.breakDistanceAtr >= .25 && s.rangeAtr >= 1.50,
      'break>=0.25ATR & body>=1.00ATR': (s) =>
          s.breakDistanceAtr >= .25 && s.bodyAtr >= 1.00,
    };

    return [
      for (final bucket in buckets.entries)
        _summary(bucket.key, input.where(bucket.value).toList(growable: false)),
    ];
  }

  StructuralBreakoutSummary _summary(
    String label,
    List<StructuralBreakoutSample> samples,
  ) {
    if (samples.isEmpty) {
      return StructuralBreakoutSummary(
        label: label,
        samples: 0,
        continuation12: 0,
        continuation24: 0,
        continuation48: 0,
      );
    }

    double rate(double Function(StructuralBreakoutSample) value) =>
        samples.where((s) => s.continuation(value(s))).length / samples.length;

    return StructuralBreakoutSummary(
      label: label,
      samples: samples.length,
      continuation12: rate((s) => s.return12),
      continuation24: rate((s) => s.return24),
      continuation48: rate((s) => s.return48),
    );
  }
}
