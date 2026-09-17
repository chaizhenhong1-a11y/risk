enum LiquiditySweepSide { support, resistance }

final class LiquiditySweepReversalSample {
  const LiquiditySweepReversalSample({
    required this.time,
    required this.side,
    required this.reclaimed,
    required this.return12,
    required this.return24,
    required this.return48,
  });

  final DateTime time;
  final LiquiditySweepSide side;
  final bool reclaimed;
  final double return12;
  final double return24;
  final double return48;

  bool reversed(double value) => switch (side) {
    LiquiditySweepSide.support => value > 0,
    LiquiditySweepSide.resistance => value < 0,
  };
}

final class LiquiditySweepReversalSummary {
  const LiquiditySweepReversalSummary({
    required this.label,
    required this.samples,
    required this.reversal12,
    required this.reversal24,
    required this.reversal48,
  });

  final String label;
  final int samples;
  final double reversal12;
  final double reversal24;
  final double reversal48;
}

/// Strategy F discovery diagnostics.
///
/// Buckets are declared before inspecting outcomes. Percentages describe
/// directional reversal only; they are not trade win rates.
final class StrategyFLiquiditySweepReversalDiagnostics {
  const StrategyFLiquiditySweepReversalDiagnostics();

  List<LiquiditySweepReversalSummary> summarize(
    Iterable<LiquiditySweepReversalSample> samples,
  ) {
    final input = samples.toList(growable: false);

    return [
      _summary('all sweeps', input),
      _summary(
        'sweep + same-bar reclaim',
        input.where((sample) => sample.reclaimed).toList(growable: false),
      ),
      _summary(
        'sweep without same-bar reclaim',
        input.where((sample) => !sample.reclaimed).toList(growable: false),
      ),
      _summary(
        'support sweep + reclaim',
        input
            .where(
              (sample) =>
                  sample.side == LiquiditySweepSide.support && sample.reclaimed,
            )
            .toList(growable: false),
      ),
      _summary(
        'resistance sweep + reclaim',
        input
            .where(
              (sample) =>
                  sample.side == LiquiditySweepSide.resistance &&
                  sample.reclaimed,
            )
            .toList(growable: false),
      ),
    ];
  }

  LiquiditySweepReversalSummary _summary(
    String label,
    List<LiquiditySweepReversalSample> samples,
  ) {
    if (samples.isEmpty) {
      return LiquiditySweepReversalSummary(
        label: label,
        samples: 0,
        reversal12: 0,
        reversal24: 0,
        reversal48: 0,
      );
    }

    double rate(double Function(LiquiditySweepReversalSample) value) =>
        samples.where((sample) => sample.reversed(value(sample))).length /
        samples.length;

    return LiquiditySweepReversalSummary(
      label: label,
      samples: samples.length,
      reversal12: rate((sample) => sample.return12),
      reversal24: rate((sample) => sample.return24),
      reversal48: rate((sample) => sample.return48),
    );
  }
}
