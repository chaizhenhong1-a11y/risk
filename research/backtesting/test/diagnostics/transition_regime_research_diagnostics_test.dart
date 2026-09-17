import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/diagnostics/transition_regime_research_diagnostics.dart';

void main() {
  test('classifies transition structure pairs deterministically', () {
    expect(
      TransitionRegimeResearchDiagnostics.classifyPair(
        MarketStructure.bullish,
        MarketStructure.neutral,
      ),
      TransitionStructurePair.bullishNeutral,
    );
    expect(
      TransitionRegimeResearchDiagnostics.classifyPair(
        MarketStructure.neutral,
        MarketStructure.bearish,
      ),
      TransitionStructurePair.neutralBearish,
    );
  });

  test('tracks observations, M15 structure and episode exits', () {
    final diagnostics = TransitionRegimeResearchDiagnostics();
    diagnostics.observeTransition(
      h4: MarketStructure.bullish,
      h1: MarketStructure.neutral,
      m15: MarketStructure.bullish,
    );
    diagnostics.observeTransition(
      h4: MarketStructure.bullish,
      h1: MarketStructure.neutral,
      m15: MarketStructure.neutral,
    );
    diagnostics.observeExit('trendAligned');

    final report = diagnostics.report();

    expect(report.totalObservations, 2);
    expect(report.episodeLengths, [2]);
    expect(report.exits['bullishNeutral->trendAligned'], 1);
  });
}
