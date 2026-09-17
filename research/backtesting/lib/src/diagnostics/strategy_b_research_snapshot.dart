import 'dart:convert';
import 'dart:io';

import 'strategy_b_candidate_research_diagnostics.dart';

const strategyBResearchSnapshotSchemaVersion = 2;

final class StrategyBResearchSnapshotRecord {
  const StrategyBResearchSnapshotRecord({
    required this.index,
    required this.direction,
    required this.rawRiskReward,
    required this.targetRoomAtr,
    required this.atr,
    required this.atrRelativeToRollingMedian,
    required this.riskEligible,
    this.h1CorrectionExcursionAtr,
    this.h1CorrectionDurationBars,
    this.m15RealignmentBodyAtr,
    this.m15DirectionalCloseLocation,
  });

  final int index;
  final StrategyBCandidateDirection direction;
  final double? rawRiskReward;
  final double? targetRoomAtr;
  final double atr;
  final double? atrRelativeToRollingMedian;
  final bool riskEligible;

  /// Research-only H1 directional excursion over the visible correction window,
  /// normalized by candidate-time M15 ATR. This is deliberately not labelled
  /// as the production pullback depth because Strategy B v1 does not expose
  /// its structural correction leg yet.
  final double? h1CorrectionExcursionAtr;

  /// Number of visible H1 bars from the directional extreme to the candidate.
  final int? h1CorrectionDurationBars;

  /// Candidate-time M15 candle body size normalized by M15 ATR.
  final double? m15RealignmentBodyAtr;

  /// Direction-aware M15 close location in [0, 1]. Higher means the candle
  /// closed nearer the continuation side of its visible range.
  final double? m15DirectionalCloseLocation;

  Map<String, Object?> toJson() => {
    'index': index,
    'direction': direction.name,
    'rawRiskReward': rawRiskReward,
    'targetRoomAtr': targetRoomAtr,
    'atr': atr,
    'atrRelativeToRollingMedian': atrRelativeToRollingMedian,
    'riskEligible': riskEligible,
    'h1CorrectionExcursionAtr': h1CorrectionExcursionAtr,
    'h1CorrectionDurationBars': h1CorrectionDurationBars,
    'm15RealignmentBodyAtr': m15RealignmentBodyAtr,
    'm15DirectionalCloseLocation': m15DirectionalCloseLocation,
  };

  factory StrategyBResearchSnapshotRecord.fromJson(Map<String, Object?> json) =>
      StrategyBResearchSnapshotRecord(
        index: json['index'] as int,
        direction: StrategyBCandidateDirection.values.byName(
          json['direction'] as String,
        ),
        rawRiskReward: (json['rawRiskReward'] as num?)?.toDouble(),
        targetRoomAtr: (json['targetRoomAtr'] as num?)?.toDouble(),
        atr: (json['atr'] as num).toDouble(),
        atrRelativeToRollingMedian: (json['atrRelativeToRollingMedian'] as num?)
            ?.toDouble(),
        riskEligible: json['riskEligible'] as bool,
        h1CorrectionExcursionAtr: (json['h1CorrectionExcursionAtr'] as num?)
            ?.toDouble(),
        h1CorrectionDurationBars: json['h1CorrectionDurationBars'] as int?,
        m15RealignmentBodyAtr: (json['m15RealignmentBodyAtr'] as num?)
            ?.toDouble(),
        m15DirectionalCloseLocation:
            (json['m15DirectionalCloseLocation'] as num?)?.toDouble(),
      );
}

final class StrategyBResearchSnapshot {
  const StrategyBResearchSnapshot({
    required this.strategyFingerprint,
    required this.datasetFingerprint,
    required this.observedM5Closes,
    required this.records,
    required this.samplesByHorizon,
  });

  final String strategyFingerprint;
  final String datasetFingerprint;
  final int observedM5Closes;
  final List<StrategyBResearchSnapshotRecord> records;
  final Map<int, List<StrategyBCandidateResearchSample>> samplesByHorizon;

  bool isValidFor({
    required String expectedStrategyFingerprint,
    required String expectedDatasetFingerprint,
  }) =>
      strategyFingerprint == expectedStrategyFingerprint &&
      datasetFingerprint == expectedDatasetFingerprint;

  Map<String, Object?> toJson() => {
    'schemaVersion': strategyBResearchSnapshotSchemaVersion,
    'strategyFingerprint': strategyFingerprint,
    'datasetFingerprint': datasetFingerprint,
    'observedM5Closes': observedM5Closes,
    'records': records.map((record) => record.toJson()).toList(),
    'samplesByHorizon': {
      for (final entry in samplesByHorizon.entries)
        '${entry.key}': entry.value.map(_sampleToJson).toList(),
    },
  };

  factory StrategyBResearchSnapshot.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != strategyBResearchSnapshotSchemaVersion) {
      throw const FormatException('Unsupported Strategy B snapshot schema.');
    }
    final rawHorizons = json['samplesByHorizon'] as Map<String, Object?>;
    return StrategyBResearchSnapshot(
      strategyFingerprint: json['strategyFingerprint'] as String,
      datasetFingerprint: json['datasetFingerprint'] as String,
      observedM5Closes: json['observedM5Closes'] as int,
      records: (json['records'] as List<Object?>)
          .map(
            (value) => StrategyBResearchSnapshotRecord.fromJson(
              value as Map<String, Object?>,
            ),
          )
          .toList(growable: false),
      samplesByHorizon: {
        for (final entry in rawHorizons.entries)
          int.parse(entry.key): (entry.value as List<Object?>)
              .map((value) => _sampleFromJson(value as Map<String, Object?>))
              .toList(growable: false),
      },
    );
  }
}

final class StrategyBResearchSnapshotStore {
  const StrategyBResearchSnapshotStore();

  StrategyBResearchSnapshot? read(File file) {
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      return StrategyBResearchSnapshot.fromJson(
        (decoded as Map).cast<String, Object?>(),
      );
    } on Object {
      return null;
    }
  }

  void write(File file, StrategyBResearchSnapshot snapshot) {
    file.parent.createSync(recursive: true);
    final temporary = File('${file.path}.tmp');
    temporary.writeAsStringSync(jsonEncode(snapshot.toJson()));
    if (file.existsSync()) file.deleteSync();
    temporary.renameSync(file.path);
  }
}

Map<String, Object?> _sampleToJson(StrategyBCandidateResearchSample sample) => {
  'direction': sample.direction.name,
  'rawRiskReward': sample.rawRiskReward,
  'targetRoomAtr': sample.targetRoomAtr,
  'pullbackDepthAtr': sample.pullbackDepthAtr,
  'atrRelativeToMedian': sample.atrRelativeToMedian,
  'riskEligible': sample.riskEligible,
  'outcome': sample.outcome.name,
};

StrategyBCandidateResearchSample _sampleFromJson(Map<String, Object?> json) =>
    StrategyBCandidateResearchSample(
      direction: StrategyBCandidateDirection.values.byName(
        json['direction'] as String,
      ),
      rawRiskReward: (json['rawRiskReward'] as num?)?.toDouble(),
      targetRoomAtr: (json['targetRoomAtr'] as num?)?.toDouble(),
      pullbackDepthAtr: (json['pullbackDepthAtr'] as num?)?.toDouble(),
      atrRelativeToMedian: (json['atrRelativeToMedian'] as num?)?.toDouble(),
      riskEligible: json['riskEligible'] as bool,
      outcome: StrategyBCandidateOutcome.values.byName(
        json['outcome'] as String,
      ),
    );
