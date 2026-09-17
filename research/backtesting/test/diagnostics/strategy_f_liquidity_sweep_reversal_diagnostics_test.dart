import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/diagnostics/strategy_f_liquidity_sweep_reversal_diagnostics.dart';

void main() {
  test('support and resistance sweeps use opposite reversal directions', () {
    final rows = const StrategyFLiquiditySweepReversalDiagnostics().summarize([
      _sample(LiquiditySweepSide.support, true, 1),
      _sample(LiquiditySweepSide.resistance, true, -1),
      _sample(LiquiditySweepSide.resistance, true, 1),
    ]);

    final reclaimed = rows.firstWhere(
      (row) => row.label == 'sweep + same-bar reclaim',
    );

    expect(reclaimed.samples, 3);
    expect(reclaimed.reversal12, closeTo(2 / 3, 1e-9));
    expect(reclaimed.reversal24, closeTo(2 / 3, 1e-9));
    expect(reclaimed.reversal48, closeTo(2 / 3, 1e-9));
  });

  test('empty bucket is safe', () {
    final rows = const StrategyFLiquiditySweepReversalDiagnostics().summarize([
      _sample(LiquiditySweepSide.support, true, 1),
    ]);

    final noReclaim = rows.firstWhere(
      (row) => row.label == 'sweep without same-bar reclaim',
    );

    expect(noReclaim.samples, 0);
    expect(noReclaim.reversal48, 0);
  });
}

LiquiditySweepReversalSample _sample(
  LiquiditySweepSide side,
  bool reclaimed,
  double value,
) => LiquiditySweepReversalSample(
  time: DateTime.utc(2026),
  side: side,
  reclaimed: reclaimed,
  return12: value,
  return24: value,
  return48: value,
);
