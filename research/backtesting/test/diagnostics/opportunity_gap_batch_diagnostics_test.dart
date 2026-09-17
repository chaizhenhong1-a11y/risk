import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/diagnostics/opportunity_gap_batch_diagnostics.dart';

void main() {
  test('summarizes continuation and chronological stability', () {
    final samples = [
      GapEpisodeSample(
        stateId: 'x',
        startedAt: DateTime.utc(2025, 1, 1),
        direction: MarketStructure.bullish,
        return12: 1,
        return24: 1,
        return48: -1,
      ),
      GapEpisodeSample(
        stateId: 'x',
        startedAt: DateTime.utc(2025, 1, 2),
        direction: MarketStructure.bearish,
        return12: -1,
        return24: -1,
        return48: -1,
      ),
    ];

    final result = const OpportunityGapBatchDiagnostics().summarize(
      'x',
      samples,
    );

    expect(result.samples, 2);
    expect(result.days, 2);
    expect(result.bullishSamples, 1);
    expect(result.bearishSamples, 1);
    expect(result.rate12, 1);
    expect(result.rate24, 1);
    expect(result.rate48, .5);
    expect(result.firstHalfRate24, 1);
    expect(result.secondHalfRate24, 1);
  });
}
