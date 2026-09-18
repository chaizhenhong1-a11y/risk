import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/strategy_library/batch3_research_selection.dart';
import 'package:tradeforge_backtesting/src/strategy_library/strategy_registry.dart';

void main() {
  test('Batch 3 selection freezes exactly the six first-gate hypotheses', () {
    expect(Batch3ResearchSelection.historicalPassIds, <String>{
      'FAILED_BREAKOUT_V2',
      'SR_RECLAIM_V2',
      'ENGULFING_REVERSAL',
      'NR7_BREAKOUT',
      'EMA_TREND_RECLAIM',
      'THREE_BAR_PULLBACK',
    });
  });

  test('Batch 3 selection remains research-only', () {
    const registry = StrategyRegistry();
    final selected = registry.research
        .where(
          (strategy) =>
              Batch3ResearchSelection.historicalPassIds.contains(strategy.id),
        )
        .toList(growable: false);

    expect(
      selected,
      hasLength(Batch3ResearchSelection.historicalPassIds.length),
    );
    expect(registry.production.map((strategy) => strategy.id), <String>[
      'A',
      'C5',
    ]);
  });
}
