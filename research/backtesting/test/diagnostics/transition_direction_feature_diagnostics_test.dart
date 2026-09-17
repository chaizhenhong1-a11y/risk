import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/diagnostics/transition_direction_feature_diagnostics.dart';

void main() {
  test('records transition feature outcome and wait length', () {
    final diagnostics = TransitionDirectionFeatureDiagnostics();

    diagnostics.observeTransition(
      h4: MarketStructure.bullish,
      h1: MarketStructure.neutral,
      m15: MarketStructure.bullish,
      directionalSweepEvidencePresent: true,
    );
    diagnostics.observeTransition(
      h4: MarketStructure.bullish,
      h1: MarketStructure.neutral,
      m15: MarketStructure.bullish,
      directionalSweepEvidencePresent: true,
    );
    diagnostics.observeNonTransition(regimeName: 'trendAligned');

    final report = diagnostics.finish();
    expect(report.rows, hasLength(1));
    expect(report.rows.single.samples, 1);
    expect(report.rows.single.trendAligned, 1);
    expect(report.rows.single.correction, 0);
    expect(report.rows.single.averageWaitObservations, 2);
  });
}
