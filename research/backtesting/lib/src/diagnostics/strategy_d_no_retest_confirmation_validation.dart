enum NoRetestDirection { bullish, bearish }

final class NoRetestConfirmationSample {
  const NoRetestConfirmationSample({
    required this.breakoutTime,
    required this.confirmationTime,
    required this.direction,
    required this.return12,
    required this.return24,
    required this.return48,
  });

  final DateTime breakoutTime;
  final DateTime confirmationTime;
  final NoRetestDirection direction;
  final double return12;
  final double return24;
  final double return48;

  bool continuation(double value) => switch (direction) {
    NoRetestDirection.bullish => value > 0,
    NoRetestDirection.bearish => value < 0,
  };
}

final class NoRetestConfirmationSummary {
  const NoRetestConfirmationSummary({
    required this.samples,
    required this.continuation12,
    required this.continuation24,
    required this.continuation48,
  });

  final int samples;
  final double continuation12;
  final double continuation24;
  final double continuation48;
}

/// Research-only validation of the tradable no-retest hypothesis.
///
/// A signal is observable only after 12 fully closed M5 bars have passed
/// without touching the broken structural level. Forward outcomes therefore
/// begin at that confirmation close, never at the original breakout close.
final class StrategyDNoRetestConfirmationValidation {
  const StrategyDNoRetestConfirmationValidation();

  NoRetestConfirmationSummary summarize(
    Iterable<NoRetestConfirmationSample> samples,
  ) {
    final input = samples.toList(growable: false);
    if (input.isEmpty) {
      return const NoRetestConfirmationSummary(
        samples: 0,
        continuation12: 0,
        continuation24: 0,
        continuation48: 0,
      );
    }

    double rate(double Function(NoRetestConfirmationSample) value) =>
        input.where((s) => s.continuation(value(s))).length / input.length;

    return NoRetestConfirmationSummary(
      samples: input.length,
      continuation12: rate((s) => s.return12),
      continuation24: rate((s) => s.return24),
      continuation48: rate((s) => s.return48),
    );
  }
}
