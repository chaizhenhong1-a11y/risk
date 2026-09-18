import 'dart:io';

import 'package:risk_engine/risk_engine.dart';
import 'package:signal_engine/signal_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/validation/historical_strategy_audit.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_audit_snapshot.dart';
import 'package:tradeforge_backtesting/src/validation/unified_strategy_expectancy_audit.dart';

const _expectedFiles = <MarketTimeframe, String>{
  MarketTimeframe.m5: 'XAUUSD_M5_2024_2026.csv',
  MarketTimeframe.m15: 'XAUUSD_M15_2024_2026.csv',
  MarketTimeframe.h1: 'XAUUSD_H1_2024_2026.csv',
  MarketTimeframe.h4: 'XAUUSD_H4_2024_2026.csv',
};

const _equalityTolerance = 0.10;
const _zoneHalfWidth = 0.50;
const _levelMergeMaxGap = 0.20;
const _atrPeriod = 14;
const _atrMultiplierValue = 0.50;
const _minimumRiskReward = 2.0;
const _maximumWaitingCandles = 12;

void main(List<String> arguments) {
  if (arguments.isEmpty || arguments.length > 2) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_ab_unified_expectancy_audit.dart '
      '<mt5-history-directory> [audit-snapshot-directory]',
    );
    exitCode = 64;
    return;
  }

  final directory = Directory(arguments.first);
  if (!directory.existsSync()) {
    stderr.writeln('History directory not found: ${directory.path}');
    exitCode = 66;
    return;
  }

  stdout.writeln('[1/5] Loading MT5 history...');
  const adapter = Mt5HistoryAdapter();
  final loaded = <MarketTimeframe, Mt5HistorySeries>{};
  for (final entry in _expectedFiles.entries) {
    stdout.writeln('  loading ${entry.key.name}: ${entry.value}');
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
      '  loaded ${entry.key.name}: ${loaded[entry.key]!.candles.length} candles',
    );
  }

  stdout.writeln(
    '[2/5] History loaded. M5=${loaded[MarketTimeframe.m5]!.candles.length}',
  );
  final feed = MultiTimeframeBacktestFeed(
    m5Candles: loaded[MarketTimeframe.m5]!.candles,
    m15Candles: loaded[MarketTimeframe.m15]!.candles,
    h1Candles: loaded[MarketTimeframe.h1]!.candles,
    h4Candles: loaded[MarketTimeframe.h4]!.candles,
  );
  final m5 = loaded[MarketTimeframe.m5]!.candles;

  stdout.writeln('[3/5] Running Strategy A frozen replay...');
  final aWatch = Stopwatch()..start();
  final a = _runA(feed);
  aWatch.stop();
  stdout.writeln(
    '  Strategy A complete: ${a.length} terminal plans '
    '(${aWatch.elapsed})',
  );

  stdout.writeln('[4/5] Running Strategy B frozen replay...');
  final bWatch = Stopwatch()..start();
  final b = _runB(feed);
  bWatch.stop();
  stdout.writeln(
    '  Strategy B complete: ${b.length} terminal plans '
    '(${bWatch.elapsed})',
  );

  stdout.writeln('[5/5] Running unified expectancy audit...');
  const audit = HistoricalStrategyAudit();
  final aAudit = audit.evaluate(
    strategy: AuditedStrategy.strategyA,
    records: a,
    timeForObservationIndex: (index) => m5[index].closeTime,
  );
  final bAudit = audit.evaluate(
    strategy: AuditedStrategy.strategyB,
    records: b,
    timeForObservationIndex: (index) => m5[index].closeTime,
  );

  if (arguments.length == 2) {
    final output = Directory(arguments[1])..createSync(recursive: true);
    _writeSnapshot(output, 'strategy_a.json', aAudit.verdict);
    _writeSnapshot(output, 'strategy_b.json', bAudit.verdict);
    stdout.writeln('Audit snapshots written to: ${output.path}');
  }

  stdout.writeln('');
  stdout.writeln('TradeForge V2 — Increment 141 A/B Unified Expectancy Audit');
  stdout.writeln(
    'Frozen geometry only. No strategy thresholds or risk parameters tuned.',
  );
  _print('A', aAudit);
  _print('B', bAudit);
  stdout.writeln('');
  stdout.writeln(
    'C5 remains audited by xauusd_c5_unified_expectancy_audit.dart because '
    'its frozen structural risk geometry is intentionally separate.',
  );
  stdout.writeln(
    'Research only. Same historical dataset; this does not replace unseen '
    'forward validation.',
  );
}

void _writeSnapshot(
  Directory directory,
  String filename,
  StrategyAuditVerdict verdict,
) {
  final snapshot = StrategyAuditSnapshot(
    verdict: verdict,
    generatedAt: DateTime.now().toUtc(),
  );
  File(
    '${directory.path}${Platform.pathSeparator}$filename',
  ).writeAsStringSync('${snapshot.toJsonLine()}\n');
}

List<HistoricalSignalRecord> _runA(MultiTimeframeBacktestFeed feed) {
  final strategyParameters = StrategyReplayResearchParameters(
    equalityTolerance: _equalityTolerance,
    zoneHalfWidth: _zoneHalfWidth,
    levelMergeMaxGap: _levelMergeMaxGap,
    scoreProfile: SetupScoreProfiles.baselineResearchV1,
  );
  final riskParameters = RiskReplayResearchParameters(
    atrTimeframe: MarketTimeframe.m15,
    atrPeriod: _atrPeriod,
    atrMultiplier: AtrStopBufferMultiplier(_atrMultiplierValue),
    minimumRiskRewardPolicy: MinimumRiskRewardPolicy(_minimumRiskReward),
    entryPriceResolver: (_, strategyAnalysis) {
      final level = strategyAnalysis.pullback.matchedLevel;
      if (level == null) {
        throw StateError(
          'Eligible Strategy A setup must retain its matched pullback level.',
        );
      }
      return level.midpoint;
    },
  );

  final replay = const SignalCandidateHistoricalReplay().create(
    feed: feed,
    riskReplay: RiskPlanHistoricalReplay(),
    strategyReplay: StrategySetupHistoricalReplay(),
    strategyParameters: strategyParameters,
    riskParameters: riskParameters,
  );

  const lifecycle = HistoricalSignalLifecycleReplay();
  const builder = HistoricalSignalRecordBuilder();
  final records = <HistoricalSignalRecord>[];
  HistoricalSignalLifecycleState? state;
  HistoricalSignalCandidateResult? active;
  var processed = 0;

  for (final step in replay.run()) {
    processed++;
    if (processed % 10000 == 0) {
      stdout.writeln('  A replay: $processed observations processed');
    }
    final observation = step.observation;

    if (state != null && active != null) {
      final risk = active.riskResult;
      final plan = risk.riskPlan!;
      state = lifecycle.observeClosedM5Candle(
        state: state,
        candle: observation.currentM5Candle,
        observationIndex: observation.index,
        structuralBoundary: plan.structuralStopAnalysis.stop!.price,
        stopPrice: plan.protectiveStopAnalysis.stop!.price,
        targetPrice: plan.targetAnalysis.target!.price,
        maximumWaitingCandles: _maximumWaitingCandles,
      );
      if (state.isTerminal) {
        final record = builder.build(
          state: state,
          terminalAtObservationIndex: observation.index,
          entryPrice: risk.entryPrice!,
          stopPrice: plan.protectiveStopAnalysis.stop!.price,
          targetPrice: plan.targetAnalysis.target!.price,
          riskRewardRatio: plan.riskRewardAnalysis.riskReward!.ratio,
        );
        if (record != null) records.add(record);
        state = null;
        active = null;
      }
      continue;
    }

    final result = step.result;
    if (!result.wasBuilt || !result.candidate!.isQualified) continue;
    final started = lifecycle.start(
      candidate: result.candidate!,
      observationIndex: observation.index,
    );
    if (started == null) continue;
    state = started;
    active = result;
  }

  return records;
}

List<HistoricalSignalRecord> _runB(MultiTimeframeBacktestFeed feed) {
  final sourceParameters = StrategyReplayResearchParameters(
    equalityTolerance: _equalityTolerance,
    zoneHalfWidth: _zoneHalfWidth,
    levelMergeMaxGap: _levelMergeMaxGap,
    scoreProfile: SetupScoreProfiles.baselineResearchV1,
  );
  final riskParameters = CorrectionContinuationRiskResearchParameters(
    atrTimeframe: MarketTimeframe.m15,
    atrPeriod: _atrPeriod,
    atrMultiplier: AtrStopBufferMultiplier(_atrMultiplierValue),
    minimumRiskRewardPolicy: MinimumRiskRewardPolicy(_minimumRiskReward),
  );
  final replay = const CorrectionContinuationRiskHistoricalReplay().create(
    feed: feed,
    candidateReplay: CorrectionContinuationHistoricalReplay(),
    sourceReplay: StrategySetupHistoricalReplay(),
    sourceParameters: sourceParameters,
    riskParameters: riskParameters,
  );

  const lifecycle = HistoricalSignalLifecycleReplay();
  const builder = HistoricalSignalRecordBuilder();
  final records = <HistoricalSignalRecord>[];
  HistoricalSignalLifecycleState? state;
  RiskPlanAnalysis? activePlan;
  var processed = 0;

  for (final step in replay.run()) {
    processed++;
    if (processed % 10000 == 0) {
      stdout.writeln('  B replay: $processed observations processed');
    }
    final observation = step.observation;
    final result = step.result;

    if (state != null && activePlan != null) {
      final plan = activePlan;
      state = lifecycle.observeClosedM5Candle(
        state: state,
        candle: observation.currentM5Candle,
        observationIndex: step.index,
        structuralBoundary: plan.structuralStopAnalysis.stop!.price,
        stopPrice: plan.protectiveStopAnalysis.stop!.price,
        targetPrice: plan.targetAnalysis.target!.price,
        maximumWaitingCandles: _maximumWaitingCandles,
      );
      if (state.isTerminal) {
        final record = builder.build(
          state: state,
          terminalAtObservationIndex: step.index,
          entryPrice: plan.entryZoneAnalysis.zone!.midpoint,
          stopPrice: plan.protectiveStopAnalysis.stop!.price,
          targetPrice: plan.targetAnalysis.target!.price,
          riskRewardRatio: plan.riskRewardAnalysis.riskReward!.ratio,
        );
        if (record != null) records.add(record);
        state = null;
        activePlan = null;
      }
      continue;
    }

    if (!result.isCandidate) continue;
    final plan = result.riskPlan;
    if (plan == null || !plan.isEligible) continue;

    final candidate = _buildBCandidate(
      bias: result.candidateResult!.analysis.bias,
      riskPlan: plan,
    );
    final started = lifecycle.start(
      candidate: candidate,
      observationIndex: step.index,
    );
    if (started == null) continue;
    state = started;
    activePlan = plan;
  }

  return records;
}

SignalCandidate _buildBCandidate({
  required TradingBias bias,
  required RiskPlanAnalysis riskPlan,
}) {
  final snapshot = SetupEvidenceSnapshot(
    eligibility: SetupEligibility.eligible,
    blockReason: null,
    evidence: const [
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
    contributions: const {},
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

void _print(String label, HistoricalStrategyAuditResult result) {
  final v = result.verdict;
  final r = v.report;
  stdout.writeln('');
  stdout.writeln('Strategy $label — ${v.passes ? "PASS" : "FAIL"}');
  stdout.writeln(
    'terminal=${result.terminalPlans} triggered=${result.triggeredTrades} '
    'preEntryTerminal=${result.preEntryTerminalPlans}',
  );
  stdout.writeln(
    'resolved=${r.resolved} W=${r.wins} L=${r.losses} '
    'expired=${r.expired} ambiguous=${r.ambiguous}',
  );
  stdout.writeln(
    'win=${(r.winRate * 100).toStringAsFixed(2)}% '
    'netE=${r.netExpectancyR.toStringAsFixed(3)}R '
    'PF=${r.profitFactor.isInfinite ? "inf" : r.profitFactor.toStringAsFixed(3)} '
    'streak=${r.maxLosingStreak}',
  );
  stdout.writeln(
    'first=${r.firstHalfNetExpectancyR.toStringAsFixed(3)}R '
    'second=${r.secondHalfNetExpectancyR.toStringAsFixed(3)}R',
  );
  stdout.writeln(
    'gates: sample=${v.meetsResolvedSampleFloor} '
    'expectancy=${v.hasPositiveExpectancy} '
    'pf=${v.hasProfitFactorAboveOne} '
    'first=${v.hasPositiveFirstHalf} '
    'second=${v.hasPositiveSecondHalf}',
  );
}
