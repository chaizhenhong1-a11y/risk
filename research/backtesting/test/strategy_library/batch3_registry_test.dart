import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/strategy_library/strategy_registry.dart';

void main() {
  test('Batch 3 adds eight research-only formulations', () {
    const ids = <String>{
      'FAILED_BREAKOUT_V2',
      'SR_RECLAIM_V2',
      'PIN_BAR_REVERSAL',
      'ENGULFING_REVERSAL',
      'NR7_BREAKOUT',
      'EMA_TREND_RECLAIM',
      'VOL_SPIKE_FADE',
      'THREE_BAR_PULLBACK',
    };

    const registry = StrategyRegistry();
    final research = registry.research
        .where((s) => ids.contains(s.id))
        .toList();

    expect(research, hasLength(ids.length));
    expect(
      research.every((s) => s.lifecycle == StrategyLifecycle.researchOnly),
      isTrue,
    );
    expect(
      registry.production.map((s) => s.id),
      containsAll(<String>['A', 'C5']),
    );
  });
}
