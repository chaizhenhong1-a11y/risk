import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/diagnostics/strategy_d_retest_diagnostics.dart';

void main() {
  test('separates held, failed and no-retest samples', () {
    final rows = const StrategyDRetestDiagnostics().summarize([
      _sample(
        BreakoutRetestDirection.bullish,
        BreakoutRetestOutcome.held,
        2,
        1,
      ),
      _sample(
        BreakoutRetestDirection.bearish,
        BreakoutRetestOutcome.failed,
        4,
        1,
      ),
      _sample(
        BreakoutRetestDirection.bullish,
        BreakoutRetestOutcome.noRetest,
        null,
        -1,
      ),
    ]);

    expect(rows.firstWhere((e) => e.label == 'retest held').samples, 1);
    expect(rows.firstWhere((e) => e.label == 'retest failed').samples, 1);
    expect(
      rows.firstWhere((e) => e.label == 'no retest within 12M5').samples,
      1,
    );
    expect(rows.firstWhere((e) => e.label == 'held within 3M5').samples, 1);
  });

  test('continuation is relative to breakout direction', () {
    final rows = const StrategyDRetestDiagnostics().summarize([
      _sample(
        BreakoutRetestDirection.bullish,
        BreakoutRetestOutcome.held,
        2,
        1,
      ),
      _sample(
        BreakoutRetestDirection.bearish,
        BreakoutRetestOutcome.held,
        2,
        -1,
      ),
    ]);
    final held = rows.firstWhere((e) => e.label == 'retest held');

    expect(held.continuation12, 1);
    expect(held.continuation24, 1);
    expect(held.continuation48, 1);
  });
}

BreakoutRetestSample _sample(
  BreakoutRetestDirection direction,
  BreakoutRetestOutcome outcome,
  int? offset,
  double value,
) => BreakoutRetestSample(
  breakoutTime: DateTime.utc(2026),
  direction: direction,
  outcome: outcome,
  retestOffset: offset,
  return12: value,
  return24: value,
  return48: value,
);
