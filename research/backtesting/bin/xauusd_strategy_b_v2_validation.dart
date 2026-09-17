import 'dart:io';

import 'package:risk_engine/risk_engine.dart';
import 'package:signal_engine/signal_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

const _expectedFiles = <MarketTimeframe, String>{
  MarketTimeframe.m5: 'XAUUSD_M5_2024_2026.csv',
  MarketTimeframe.m15: 'XAUUSD_M15_2024_2026.csv',
  MarketTimeframe.h1: 'XAUUSD_H1_2024_2026.csv',
  MarketTimeframe.h4: 'XAUUSD_H4_2024_2026.csv',
};
const _atrPeriod = 14;
const _maximumWaitingCandles = 12;
const _maximumObservations = 100049;
const _progressInterval = 1000;

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_strategy_b_v2_validation.dart <mt5-history-directory>',
    );
    exitCode = 64;
    return;
  }
  final directory = Directory(arguments.single);
  if (!directory.existsSync()) {
    stderr.writeln('History directory not found: ${directory.path}');
    exitCode = 66;
    return;
  }

  stdout.writeln('TradeForge V2 — Strategy B v2 frozen-hypothesis validation');
  stdout.writeln('Hypothesis: ${StrategyBV2Hypothesis.id}');
  stdout.writeln(
    'Fresh historical replay required; snapshot cache is not used.',
  );
  stdout.writeln(
    'Frozen gate: RR >= ${StrategyBV2Hypothesis.minimumPlannedRiskReward.toStringAsFixed(2)} '
    'and M15 body/ATR in [${StrategyBV2Hypothesis.minimumRealignmentBodyAtr.toStringAsFixed(2)}, '
    '${StrategyBV2Hypothesis.maximumRealignmentBodyAtr.toStringAsFixed(2)}).',
  );

  const adapter = Mt5HistoryAdapter();
  final loaded = <MarketTimeframe, Mt5HistorySeries>{};
  for (final entry in _expectedFiles.entries) {
    final file = File(
      '${directory.path}${Platform.pathSeparator}${entry.value}',
    );
    if (!file.existsSync()) {
      stderr.writeln('Missing required history file: ${file.path}');
      exitCode = 66;
      return;
    }
    loaded[entry.key] = adapter.parse(
      content: file.readAsStringSync(),
      timeframe: entry.key,
    );
    stdout.writeln(
      'Loaded ${entry.key.name}: ${loaded[entry.key]!.candles.length}',
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
      equalityTolerance: .10,
      zoneHalfWidth: .50,
      levelMergeMaxGap: .20,
      scoreProfile: SetupScoreProfiles.baselineResearchV1,
    ),
    riskParameters: CorrectionContinuationRiskResearchParameters(
      atrTimeframe: MarketTimeframe.m15,
      atrPeriod: _atrPeriod,
      atrMultiplier: AtrStopBufferMultiplier(.50),
      minimumRiskRewardPolicy: MinimumRiskRewardPolicy(2.0),
    ),
  );

  const validation = StrategyBV2Validation();
  final tracker = StrategyBCandidateForwardTracker();
  final records = <StrategyBResearchSnapshotRecord>[];
  const lifecycle = HistoricalSignalLifecycleReplay();
  const recordBuilder = HistoricalSignalRecordBuilder();
  const metricsCalculator = BacktestMetricsCalculator();
  final terminalRecords = <HistoricalSignalRecord>[];
  HistoricalSignalLifecycleState? activeState;
  RiskPlanAnalysis? activeRiskPlan;

  var observations = 0;
  var candidateCount = 0;
  var riskEligibleCount = 0;
  var hypothesisMatched = 0;
  var plansStarted = 0;
  var matchedWhileActive = 0;
  final stopwatch = Stopwatch()..start();

  for (final step in replay.run()) {
    if (observations >= _maximumObservations) break;
    observations++;
    if (observations % _progressInterval == 0) {
      stdout.writeln(
        'Progress: $observations/$_maximumObservations M5 '
        'elapsed=${_duration(stopwatch.elapsed)} candidates=$candidateCount '
        'v2=$hypothesisMatched',
      );
    }

    // Forward labels see only candles after a candidate candle.
    tracker.observeLaterCandle(step.observation.currentM5Candle);

    // Advance the independent v2 lifecycle. A terminal candle is deliberately
    // not reused to start another plan, matching the frozen baseline policy.
    var terminalThisCandle = false;
    if (activeState != null && activeRiskPlan != null) {
      final riskPlan = activeRiskPlan;
      activeState = lifecycle.observeClosedM5Candle(
        state: activeState,
        candle: step.observation.currentM5Candle,
        observationIndex: step.index,
        structuralBoundary: riskPlan.structuralStopAnalysis.stop!.price,
        stopPrice: riskPlan.protectiveStopAnalysis.stop!.price,
        targetPrice: riskPlan.targetAnalysis.target!.price,
        maximumWaitingCandles: _maximumWaitingCandles,
      );
      if (activeState.isTerminal) {
        final record = recordBuilder.build(
          state: activeState,
          terminalAtObservationIndex: step.index,
          entryPrice: riskPlan.entryZoneAnalysis.zone!.midpoint,
          stopPrice: riskPlan.protectiveStopAnalysis.stop!.price,
          targetPrice: riskPlan.targetAnalysis.target!.price,
          riskRewardRatio: riskPlan.riskRewardAnalysis.riskReward!.ratio,
        );
        if (record != null) terminalRecords.add(record);
        activeState = null;
        activeRiskPlan = null;
        terminalThisCandle = true;
      }
    }

    final result = step.result;
    if (!result.isCandidate) continue;
    candidateCount++;
    final riskPlan = result.riskPlan;
    final atr = result.atr;
    if (riskPlan == null || atr == null || !atr.isFinite || atr <= 0) continue;

    final bias = result.candidateResult!.analysis.bias;
    final direction = switch (bias) {
      TradingBias.buy => StrategyBCandidateDirection.buy,
      TradingBias.sell => StrategyBCandidateDirection.sell,
      TradingBias.noTrade => throw StateError(
        'Strategy B candidate cannot be noTrade.',
      ),
    };
    final m15 = step.observation.historyFor(MarketTimeframe.m15);
    final bodyAtr = m15.isEmpty
        ? null
        : (m15.last.close - m15.last.open).abs() / atr;
    final rr = riskPlan.riskRewardAnalysis.riskReward?.ratio;
    final entry = riskPlan.entryZoneAnalysis.zone?.midpoint;
    final target = riskPlan.targetAnalysis.target?.price;
    final targetRoomAtr = entry == null || target == null
        ? null
        : (target - entry).abs() / atr;

    if (riskPlan.isEligible) riskEligibleCount++;
    final snapshotRecord = StrategyBResearchSnapshotRecord(
      index: candidateCount,
      direction: direction,
      rawRiskReward: rr,
      targetRoomAtr: targetRoomAtr,
      atr: atr,
      atrRelativeToRollingMedian: null,
      riskEligible: riskPlan.isEligible,
      h1CorrectionExcursionAtr: null,
      h1CorrectionDurationBars: null,
      m15RealignmentBodyAtr: bodyAtr,
      m15DirectionalCloseLocation: null,
    );
    records.add(snapshotRecord);
    tracker.registerCandidate(
      direction: direction,
      referencePrice: step.observation.currentM5Candle.close,
      atr: atr,
      rawRiskReward: rr,
      targetRoomAtr: targetRoomAtr,
      pullbackDepthAtr: null,
      atrRelativeToMedian: null,
      riskEligible: riskPlan.isEligible,
    );

    if (!validation.matchesRecord(snapshotRecord)) continue;
    hypothesisMatched++;
    if (activeState != null) {
      matchedWhileActive++;
      continue;
    }
    if (terminalThisCandle) continue;

    final state = lifecycle.start(
      candidate: _buildLifecycleCandidate(bias: bias, riskPlan: riskPlan),
      observationIndex: step.index,
    );
    if (state != null) {
      plansStarted++;
      activeState = state;
      activeRiskPlan = riskPlan;
    }
  }
  tracker.finish();
  stopwatch.stop();

  if (observations != _maximumObservations) {
    throw StateError(
      'Fresh validation ended early: $observations/$_maximumObservations observations.',
    );
  }
  validation.assertBaselineIntegrity(
    candidateCount: candidateCount,
    riskEligibleCount: riskEligibleCount,
  );

  stdout.writeln('');
  stdout.writeln('Increment 098 validation results');
  stdout.writeln('Observed M5 closes: $observations');
  stdout.writeln('Baseline candidates: $candidateCount (expected 203)');
  stdout.writeln('Baseline RR-eligible: $riskEligibleCount (expected 12)');
  stdout.writeln('Baseline integrity: PASS');
  stdout.writeln('Frozen-hypothesis candidates: $hypothesisMatched');
  stdout.writeln('V2 plans started: $plansStarted');
  stdout.writeln('V2 candidates skipped while active: $matchedWhileActive');

  for (final horizon in StrategyBV2ValidationPlan.forwardHorizonsM5) {
    final summary = validation.summarize(
      horizonM5: horizon,
      records: records
          .take(tracker.diagnosticsByHorizon[horizon]!.samples.length)
          .toList(),
      samples: tracker.diagnosticsByHorizon[horizon]!.samples,
    );
    stdout.writeln(
      'Forward $horizon M5: n=${summary.candidates} '
      'continuation=${summary.continuation} rejection=${summary.rejection} '
      'unresolved=${summary.unresolved} '
      'resolvedContinuationRate=${_percent(summary.resolvedContinuationRate)}',
    );
  }

  final metrics = metricsCalculator.calculate(terminalRecords);
  stdout.writeln('');
  stdout.writeln('V2 terminal lifecycle:');
  stdout.writeln('  terminal plans: ${metrics.totalTerminalSignals}');
  stdout.writeln('  invalidated: ${metrics.invalidatedSignals}');
  stdout.writeln('  expired: ${metrics.expiredSignals}');
  stdout.writeln('  triggered resolved trades: ${metrics.triggeredTrades}');
  stdout.writeln('  wins: ${metrics.wins}');
  stdout.writeln('  losses: ${metrics.losses}');
  stdout.writeln('  win rate: ${_percent(metrics.winRate)}');
  stdout.writeln('  expectancy R: ${_number(metrics.expectancyR)}');
  stdout.writeln('  profit factor: ${_number(metrics.profitFactor)}');
  stdout.writeln('');
  stdout.writeln('Threshold retuning during this validation: DISALLOWED');
  stdout.writeln('Production Strategy B changed: NO');
  stdout.writeln('Research only; no spread/slippage/commission.');
}

SignalCandidate _buildLifecycleCandidate({
  required TradingBias bias,
  required RiskPlanAnalysis riskPlan,
}) {
  final snapshot = SetupEvidenceSnapshot(
    eligibility: SetupEligibility.eligible,
    blockReason: null,
    evidence: [
      SetupEvidence(type: SetupEvidenceType.directionalBias, present: true),
      SetupEvidence(
        type: SetupEvidenceType.directionalM15Structure,
        present: true,
      ),
    ],
    d1ContextAlignment: D1ContextAlignment.unavailable,
    keyLevelQuality: KeyLevelQuality.unavailable,
  );
  final score = SetupScoreResult(
    earnedPoints: 0,
    availablePoints: 0,
    contributions: {},
  );
  final direction = switch (bias) {
    TradingBias.buy => SignalCandidateDirection.buy,
    TradingBias.sell => SignalCandidateDirection.sell,
    TradingBias.noTrade => SignalCandidateDirection.noTrade,
  };
  return SignalCandidate.qualified(
    direction: direction,
    setupSnapshot: snapshot,
    setupScore: score,
    riskPlan: riskPlan,
  );
}

String _percent(double? value) =>
    value == null ? 'n/a' : '${(value * 100).toStringAsFixed(2)}%';
String _number(double? value) => value?.toStringAsFixed(4) ?? 'n/a';
String _duration(Duration value) => value.inMinutes > 0
    ? '${value.inMinutes}m ${value.inSeconds % 60}s'
    : '${(value.inMilliseconds / 1000).toStringAsFixed(3)}s';
