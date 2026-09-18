import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_structural_lifecycle_validation.dart';
import 'package:tradeforge_backtesting/src/validation/c5_expectancy_adapter.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_expectancy_validator.dart';

void main() {
  final risk = C5StructuralRisk(
    time: DateTime.utc(2026, 1, 1),
    entryClose: 2500,
    m15Atr14: 10,
    supportLowerBound: 2488,
    bufferedStopPrice: 2483,
    bufferedStopDistance: 17,
  );
  final path = C5StructuralPath(
    time: DateTime.utc(2026, 1, 1),
    entryClose: 2500,
    bars: const [C5StructuralBar(high: 2534, low: 2490, close: 2520)],
  );

  test('maps frozen C5 target settlement to a 2R win', () {
    final sample = C5StructuralCase(risk: risk, path: path);
    final settlement = const C5StructuralLifecycleValidation().settle(
      sample,
      2,
    );
    final trade = const C5ExpectancyAdapter().convert(sample, settlement);

    expect(trade.resolution, TradeResolution.win);
    expect(trade.rewardRisk, 2);
  });

  test('keeps C5 expiry unresolved for common expectancy audit', () {
    final expiryPath = C5StructuralPath(
      time: risk.time,
      entryClose: 2500,
      bars: const [C5StructuralBar(high: 2505, low: 2490, close: 2502)],
    );
    final sample = C5StructuralCase(risk: risk, path: expiryPath);
    final settlement = const C5StructuralLifecycleValidation().settle(
      sample,
      2,
    );
    final trade = const C5ExpectancyAdapter().convert(sample, settlement);

    expect(trade.resolution, TradeResolution.expired);
  });
}
