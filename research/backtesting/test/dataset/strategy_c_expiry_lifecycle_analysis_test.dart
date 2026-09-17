import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_expiry_lifecycle_analysis.dart';

void main() {
  const analysis = C5ExpiryLifecycleAnalysis();

  test('settles unresolved path at expiry close in R', () {
    const path = C5ExpiryPath(
      entryClose: 100,
      bars: [C5ExpiryBar(high: 103, low: 98, close: 102)],
    );
    final trade = analysis.settle(path, stopDistance: 5, rewardMultiple: 2);
    expect(trade.outcome, C5ExpiryOutcome.expiry);
    expect(trade.r, closeTo(.4, 1e-9));
  });

  test('ambiguous same-bar touch is excluded from expectancy', () {
    const path = C5ExpiryPath(
      entryClose: 100,
      bars: [C5ExpiryBar(high: 111, low: 94, close: 105)],
    );
    final trade = analysis.settle(path, stopDistance: 5, rewardMultiple: 2);
    expect(trade.outcome, C5ExpiryOutcome.ambiguous);
    expect(trade.r, isNull);
  });
}
