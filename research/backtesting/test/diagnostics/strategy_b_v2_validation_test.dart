import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:test/test.dart';

void main() {
  const validation = StrategyBV2Validation();

  StrategyBResearchSnapshotRecord record(double body, {bool eligible = true}) {
    return StrategyBResearchSnapshotRecord(
      index: 1,
      direction: StrategyBCandidateDirection.buy,
      rawRiskReward: 2.5,
      targetRoomAtr: 2.5,
      atr: 1,
      atrRelativeToRollingMedian: 1,
      riskEligible: eligible,
      h1CorrectionExcursionAtr: 3,
      h1CorrectionDurationBars: 4,
      m15RealignmentBodyAtr: body,
      m15DirectionalCloseLocation: .8,
    );
  }

  StrategyBCandidateResearchSample sample(StrategyBCandidateOutcome outcome) {
    return StrategyBCandidateResearchSample(
      direction: StrategyBCandidateDirection.buy,
      rawRiskReward: 2.5,
      targetRoomAtr: 2.5,
      pullbackDepthAtr: null,
      atrRelativeToMedian: 1,
      riskEligible: true,
      outcome: outcome,
    );
  }

  test('matches only RR-eligible records in frozen 0.50-1.00 ATR band', () {
    expect(validation.matchesRecord(record(.49)), isFalse);
    expect(validation.matchesRecord(record(.50)), isTrue);
    expect(validation.matchesRecord(record(.999)), isTrue);
    expect(validation.matchesRecord(record(1.0)), isFalse);
    expect(validation.matchesRecord(record(.75, eligible: false)), isFalse);
  });

  test('summarizes only frozen-hypothesis subset', () {
    final summary = validation.summarize(
      horizonM5: 24,
      records: [record(.75), record(.3), record(.8)],
      samples: [
        sample(StrategyBCandidateOutcome.continuation),
        sample(StrategyBCandidateOutcome.continuation),
        sample(StrategyBCandidateOutcome.rejection),
      ],
    );
    expect(summary.candidates, 2);
    expect(summary.continuation, 1);
    expect(summary.rejection, 1);
    expect(summary.unresolved, 0);
    expect(summary.resolvedContinuationRate, .5);
  });

  test('rejects record/sample misalignment', () {
    expect(
      () => validation.summarize(
        horizonM5: 12,
        records: [record(.75)],
        samples: const [],
      ),
      throwsStateError,
    );
  });
}
