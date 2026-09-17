import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_structural_lifecycle_validation.dart';

void main() {
  C5StructuralCase sample(List<C5StructuralBar> bars) {
    final time = DateTime.utc(2026, 1, 1);
    return C5StructuralCase(
      risk: C5StructuralRisk(
        time: time,
        entryClose: 100,
        m15Atr14: 4,
        supportLowerBound: 95,
        bufferedStopPrice: 93,
        bufferedStopDistance: 7,
      ),
      path: C5StructuralPath(time: time, entryClose: 100, bars: bars),
    );
  }

  test('structural stop and 2R target settle target-first', () {
    const validation = C5StructuralLifecycleValidation();
    final result = validation.settle(
      sample(const [C5StructuralBar(high: 115, low: 99, close: 114)]),
      2,
    );

    expect(result.outcome, C5StructuralOutcome.target);
    expect(result.r, 2);
  });

  test('same-bar structural stop and target is ambiguous', () {
    const validation = C5StructuralLifecycleValidation();
    final result = validation.settle(
      sample(const [C5StructuralBar(high: 115, low: 92, close: 100)]),
      2,
    );

    expect(result.outcome, C5StructuralOutcome.ambiguous);
    expect(result.r, isNull);
  });

  test('joins structural risk and forward paths by episode time', () {
    final time = DateTime.utc(2026, 1, 1);
    const validation = C5StructuralLifecycleValidation();
    final joined = validation.join(
      risks: [
        C5StructuralRisk(
          time: time,
          entryClose: 100,
          m15Atr14: 4,
          supportLowerBound: 95,
          bufferedStopPrice: 93,
          bufferedStopDistance: 7,
        ),
      ],
      paths: [
        C5StructuralPath(
          time: time,
          entryClose: 100,
          bars: const [C5StructuralBar(high: 101, low: 99, close: 100)],
        ),
      ],
    );

    expect(joined, hasLength(1));
  });
}
