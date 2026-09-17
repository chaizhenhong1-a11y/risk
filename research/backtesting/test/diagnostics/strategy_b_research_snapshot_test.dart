import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  test('snapshot round-trips candidate facts and research outcomes', () {
    const snapshot = StrategyBResearchSnapshot(
      strategyFingerprint: 'strategy-v1',
      datasetFingerprint: 'dataset-v1',
      observedM5Closes: 100049,
      records: [
        StrategyBResearchSnapshotRecord(
          index: 1,
          direction: StrategyBCandidateDirection.buy,
          rawRiskReward: 2.5,
          targetRoomAtr: 1.4,
          atr: 5.0,
          atrRelativeToRollingMedian: 0.9,
          riskEligible: true,
          h1CorrectionExcursionAtr: 2.2,
          h1CorrectionDurationBars: 4,
          m15RealignmentBodyAtr: 0.35,
          m15DirectionalCloseLocation: 0.82,
        ),
      ],
      samplesByHorizon: {
        12: [
          StrategyBCandidateResearchSample(
            direction: StrategyBCandidateDirection.buy,
            rawRiskReward: 2.5,
            targetRoomAtr: 1.4,
            pullbackDepthAtr: null,
            atrRelativeToMedian: 0.9,
            riskEligible: true,
            outcome: StrategyBCandidateOutcome.continuation,
          ),
        ],
      },
    );

    final restored = StrategyBResearchSnapshot.fromJson(
      (jsonDecode(jsonEncode(snapshot.toJson())) as Map)
          .cast<String, Object?>(),
    );
    expect(restored.observedM5Closes, 100049);
    expect(restored.records.single.rawRiskReward, 2.5);
    expect(restored.records.single.h1CorrectionExcursionAtr, 2.2);
    expect(restored.records.single.h1CorrectionDurationBars, 4);
    expect(restored.records.single.m15RealignmentBodyAtr, 0.35);
    expect(restored.records.single.m15DirectionalCloseLocation, 0.82);
    expect(
      restored.samplesByHorizon[12]!.single.outcome,
      StrategyBCandidateOutcome.continuation,
    );
  });

  test('fingerprints reject stale snapshots', () {
    const snapshot = StrategyBResearchSnapshot(
      strategyFingerprint: 'strategy-v1',
      datasetFingerprint: 'dataset-v1',
      observedM5Closes: 1,
      records: [],
      samplesByHorizon: {},
    );
    expect(
      snapshot.isValidFor(
        expectedStrategyFingerprint: 'strategy-v2',
        expectedDatasetFingerprint: 'dataset-v1',
      ),
      isFalse,
    );
  });

  test('store ignores corrupt cache instead of trusting it', () {
    final directory = Directory.systemTemp.createTempSync('tf_snapshot_test_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}cache.json')
      ..writeAsStringSync('{broken');
    expect(const StrategyBResearchSnapshotStore().read(file), isNull);
  });
}
