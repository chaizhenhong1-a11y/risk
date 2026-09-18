import 'package:test/test.dart';

import 'package:tradeforge_backtesting/src/strategy_library/strategy_registry.dart';

void main() {
  test('only frozen A and C5 are production eligible', () {
    const registry = StrategyRegistry();
    expect(registry.production.map((s) => s.id), ['A', 'C5']);
    expect(registry.research.length, 34);
    expect(
      registry.research.every(
        (s) => s.lifecycle == StrategyLifecycle.researchOnly,
      ),
      isTrue,
    );
  });

  test('research library covers distinct market families', () {
    const registry = StrategyRegistry();
    final families = registry.research.map((s) => s.family).toSet();
    expect(
      families,
      containsAll(<StrategyMarketFamily>{
        StrategyMarketFamily.trend,
        StrategyMarketFamily.pullback,
        StrategyMarketFamily.momentum,
        StrategyMarketFamily.breakout,
        StrategyMarketFamily.range,
        StrategyMarketFamily.reversal,
        StrategyMarketFamily.transition,
        StrategyMarketFamily.volatility,
      }),
    );
  });
}
