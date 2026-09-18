import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/strategy_library/batch2_research_selection.dart';

void main() {
  test('Batch 2 selection freezes exactly the four first-gate hypotheses', () {
    expect(Batch2ResearchSelection.historicalPassIds, {
      'VOL_COMPRESSION_BREAK',
      'SWEEP_STRUCTURE',
      'EMA_MEAN_REVERT',
      'INSIDE_BAR_BREAK',
    });
  });
}
