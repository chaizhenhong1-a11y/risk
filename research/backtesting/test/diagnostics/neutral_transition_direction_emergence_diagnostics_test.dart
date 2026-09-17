import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/diagnostics/neutral_transition_direction_emergence_diagnostics.dart';

void main() {
  test('measures continuation in the newly emerged direction', () {
    final result = const NeutralTransitionDirectionEmergenceDiagnostics()
        .summarize([
          _sample(EmergenceDirection.bullish, 1),
          _sample(EmergenceDirection.bearish, -1),
          _sample(EmergenceDirection.bearish, 1),
        ]);

    expect(result.samples, 3);
    expect(result.bullishSamples, 1);
    expect(result.bearishSamples, 2);
    expect(result.continuation12, closeTo(2 / 3, 1e-9));
    expect(result.continuation24, closeTo(2 / 3, 1e-9));
    expect(result.continuation48, closeTo(2 / 3, 1e-9));
  });

  test('counts distinct emergence days', () {
    final result = const NeutralTransitionDirectionEmergenceDiagnostics()
        .summarize([
          _sample(EmergenceDirection.bullish, 1, day: 1),
          _sample(EmergenceDirection.bearish, -1, day: 1),
          _sample(EmergenceDirection.bullish, 1, day: 2),
        ]);

    expect(result.days, 2);
  });
}

DirectionEmergenceSample _sample(
  EmergenceDirection direction,
  double value, {
  int day = 1,
}) => DirectionEmergenceSample(
  neutralStartedAt: DateTime.utc(2026, 1, day),
  emergedAt: DateTime.utc(2026, 1, day, 1),
  direction: direction,
  return12: value,
  return24: value,
  return48: value,
);
