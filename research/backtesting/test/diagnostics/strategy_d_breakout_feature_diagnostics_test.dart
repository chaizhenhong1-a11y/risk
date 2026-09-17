import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/diagnostics/strategy_d_breakout_feature_diagnostics.dart';

void main() {
  test('measures continuation in candle expansion direction', () {
    final rows = const StrategyDBreakoutFeatureDiagnostics().summarize([
      _sample(BreakoutExpansionDirection.bullish, 1.6, .8, 1, 1, 1),
      _sample(BreakoutExpansionDirection.bullish, 1.7, .9, -1, 1, 1),
      _sample(BreakoutExpansionDirection.bearish, 1.8, 1, -1, -1, 1),
    ]);

    final row = rows.firstWhere(
      (e) => e.label == 'range>=1.50ATR & body>=0.75ATR',
    );
    expect(row.samples, 3);
    expect(row.continuation12, closeTo(2 / 3, 1e-9));
    expect(row.continuation24, 1);
    expect(row.continuation48, closeTo(2 / 3, 1e-9));
  });

  test('reports empty buckets safely', () {
    final rows = const StrategyDBreakoutFeatureDiagnostics().summarize([
      _sample(BreakoutExpansionDirection.bullish, 1, .2, 1, 1, 1),
    ]);
    final row = rows.firstWhere((e) => e.label == 'range>=2.00ATR');
    expect(row.samples, 0);
    expect(row.continuation48, 0);
  });
}

BreakoutExpansionSample _sample(
  BreakoutExpansionDirection direction,
  double rangeAtr,
  double bodyAtr,
  double r12,
  double r24,
  double r48,
) => BreakoutExpansionSample(
  time: DateTime.utc(2026),
  direction: direction,
  rangeAtr: rangeAtr,
  bodyAtr: bodyAtr,
  return12: r12,
  return24: r24,
  return48: r48,
);
