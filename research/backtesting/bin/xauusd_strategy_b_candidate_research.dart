import 'dart:io';

import 'package:market_models/market_models.dart';
import 'package:risk_engine/risk_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

const _expectedFiles = <MarketTimeframe, String>{
  MarketTimeframe.m5: 'XAUUSD_M5_2024_2026.csv',
  MarketTimeframe.m15: 'XAUUSD_M15_2024_2026.csv',
  MarketTimeframe.h1: 'XAUUSD_H1_2024_2026.csv',
  MarketTimeframe.h4: 'XAUUSD_H4_2024_2026.csv',
};

const _atrPeriod = 14;
const _minimumRiskReward = 2.0;
const _defaultMaximumObservations = 100049;
const _progressInterval = 1000;
const _rollingAtrBaselineSize = 96;
const _snapshotStrategyFingerprint =
    'strategy-b-v1|eq=.10|zone=.50|merge=.20|atr=14|atrMult=.50|minRR=2.0|rollingAtr=96|horizons=12,24,48|enrichment=095-v1';

void main(List<String> arguments) {
  if (arguments.isEmpty || arguments.length > 2) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_strategy_b_candidate_research.dart <mt5-history-directory> [max-observations]',
    );
    exitCode = 64;
    return;
  }
  final directory = Directory(arguments.first);
  final maximumObservations = arguments.length == 2
      ? int.tryParse(arguments[1])
      : _defaultMaximumObservations;
  if (!directory.existsSync() ||
      maximumObservations == null ||
      maximumObservations <= 0) {
    stderr.writeln('Invalid history directory or max-observations.');
    exitCode = 66;
    return;
  }

  stdout.writeln('TradeForge V2 — Strategy B candidate-quality research');
  final historyFiles = <MarketTimeframe, File>{
    for (final entry in _expectedFiles.entries)
      entry.key: File(
        '${directory.path}${Platform.pathSeparator}${entry.value}',
      ),
  };
  for (final file in historyFiles.values) {
    if (!file.existsSync()) {
      stderr.writeln('Missing required history file: ${file.path}');
      exitCode = 66;
      return;
    }
  }
  final datasetFingerprint = _datasetFingerprint(historyFiles);
  final useSnapshot = arguments.length == 1;
  final snapshotFile = File(
    '${Directory.current.path}${Platform.pathSeparator}.research_cache${Platform.pathSeparator}strategy_b_candidates_v1.json',
  );
  if (useSnapshot) {
    final snapshot = const StrategyBResearchSnapshotStore().read(snapshotFile);
    if (snapshot != null &&
        snapshot.isValidFor(
          expectedStrategyFingerprint: _snapshotStrategyFingerprint,
          expectedDatasetFingerprint: datasetFingerprint,
        )) {
      stdout.writeln('Research snapshot hit: ${snapshotFile.path}');
      _printSnapshot(snapshot);
      return;
    }
    stdout.writeln('Research snapshot miss/stale. Full replay required once.');
  }
  stdout.writeln('Loading MT5 history from: ${directory.path}');

  const adapter = Mt5HistoryAdapter();
  final loaded = <MarketTimeframe, Mt5HistorySeries>{};
  for (final entry in _expectedFiles.entries) {
    final file = historyFiles[entry.key]!;
    stdout.writeln('  loading ${entry.value} ...');
    loaded[entry.key] = adapter.parse(
      content: file.readAsStringSync(),
      timeframe: entry.key,
    );
    stdout.writeln(
      '  loaded ${entry.key.name}: ${loaded[entry.key]!.candles.length} candles',
    );
  }

  final feed = MultiTimeframeBacktestFeed(
    m5Candles: loaded[MarketTimeframe.m5]!.candles,
    m15Candles: loaded[MarketTimeframe.m15]!.candles,
    h1Candles: loaded[MarketTimeframe.h1]!.candles,
    h4Candles: loaded[MarketTimeframe.h4]!.candles,
  );
  final replay = const CorrectionContinuationRiskHistoricalReplay().create(
    feed: feed,
    candidateReplay: const CorrectionContinuationHistoricalReplay(),
    sourceReplay: const StrategySetupHistoricalReplay(),
    sourceParameters: StrategyReplayResearchParameters(
      equalityTolerance: 0.10,
      zoneHalfWidth: 0.50,
      levelMergeMaxGap: 0.20,
      scoreProfile: SetupScoreProfiles.baselineResearchV1,
    ),
    riskParameters: CorrectionContinuationRiskResearchParameters(
      atrTimeframe: MarketTimeframe.m15,
      atrPeriod: _atrPeriod,
      atrMultiplier: AtrStopBufferMultiplier(0.50),
      minimumRiskRewardPolicy: MinimumRiskRewardPolicy(_minimumRiskReward),
    ),
  );

  stdout.writeln('History loaded. Starting replay...');
  final stopwatch = Stopwatch()..start();

  final tracker = StrategyBCandidateForwardTracker();
  final rollingMarketAtr = <double>[];
  final candidateRecords = <StrategyBResearchSnapshotRecord>[];
  var lastM15HistoryLength = -1;
  var observations = 0;
  var candidateEvents = 0;
  var riskEligible = 0;

  for (final step in replay.run()) {
    if (observations >= maximumObservations) break;
    observations++;
    if (observations % _progressInterval == 0) {
      final elapsedSeconds = stopwatch.elapsedMicroseconds / 1000000.0;
      final rate = elapsedSeconds <= 0 ? 0.0 : observations / elapsedSeconds;
      stdout.writeln(
        'Progress: $observations/$maximumObservations M5 '
        'elapsed=${_duration(stopwatch.elapsed)} '
        'rate=${rate.toStringAsFixed(1)} obs/s '
        'candidates=$candidateEvents',
      );
    }

    // Build a true rolling market ATR baseline from every newly visible M15
    // candle, not only from Strategy B candidate events. Only closed history
    // visible at this replay step is used.
    final m15History = step.observation.historyFor(MarketTimeframe.m15);
    if (m15History.length != lastM15HistoryLength) {
      lastM15HistoryLength = m15History.length;
      if (m15History.length >= _atrPeriod + 1) {
        final marketAtr = const AverageTrueRange().calculate(
          candles: m15History.sublist(m15History.length - _atrPeriod - 1),
          period: _atrPeriod,
        );
        if (marketAtr.isFinite && marketAtr > 0) {
          rollingMarketAtr.add(marketAtr);
          if (rollingMarketAtr.length > _rollingAtrBaselineSize) {
            rollingMarketAtr.removeAt(0);
          }
        }
      }
    }

    // Advance existing labels before registering any candidate on this candle.
    // Therefore the candidate/trigger candle is excluded from forward outcomes.
    tracker.observeLaterCandle(step.observation.currentM5Candle);

    final result = step.result;
    if (!result.isCandidate) continue;
    candidateEvents++;

    final atr = result.atr;
    final riskPlan = result.riskPlan;
    if (atr == null || !atr.isFinite || atr <= 0 || riskPlan == null) continue;

    final rr = riskPlan.riskRewardAnalysis.riskReward?.ratio;
    final entry = riskPlan.entryZoneAnalysis.zone?.midpoint;
    final target = riskPlan.targetAnalysis.target?.price;
    final targetRoomAtr = entry == null || target == null
        ? null
        : (target - entry).abs() / atr;
    // Exclude the current M15 ATR from its own baseline comparison. The last
    // value is the current visible M15 ATR, so compare against earlier values.
    final baselineValues = rollingMarketAtr.length <= 1
        ? const <double>[]
        : rollingMarketAtr.sublist(0, rollingMarketAtr.length - 1);
    final median = _median(baselineValues);
    final atrRelativeToMedian = median == null || median <= 0
        ? null
        : atr / median;

    final bias = result.candidateResult!.analysis.bias;
    final direction = switch (bias) {
      TradingBias.buy => StrategyBCandidateDirection.buy,
      TradingBias.sell => StrategyBCandidateDirection.sell,
      TradingBias.noTrade => throw StateError(
        'Strategy B candidate cannot be noTrade.',
      ),
    };
    final h1History = step.observation.historyFor(MarketTimeframe.h1);
    final m15HistoryForCandidate = step.observation.historyFor(
      MarketTimeframe.m15,
    );
    final enrichment = _candidateEnrichment(
      direction: direction,
      atr: atr,
      h1History: h1History,
      m15History: m15HistoryForCandidate,
    );

    if (riskPlan.isEligible) riskEligible++;
    candidateRecords.add(
      StrategyBResearchSnapshotRecord(
        index: candidateEvents,
        direction: direction,
        rawRiskReward: rr,
        targetRoomAtr: targetRoomAtr,
        atr: atr,
        atrRelativeToRollingMedian: atrRelativeToMedian,
        riskEligible: riskPlan.isEligible,
        h1CorrectionExcursionAtr: enrichment.h1CorrectionExcursionAtr,
        h1CorrectionDurationBars: enrichment.h1CorrectionDurationBars,
        m15RealignmentBodyAtr: enrichment.m15RealignmentBodyAtr,
        m15DirectionalCloseLocation: enrichment.m15DirectionalCloseLocation,
      ),
    );

    tracker.registerCandidate(
      direction: direction,
      referencePrice: step.observation.currentM5Candle.close,
      atr: atr,
      rawRiskReward: rr,
      targetRoomAtr: targetRoomAtr,
      // True correction-leg depth is not exposed by the frozen replay yet.
      // Keep it unavailable rather than relabeling another distance as pullback.
      pullbackDepthAtr: null,
      atrRelativeToMedian: atrRelativeToMedian,
      riskEligible: riskPlan.isEligible,
    );
  }
  tracker.finish();
  stopwatch.stop();

  if (useSnapshot && observations == _defaultMaximumObservations) {
    const StrategyBResearchSnapshotStore().write(
      snapshotFile,
      StrategyBResearchSnapshot(
        strategyFingerprint: _snapshotStrategyFingerprint,
        datasetFingerprint: datasetFingerprint,
        observedM5Closes: observations,
        records: candidateRecords,
        samplesByHorizon: {
          for (final entry in tracker.diagnosticsByHorizon.entries)
            entry.key: entry.value.samples,
        },
      ),
    );
    stdout.writeln('Research snapshot written: ${snapshotFile.path}');
  }

  stdout.writeln('');
  stdout.writeln(
    'TradeForge V2 — Strategy B candidate-quality research results',
  );
  stdout.writeln('Observed M5 closes: $observations');
  stdout.writeln('Strategy B candidate events: $candidateEvents');
  stdout.writeln(
    'Forward-label candidates registered: ${tracker.registeredCandidates}',
  );
  stdout.writeln('Risk eligible candidates: $riskEligible');
  stdout.writeln(
    'Pullback depth: unavailable until true correction-leg depth is exposed; no proxy is invented.',
  );
  _printIntegrityDiagnostics(candidateRecords);
  for (final horizon in tracker.horizonsM5) {
    final diagnostics = tracker.diagnosticsByHorizon[horizon]!;
    stdout.writeln('');
    stdout.writeln('Forward horizon: $horizon M5 candles');
    stdout.writeln('Resolved-window samples: ${diagnostics.candidateCount}');
    _printTargetRoom(diagnostics);
    _printVolatility(diagnostics);
  }
  stdout.writeln('');
  stdout.writeln(
    'Research only. Forward labels are never fed into Strategy B candidate generation.',
  );
}

final class _CandidateEnrichment {
  const _CandidateEnrichment({
    required this.h1CorrectionExcursionAtr,
    required this.h1CorrectionDurationBars,
    required this.m15RealignmentBodyAtr,
    required this.m15DirectionalCloseLocation,
  });

  final double? h1CorrectionExcursionAtr;
  final int? h1CorrectionDurationBars;
  final double? m15RealignmentBodyAtr;
  final double? m15DirectionalCloseLocation;
}

_CandidateEnrichment _candidateEnrichment({
  required StrategyBCandidateDirection direction,
  required double atr,
  required List<Candle> h1History,
  required List<Candle> m15History,
}) {
  const correctionWindow = 12;
  double? excursionAtr;
  int? durationBars;

  if (h1History.isNotEmpty && atr > 0) {
    final start = h1History.length > correctionWindow
        ? h1History.length - correctionWindow
        : 0;
    final visible = h1History.sublist(start);
    if (direction == StrategyBCandidateDirection.buy) {
      var extremeIndex = 0;
      var extreme = visible.first.high;
      for (var i = 1; i < visible.length; i++) {
        if (visible[i].high > extreme) {
          extreme = visible[i].high;
          extremeIndex = i;
        }
      }
      final currentLow = visible.last.low;
      excursionAtr = (extreme - currentLow).abs() / atr;
      durationBars = visible.length - 1 - extremeIndex;
    } else {
      var extremeIndex = 0;
      var extreme = visible.first.low;
      for (var i = 1; i < visible.length; i++) {
        if (visible[i].low < extreme) {
          extreme = visible[i].low;
          extremeIndex = i;
        }
      }
      final currentHigh = visible.last.high;
      excursionAtr = (currentHigh - extreme).abs() / atr;
      durationBars = visible.length - 1 - extremeIndex;
    }
  }

  double? bodyAtr;
  double? closeLocation;
  if (m15History.isNotEmpty && atr > 0) {
    final candle = m15History.last;
    bodyAtr = (candle.close - candle.open).abs() / atr;
    final range = candle.high - candle.low;
    if (range > 0) {
      final rawCloseLocation = direction == StrategyBCandidateDirection.buy
          ? (candle.close - candle.low) / range
          : (candle.high - candle.close) / range;
      closeLocation = rawCloseLocation.clamp(0.0, 1.0).toDouble();
    }
  }

  return _CandidateEnrichment(
    h1CorrectionExcursionAtr: excursionAtr,
    h1CorrectionDurationBars: durationBars,
    m15RealignmentBodyAtr: bodyAtr,
    m15DirectionalCloseLocation: closeLocation,
  );
}

void _printTargetRoom(StrategyBCandidateResearchDiagnostics diagnostics) {
  stdout.writeln('  Target-room / planned-RR buckets:');
  for (final entry in diagnostics.summarizeTargetRoom().entries) {
    final s = entry.value;
    stdout.writeln(
      '    ${entry.key.name}: n=${s.candidates} eligible=${s.riskEligible} continuation=${s.continuation} rejection=${s.rejection} unresolved=${s.unresolved} continuationRate=${_percent(s.resolvedContinuationRate)} avgTargetRoomAtr=${_number(s.averageTargetRoomAtr)}',
    );
  }
}

void _printVolatility(StrategyBCandidateResearchDiagnostics diagnostics) {
  stdout.writeln('  Candidate ATR / rolling-market-median buckets:');
  for (final entry in diagnostics.summarizeVolatility().entries) {
    final s = entry.value;
    stdout.writeln(
      '    ${entry.key.name}: n=${s.candidates} eligible=${s.riskEligible} continuation=${s.continuation} rejection=${s.rejection} unresolved=${s.unresolved} continuationRate=${_percent(s.resolvedContinuationRate)}',
    );
  }
}

void _printIntegrityDiagnostics(List<StrategyBResearchSnapshotRecord> records) {
  stdout.writeln('');
  stdout.writeln('Research integrity diagnostics');
  final rr = records
      .map((r) => r.rawRiskReward)
      .whereType<double>()
      .where((v) => v.isFinite)
      .toList();
  final targetRoom = records
      .map((r) => r.targetRoomAtr)
      .whereType<double>()
      .where((v) => v.isFinite)
      .toList();
  _printDistribution('Raw planned RR', rr);
  _printDistribution('Target room / ATR', targetRoom);

  for (final direction in StrategyBCandidateDirection.values) {
    final group = records.where((r) => r.direction == direction).toList();
    final eligible = group.where((r) => r.riskEligible).length;
    stdout.writeln(
      '  ${direction.name.toUpperCase()}: n=${group.length} eligible=$eligible',
    );
  }

  final eligibleRecords = records.where((r) => r.riskEligible).toList();
  stdout.writeln(
    '  RR-eligible candidate details (${eligibleRecords.length}):',
  );
  for (final r in eligibleRecords) {
    stdout.writeln(
      '    #${r.index} ${r.direction.name.toUpperCase()} '
      'rr=${_number(r.rawRiskReward)} '
      'targetRoomAtr=${_number(r.targetRoomAtr)} '
      'atr=${_number(r.atr)} '
      'atrVsRollingMedian=${_number(r.atrRelativeToRollingMedian)}',
    );
  }

  final outliers =
      records
          .where((r) => r.targetRoomAtr != null && r.targetRoomAtr!.isFinite)
          .toList()
        ..sort((a, b) => b.targetRoomAtr!.compareTo(a.targetRoomAtr!));
  stdout.writeln('  Largest target-room/ATR observations:');
  for (final r in outliers.take(10)) {
    stdout.writeln(
      '    #${r.index} ${r.direction.name.toUpperCase()} '
      'rr=${_number(r.rawRiskReward)} '
      'targetRoomAtr=${_number(r.targetRoomAtr)} '
      'eligible=${r.riskEligible}',
    );
  }
}

void _printDistribution(String label, List<double> values) {
  if (values.isEmpty) {
    stdout.writeln('  $label: n=0');
    return;
  }
  final sorted = List<double>.of(values)..sort();
  final mean = sorted.reduce((a, b) => a + b) / sorted.length;
  stdout.writeln(
    '  $label: n=${sorted.length} '
    'min=${_number(sorted.first)} '
    'median=${_number(_quantile(sorted, 0.50))} '
    'p75=${_number(_quantile(sorted, 0.75))} '
    'p90=${_number(_quantile(sorted, 0.90))} '
    'p95=${_number(_quantile(sorted, 0.95))} '
    'max=${_number(sorted.last)} '
    'mean=${_number(mean)}',
  );
}

double _quantile(List<double> sorted, double q) {
  if (sorted.length == 1) return sorted.single;
  final position = (sorted.length - 1) * q;
  final lower = position.floor();
  final upper = position.ceil();
  if (lower == upper) return sorted[lower];
  final fraction = position - lower;
  return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction;
}

String _datasetFingerprint(Map<MarketTimeframe, File> files) {
  final parts = <String>[];
  for (final timeframe in MarketTimeframe.values) {
    final file = files[timeframe];
    if (file == null) continue;
    final stat = file.statSync();
    parts.add(
      '${timeframe.name}:${stat.size}:${stat.modified.toUtc().microsecondsSinceEpoch}',
    );
  }
  return parts.join('|');
}

void _printSnapshot(StrategyBResearchSnapshot snapshot) {
  stdout.writeln('');
  stdout.writeln(
    'TradeForge V2 — Strategy B candidate-quality research results',
  );
  stdout.writeln('Observed M5 closes: ${snapshot.observedM5Closes}');
  stdout.writeln('Strategy B candidate events: ${snapshot.records.length}');
  stdout.writeln(
    'Forward-label candidates registered: ${snapshot.records.length}',
  );
  stdout.writeln(
    'Risk eligible candidates: ${snapshot.records.where((r) => r.riskEligible).length}',
  );
  stdout.writeln(
    'Pullback depth: unavailable until true correction-leg depth is exposed; no proxy is invented.',
  );
  _printIntegrityDiagnostics(snapshot.records);
  final horizons = snapshot.samplesByHorizon.keys.toList()..sort();
  for (final horizon in horizons) {
    final diagnostics = StrategyBCandidateResearchDiagnostics();
    for (final sample in snapshot.samplesByHorizon[horizon]!) {
      diagnostics.add(sample);
    }
    stdout.writeln('');
    stdout.writeln('Forward horizon: $horizon M5 candles');
    stdout.writeln('Resolved-window samples: ${diagnostics.candidateCount}');
    _printTargetRoom(diagnostics);
    _printVolatility(diagnostics);
  }
  stdout.writeln('');
  stdout.writeln(
    'Research snapshot only. Full replay remains the source of truth after strategy/risk changes.',
  );
}

double? _median(List<double> values) {
  if (values.isEmpty) return null;
  final sorted = List<double>.of(values)..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

String _percent(double? value) =>
    value == null ? 'n/a' : '${(value * 100).toStringAsFixed(2)}%';
String _number(double? value) => value?.toStringAsFixed(4) ?? 'n/a';

String _duration(Duration value) {
  final minutes = value.inMinutes;
  final seconds = value.inSeconds.remainder(60);
  if (minutes == 0) return '${value.inSeconds}s';
  return '${minutes}m ${seconds}s';
}
