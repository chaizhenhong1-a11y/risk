import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/diagnostics/strategy_d_structural_breakout_diagnostics.dart';

void main() {
  test('measures continuation in structural-break direction', () {
    final rows = const StrategyDStructuralBreakoutDiagnostics().summarize([
      _sample(StructuralBreakoutDirection.bullish, .3, 1.6, .8, 1, 1, 1),
      _sample(StructuralBreakoutDirection.bullish, .4, 1.7, .9, -1, 1, 1),
      _sample(StructuralBreakoutDirection.bearish, .3, 1.8, 1, -1, -1, 1),
    ]);

    final row = rows.firstWhere(
      (e) => e.label == 'break>=0.10ATR & range>=1.25ATR',
    );
    expect(row.samples, 3);
    expect(row.continuation12, closeTo(2 / 3, 1e-9));
    expect(row.continuation24, 1);
    expect(row.continuation48, closeTo(2 / 3, 1e-9));
  });

  test('empty bucket is safe', () {
    final rows = const StrategyDStructuralBreakoutDiagnostics().summarize([
      _sample(StructuralBreakoutDirection.bullish, .1, 1, .2, 1, 1, 1),
    ]);

    final row = rows.firstWhere((e) => e.label == 'break>=0.50ATR');
    expect(row.samples, 0);
    expect(row.continuation48, 0);
  });
}

StructuralBreakoutSample _sample(
  StructuralBreakoutDirection direction,
  double breakDistanceAtr,
  double rangeAtr,
  double bodyAtr,
  double r12,
  double r24,
  double r48,
) => StructuralBreakoutSample(
  time: DateTime.utc(2026),
  direction: direction,
  breakDistanceAtr: breakDistanceAtr,
  rangeAtr: rangeAtr,
  bodyAtr: bodyAtr,
  return12: r12,
  return24: r24,
  return48: r48,
);
