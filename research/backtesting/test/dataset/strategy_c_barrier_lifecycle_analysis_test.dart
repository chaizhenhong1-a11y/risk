import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_barrier_lifecycle_analysis.dart';

void main() {
  const analysis = C5BarrierLifecycleAnalysis();

  test('classifies target before stop', () {
    const path = C5BarrierPath(
      entryClose: 100,
      bars: [
        C5BarrierBar(offset: 1, high: 103, low: 99),
        C5BarrierBar(offset: 2, high: 105, low: 99),
      ],
    );

    expect(
      analysis.classify(path, stopDistance: 2, rewardMultiple: 2),
      BarrierOutcome.targetFirst,
    );
  });

  test('marks same-bar stop and target as ambiguous', () {
    const path = C5BarrierPath(
      entryClose: 100,
      bars: [C5BarrierBar(offset: 1, high: 105, low: 97)],
    );

    expect(
      analysis.classify(path, stopDistance: 2, rewardMultiple: 2),
      BarrierOutcome.ambiguousSameBar,
    );
  });
}
