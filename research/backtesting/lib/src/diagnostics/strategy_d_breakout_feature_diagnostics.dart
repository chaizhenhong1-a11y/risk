enum BreakoutExpansionDirection { bullish, bearish }

final class BreakoutExpansionSample {
  const BreakoutExpansionSample({
    required this.time,
    required this.direction,
    required this.rangeAtr,
    required this.bodyAtr,
    required this.return12,
    required this.return24,
    required this.return48,
  });

  final DateTime time;
  final BreakoutExpansionDirection direction;
  final double rangeAtr;
  final double bodyAtr;
  final double return12;
  final double return24;
  final double return48;

  bool continuation(double value) => switch (direction) {
    BreakoutExpansionDirection.bullish => value > 0,
    BreakoutExpansionDirection.bearish => value < 0,
  };
}

final class BreakoutExpansionSummary {
  const BreakoutExpansionSummary({
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

/// Discovery diagnostics only. These buckets are not Strategy D production
/// rules and must not be interpreted as win rates.
final class StrategyDBreakoutFeatureDiagnostics {
  const StrategyDBreakoutFeatureDiagnostics();

  List<BreakoutExpansionSummary> summarize(
    Iterable<BreakoutExpansionSample> samples,
  ) {
    final input = samples.toList(growable: false);
    final buckets = <String, bool Function(BreakoutExpansionSample)>{
      'range>=1.25ATR': (s) => s.rangeAtr >= 1.25,
      'range>=1.50ATR': (s) => s.rangeAtr >= 1.50,
      'range>=2.00ATR': (s) => s.rangeAtr >= 2.00,
      'body>=0.75ATR': (s) => s.bodyAtr >= 0.75,
      'body>=1.00ATR': (s) => s.bodyAtr >= 1.00,
      'range>=1.50ATR & body>=0.75ATR': (s) =>
          s.rangeAtr >= 1.50 && s.bodyAtr >= 0.75,
    };

    return [
      for (final bucket in buckets.entries)
        _summarize(bucket.key, input.where(bucket.value).toList()),
    ];
  }

  BreakoutExpansionSummary _summarize(
    String label,
    List<BreakoutExpansionSample> samples,
  ) {
    if (samples.isEmpty) {
      return BreakoutExpansionSummary(
        label: label,
        samples: 0,
        continuation12: 0,
        continuation24: 0,
        continuation48: 0,
      );
    }

    double rate(double Function(BreakoutExpansionSample) value) =>
        samples.where((s) => s.continuation(value(s))).length / samples.length;

    return BreakoutExpansionSummary(
      label: label,
      samples: samples.length,
      continuation12: rate((s) => s.return12),
      continuation24: rate((s) => s.return24),
      continuation48: rate((s) => s.return48),
    );
  }
}
