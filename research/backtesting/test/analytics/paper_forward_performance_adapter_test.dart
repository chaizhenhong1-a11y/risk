import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/analytics/paper_forward_performance_adapter.dart';

void main() {
  test('preserves chronological paper-forward outcomes for max drawdown', () {
    final result = const PaperForwardPerformanceAdapter().analyze([
      _result('C5', 'BUY', 4, 1),
      _result('C5', 'BUY', 1, 3),
      _result('C5', 'BUY', 3, -2),
      _result('C5', 'BUY', 2, -1),
    ]);

    expect(result.overall.tradeCount, 4);
    expect(result.overall.totalR, 1);
    expect(result.overall.maxDrawdownR, 3);
  });

  test('keeps strategies and BUY SELL sides independent', () {
    final result = const PaperForwardPerformanceAdapter().analyze([
      _result('C5', 'BUY', 1, 2),
      _result('C5', 'SELL', 2, -1),
      _result('ADX_TREND', 'BUY', 3, 2),
    ]);

    expect(result.byStrategy['C5']?.tradeCount, 2);
    expect(result.byStrategy['ADX_TREND']?.tradeCount, 1);
    expect(result.byStrategyAndSide['C5']?['BUY']?.totalR, 2);
    expect(result.byStrategyAndSide['C5']?['SELL']?.totalR, -1);
  });

  test('ignores non-finite realized R safely', () {
    final result = const PaperForwardPerformanceAdapter().analyze([
      _result('C5', 'BUY', 1, double.nan),
      _result('C5', 'BUY', 2, 2),
    ]);

    expect(result.overall.tradeCount, 1);
    expect(result.overall.totalR, 2);
  });
}

PaperForwardResult _result(String strategy, String side, int hour, double r) =>
    PaperForwardResult(
      strategy: strategy,
      side: side,
      observedAt: DateTime.utc(2026, 9, 18, hour),
      realizedR: r,
    );
