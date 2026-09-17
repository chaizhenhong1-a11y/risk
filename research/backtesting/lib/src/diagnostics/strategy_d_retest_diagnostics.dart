enum BreakoutRetestDirection { bullish, bearish }

enum BreakoutRetestOutcome { noRetest, held, failed }

final class BreakoutRetestSample {
  const BreakoutRetestSample({
    required this.breakoutTime,
    required this.direction,
    required this.outcome,
    required this.retestOffset,
    required this.return12,
    required this.return24,
    required this.return48,
  });

  final DateTime breakoutTime;
  final BreakoutRetestDirection direction;
  final BreakoutRetestOutcome outcome;
  final int? retestOffset;
  final double return12;
  final double return24;
  final double return48;

  bool continuation(double value) => switch (direction) {
    BreakoutRetestDirection.bullish => value > 0,
    BreakoutRetestDirection.bearish => value < 0,
  };
}

final class BreakoutRetestSummary {
  const BreakoutRetestSummary({
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

/// Research-only breakout/retest diagnostics.
/// Frozen buckets; percentages are directional continuation, not trade win rate.
final class StrategyDRetestDiagnostics {
  const StrategyDRetestDiagnostics();

  List<BreakoutRetestSummary> summarize(
    Iterable<BreakoutRetestSample> samples,
  ) {
    final input = samples.toList(growable: false);
    final buckets = <String, bool Function(BreakoutRetestSample)>{
      'all': (_) => true,
      'no retest within 12M5': (s) =>
          s.outcome == BreakoutRetestOutcome.noRetest,
      'retest held': (s) => s.outcome == BreakoutRetestOutcome.held,
      'retest failed': (s) => s.outcome == BreakoutRetestOutcome.failed,
      'held within 3M5': (s) =>
          s.outcome == BreakoutRetestOutcome.held &&
          s.retestOffset != null &&
          s.retestOffset! <= 3,
      'held within 6M5': (s) =>
          s.outcome == BreakoutRetestOutcome.held &&
          s.retestOffset != null &&
          s.retestOffset! <= 6,
    };

    return [
      for (final bucket in buckets.entries)
        _summary(bucket.key, input.where(bucket.value).toList(growable: false)),
    ];
  }

  BreakoutRetestSummary _summary(
    String label,
    List<BreakoutRetestSample> samples,
  ) {
    if (samples.isEmpty) {
      return BreakoutRetestSummary(
        label: label,
        samples: 0,
        continuation12: 0,
        continuation24: 0,
        continuation48: 0,
      );
    }

    double rate(double Function(BreakoutRetestSample) value) =>
        samples.where((s) => s.continuation(value(s))).length / samples.length;

    return BreakoutRetestSummary(
      label: label,
      samples: samples.length,
      continuation12: rate((s) => s.return12),
      continuation24: rate((s) => s.return24),
      continuation48: rate((s) => s.return48),
    );
  }
}
