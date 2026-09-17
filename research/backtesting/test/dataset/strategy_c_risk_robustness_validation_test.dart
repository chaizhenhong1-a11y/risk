import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_risk_robustness_validation.dart';

void main() {
  test('splits chronological paths into five windows without loss', () {
    final paths = List.generate(
      10,
      (i) => C5RiskPath(
        time: DateTime.utc(2026, 1, 1).add(Duration(days: i)),
        entryClose: 100,
        bars: const [C5RiskBar(high: 102, low: 99, close: 101)],
      ),
    );

    const validation = C5RiskRobustnessValidation();
    const config = C5RiskConfiguration(stopDistance: 10, rewardMultiple: 2);
    final windows = validation.evaluateFiveWindows(paths, config);

    expect(windows, hasLength(5));
    expect(windows.fold<int>(0, (sum, w) => sum + w.samples), 10);
    expect(windows.every((w) => w.samples == 2), isTrue);
  });
}
