import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  test('feature discovery groups snapshot samples without changing them', () {
    const samples = <StrategyBCandidateResearchSample>[
      StrategyBCandidateResearchSample(
        direction: StrategyBCandidateDirection.buy,
        rawRiskReward: 3.2,
        targetRoomAtr: 2.0,
        pullbackDepthAtr: null,
        atrRelativeToMedian: 0.7,
        riskEligible: true,
        outcome: StrategyBCandidateOutcome.continuation,
      ),
      StrategyBCandidateResearchSample(
        direction: StrategyBCandidateDirection.sell,
        rawRiskReward: 1.0,
        targetRoomAtr: 0.5,
        pullbackDepthAtr: null,
        atrRelativeToMedian: 1.4,
        riskEligible: false,
        outcome: StrategyBCandidateOutcome.rejection,
      ),
    ];
    const snapshot = StrategyBResearchSnapshot(
      strategyFingerprint: 'strategy',
      datasetFingerprint: 'dataset',
      observedM5Closes: 100,
      records: <StrategyBResearchSnapshotRecord>[],
      samplesByHorizon: {24: samples},
    );

    final report = const StrategyBCandidateFeatureDiscovery().analyze(snapshot);
    final section = report.sections.single;

    expect(section.all.candidates, 2);
    expect(section.all.continuationRate, 0.5);
    expect(section.eligibleOnly.candidates, 1);
    expect(section.eligibleOnly.continuationRate, 1.0);
    expect(
      section.byVolatility[StrategyBVolatilityBucket.compressed]!.candidates,
      1,
    );
    expect(
      section.byVolatility[StrategyBVolatilityBucket.expanded]!.candidates,
      1,
    );
    expect(samples.length, 2);
  });

  test('empty buckets report null rates instead of inventing evidence', () {
    const snapshot = StrategyBResearchSnapshot(
      strategyFingerprint: 'strategy',
      datasetFingerprint: 'dataset',
      observedM5Closes: 0,
      records: <StrategyBResearchSnapshotRecord>[],
      samplesByHorizon: {12: <StrategyBCandidateResearchSample>[]},
    );

    final section = const StrategyBCandidateFeatureDiscovery()
        .analyze(snapshot)
        .sections
        .single;

    expect(section.all.continuationRate, isNull);
    expect(section.all.eligibilityRate, isNull);
  });
}
