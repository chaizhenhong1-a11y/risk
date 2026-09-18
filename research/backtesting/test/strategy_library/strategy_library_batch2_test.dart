import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/strategy_library/strategy_registry.dart';

void main() {
  test('batch 2 research strategies are registered without promotion', () {
    const ids = {
      'FAILED_BREAKOUT',
      'VOL_COMPRESSION_BREAK',
      'SR_RECLAIM',
      'IMPULSE_PULLBACK',
      'SWEEP_STRUCTURE',
      'EMA_MEAN_REVERT',
      'INSIDE_BAR_BREAK',
      'TWO_BAR_MOMENTUM',
    };

    final researchIds = const StrategyRegistry().research
        .map((e) => e.id)
        .toSet();
    expect(researchIds.containsAll(ids), isTrue);

    for (final strategy in StrategyRegistry.all.where(
      (e) => ids.contains(e.id),
    )) {
      expect(strategy.lifecycle, StrategyLifecycle.researchOnly);
    }
  });
}
