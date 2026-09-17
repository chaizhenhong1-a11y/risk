import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/diagnostics/def_expectancy_rescreen_diagnostics.dart';

void main() {
  test('risk is absolute entry-to-stop distance', () {
    final sample = DefSetupSample(
      strategy: DefStrategy.dBreakout,
      observedAt: DateTime.utc(2026, 1, 1),
      isBuy: true,
      entry: 2500,
      stop: 2490,
    );

    expect(sample.risk, 10);
  });
}
