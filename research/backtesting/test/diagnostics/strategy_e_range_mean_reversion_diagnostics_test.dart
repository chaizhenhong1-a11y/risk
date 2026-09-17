import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/diagnostics/strategy_e_range_mean_reversion_diagnostics.dart';

void main() {
  test('measures reversal relative to range extreme', () {
    final rows = const StrategyERangeMeanReversionDiagnostics().summarize([
      _sample(RangeReversionSide.lowerExtreme, .1, 3, 1),
      _sample(RangeReversionSide.upperExtreme, .9, 3, -1),
      _sample(RangeReversionSide.upperExtreme, .9, 3, 1),
    ]);

    final outer = rows.firstWhere((row) => row.label == 'outer 15%');
    expect(outer.samples, 3);
    expect(outer.reversion12, closeTo(2 / 3, 1e-9));
    expect(outer.reversion24, closeTo(2 / 3, 1e-9));
    expect(outer.reversion48, closeTo(2 / 3, 1e-9));
  });

  test('empty bucket is safe', () {
    final rows = const StrategyERangeMeanReversionDiagnostics().summarize([
      _sample(RangeReversionSide.lowerExtreme, .19, 1, 1),
    ]);
    final row = rows.firstWhere(
      (row) => row.label == 'outer 15% & width>=3ATR',
    );
    expect(row.samples, 0);
    expect(row.reversion48, 0);
  });
}

RangeReversionSample _sample(
  RangeReversionSide side,
  double position,
  double widthAtr,
  double value,
) => RangeReversionSample(
  time: DateTime.utc(2026),
  side: side,
  rangePosition: position,
  rangeWidthAtr: widthAtr,
  return12: value,
  return24: value,
  return48: value,
);
