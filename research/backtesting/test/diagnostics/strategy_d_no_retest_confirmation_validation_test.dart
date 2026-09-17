import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/diagnostics/strategy_d_no_retest_confirmation_validation.dart';

void main() {
  test('measures outcomes from confirmation in breakout direction', () {
    final result = const StrategyDNoRetestConfirmationValidation().summarize([
      _sample(NoRetestDirection.bullish, 1, 1, -1),
      _sample(NoRetestDirection.bearish, -1, -1, -1),
    ]);

    expect(result.samples, 2);
    expect(result.continuation12, 1);
    expect(result.continuation24, 1);
    expect(result.continuation48, .5);
  });

  test('empty validation set is safe', () {
    final result = const StrategyDNoRetestConfirmationValidation().summarize(
      const [],
    );

    expect(result.samples, 0);
    expect(result.continuation12, 0);
    expect(result.continuation24, 0);
    expect(result.continuation48, 0);
  });
}

NoRetestConfirmationSample _sample(
  NoRetestDirection direction,
  double r12,
  double r24,
  double r48,
) => NoRetestConfirmationSample(
  breakoutTime: DateTime.utc(2026, 1, 1),
  confirmationTime: DateTime.utc(2026, 1, 1, 1),
  direction: direction,
  return12: r12,
  return24: r24,
  return48: r48,
);
