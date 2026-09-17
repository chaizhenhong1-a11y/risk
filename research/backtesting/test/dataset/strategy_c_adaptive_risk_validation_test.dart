import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_adaptive_risk_validation.dart';

void main() {
  test('entry range produces an adaptive stop distance', () {
    final path = C5AdaptivePath(
      time: DateTime.utc(2026),
      entryHigh: 110,
      entryLow: 100,
      entryClose: 105,
      bars: const [C5AdaptiveBar(high: 126, low: 104, close: 120)],
    );
    final config = c5AdaptiveConfigs().first;
    expect(config.stopDistance(path), 10);

    const validation = C5AdaptiveRiskValidation();
    final result = validation.settle(path, config);
    expect(result!.outcome, C5AdaptiveOutcome.target);
    expect(result.r, 2);
  });
}
