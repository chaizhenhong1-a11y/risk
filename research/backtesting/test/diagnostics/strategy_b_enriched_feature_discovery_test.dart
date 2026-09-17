import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:test/test.dart';

void main() {
  test(
    'groups enriched candidate-time features without changing eligibility',
    () {
      final records = [
        const StrategyBResearchSnapshotRecord(
          index: 1,
          direction: StrategyBCandidateDirection.buy,
          rawRiskReward: 3,
          targetRoomAtr: 2,
          atr: 2,
          atrRelativeToRollingMedian: .8,
          riskEligible: true,
          h1CorrectionExcursionAtr: .8,
          h1CorrectionDurationBars: 2,
          m15RealignmentBodyAtr: .6,
          m15DirectionalCloseLocation: .9,
        ),
        const StrategyBResearchSnapshotRecord(
          index: 2,
          direction: StrategyBCandidateDirection.sell,
          rawRiskReward: 1,
          targetRoomAtr: .5,
          atr: 2,
          atrRelativeToRollingMedian: 1.2,
          riskEligible: false,
          h1CorrectionExcursionAtr: 3,
          h1CorrectionDurationBars: 8,
          m15RealignmentBodyAtr: .1,
          m15DirectionalCloseLocation: .4,
        ),
      ];
      final samples = [
        const StrategyBCandidateResearchSample(
          direction: StrategyBCandidateDirection.buy,
          rawRiskReward: 3,
          targetRoomAtr: 2,
          pullbackDepthAtr: null,
          atrRelativeToMedian: .8,
          riskEligible: true,
          outcome: StrategyBCandidateOutcome.continuation,
        ),
        const StrategyBCandidateResearchSample(
          direction: StrategyBCandidateDirection.sell,
          rawRiskReward: 1,
          targetRoomAtr: .5,
          pullbackDepthAtr: null,
          atrRelativeToMedian: 1.2,
          riskEligible: false,
          outcome: StrategyBCandidateOutcome.rejection,
        ),
      ];
      final snapshot = StrategyBResearchSnapshot(
        strategyFingerprint: 'x',
        datasetFingerprint: 'y',
        observedM5Closes: 2,
        records: records,
        samplesByHorizon: {24: samples},
      );
      final section = const StrategyBEnrichedFeatureDiscovery()
          .analyze(snapshot)
          .sections
          .single;
      expect(
        section
            .byCorrectionExcursion[StrategyBCorrectionExcursionBucket
                .belowOneAtr]!
            .continuation,
        1,
      );
      expect(
        section
            .byCorrectionDuration[StrategyBCorrectionDurationBucket
                .sixToTenBars]!
            .rejection,
        1,
      );
      expect(
        section
            .byRealignmentBody[StrategyBRealignmentBodyBucket.halfToOneAtr]!
            .eligible,
        1,
      );
      expect(
        section
            .byDirectionalClose[StrategyBDirectionalCloseBucket
                .atLeastEightyFive]!
            .continuationRate,
        1,
      );
      expect(
        section
            .eligibleByCorrectionExcursion[StrategyBCorrectionExcursionBucket
                .belowOneAtr]!
            .candidates,
        1,
      );
    },
  );
  test('rejects misaligned snapshot record/sample counts', () {
    final snapshot = StrategyBResearchSnapshot(
      strategyFingerprint: 'x',
      datasetFingerprint: 'y',
      observedM5Closes: 1,
      records: const [],
      samplesByHorizon: {
        12: [
          const StrategyBCandidateResearchSample(
            direction: StrategyBCandidateDirection.buy,
            rawRiskReward: null,
            targetRoomAtr: null,
            pullbackDepthAtr: null,
            atrRelativeToMedian: null,
            riskEligible: false,
            outcome: StrategyBCandidateOutcome.unresolved,
          ),
        ],
      },
    );
    expect(
      () => const StrategyBEnrichedFeatureDiscovery().analyze(snapshot),
      throwsStateError,
    );
  });
}
