import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_cost_stress_validation.dart';

void main() {
  C5CostCase sample(List<C5CostBar> bars) {
    final time = DateTime.utc(2026, 1, 1);
    return C5CostCase(
      risk: C5CostRisk(
        time: time,
        entryClose: 100,
        stopPrice: 90,
        stopDistance: 10,
      ),
      path: C5CostPath(time: time, bars: bars),
    );
  }

  test('deducts round-trip price cost from target R', () {
    const validation = C5CostStressValidation();
    final result = validation.settle(
      sample(const [C5CostBar(high: 121, low: 99, close: 120)]),
      roundTripCostPrice: 1,
    );

    expect(result.outcome, C5CostOutcome.target);
    expect(result.netR, closeTo(1.9, 1e-12));
  });

  test('deducts round-trip price cost from expiry R', () {
    const validation = C5CostStressValidation();
    final result = validation.settle(
      sample(const [C5CostBar(high: 105, low: 95, close: 104)]),
      roundTripCostPrice: 1,
    );

    expect(result.outcome, C5CostOutcome.expiry);
    expect(result.netR, closeTo(0.3, 1e-12));
  });

  test('same-bar stop and target remains ambiguous', () {
    const validation = C5CostStressValidation();
    final result = validation.settle(
      sample(const [C5CostBar(high: 121, low: 89, close: 100)]),
      roundTripCostPrice: 1,
    );

    expect(result.outcome, C5CostOutcome.ambiguous);
    expect(result.netR, isNull);
  });
}
