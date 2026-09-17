import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/diagnostics/transition_feature_discovery.dart';

void main() {
  test('separates liquidity feature states', () {
    final discovery = TransitionFeatureDiscovery();

    discovery.observeTransition(
      h4: MarketStructure.bearish,
      h1: MarketStructure.neutral,
      m15: MarketStructure.bearish,
      supportSweep: false,
      resistanceSweep: true,
      equalLowSweep: false,
      equalHighSweep: false,
    );
    discovery.observeExit('trendAligned');

    final row = discovery.finish().rows.single;
    expect(row.samples, 1);
    expect(row.trend, 1);
    expect(row.sweepLabel, 'resistance');
  });
}
