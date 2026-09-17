enum EmergenceDirection { bullish, bearish }

final class DirectionEmergenceSample {
  const DirectionEmergenceSample({
    required this.neutralStartedAt,
    required this.emergedAt,
    required this.direction,
    required this.return12,
    required this.return24,
    required this.return48,
  });

  final DateTime neutralStartedAt;
  final DateTime emergedAt;
  final EmergenceDirection direction;
  final double return12;
  final double return24;
  final double return48;

  bool continued(double value) => switch (direction) {
    EmergenceDirection.bullish => value > 0,
    EmergenceDirection.bearish => value < 0,
  };
}

final class DirectionEmergenceSummary {
  const DirectionEmergenceSummary({
    required this.samples,
    required this.days,
    required this.bullishSamples,
    required this.bearishSamples,
    required this.continuation12,
    required this.continuation24,
    required this.continuation48,
  });

  final int samples;
  final int days;
  final int bullishSamples;
  final int bearishSamples;
  final double continuation12;
  final double continuation24;
  final double continuation48;
}

final class NeutralTransitionDirectionEmergenceDiagnostics {
  const NeutralTransitionDirectionEmergenceDiagnostics();

  DirectionEmergenceSummary summarize(
    Iterable<DirectionEmergenceSample> samples,
  ) {
    final input = samples.toList(growable: false);
    if (input.isEmpty) {
      return const DirectionEmergenceSummary(
        samples: 0,
        days: 0,
        bullishSamples: 0,
        bearishSamples: 0,
        continuation12: 0,
        continuation24: 0,
        continuation48: 0,
      );
    }

    final days = input
        .map(
          (sample) => DateTime.utc(
            sample.emergedAt.year,
            sample.emergedAt.month,
            sample.emergedAt.day,
          ),
        )
        .toSet();

    double rate(double Function(DirectionEmergenceSample) value) =>
        input.where((sample) => sample.continued(value(sample))).length /
        input.length;

    return DirectionEmergenceSummary(
      samples: input.length,
      days: days.length,
      bullishSamples: input
          .where((sample) => sample.direction == EmergenceDirection.bullish)
          .length,
      bearishSamples: input
          .where((sample) => sample.direction == EmergenceDirection.bearish)
          .length,
      continuation12: rate((sample) => sample.return12),
      continuation24: rate((sample) => sample.return24),
      continuation48: rate((sample) => sample.return48),
    );
  }
}
