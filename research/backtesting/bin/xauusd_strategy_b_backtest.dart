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

const _equalityTolerance = 0.10;
const _zoneHalfWidth = 0.50;
const _levelMergeMaxGap = 0.20;
const _atrPeriod = 14;
const _atrMultiplierValue = 0.50;
const _minimumRiskReward = 2.0;
const _maximumWaitingCandles = 12;
const _defaultMaximumObservations = 100049;
const _progressInterval = 1000;

void main(List<String> arguments) {
  if (arguments.isEmpty || arguments.length > 2) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_strategy_b_backtest.dart '
      '<mt5-history-directory> [max-observations]',
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

  final maximumObservations = arguments.length == 2
      ? int.tryParse(arguments[1])
      : _defaultMaximumObservations;
  if (maximumObservations == null || maximumObservations <= 0) {
    stderr.writeln('max-observations must be a positive integer.');
    exitCode = 64;
    return;
  }

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
  }

  final feed = MultiTimeframeBacktestFeed(
    m5Candles: loaded[MarketTimeframe.m5]!.candles,
    m15Candles: loaded[MarketTimeframe.m15]!.candles,
    h1Candles: loaded[MarketTimeframe.h1]!.candles,
    h4Candles: loaded[MarketTimeframe.h4]!.candles,
  );

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
    candidateReplay: const CorrectionContinuationHistoricalReplay(),
    sourceReplay: const StrategySetupHistoricalReplay(),
    sourceParameters: sourceParameters,
    riskParameters: riskParameters,
  );

  const lifecycle = HistoricalSignalLifecycleReplay();
  const recordBuilder = HistoricalSignalRecordBuilder();
  const metricsCalculator = BacktestMetricsCalculator();

  final stopwatch = Stopwatch()..start();
  final records = <HistoricalSignalRecord>[];
  final observedTradingDates = <DateTime>{};

  HistoricalSignalLifecycleState? activeState;
  RiskPlanAnalysis? activeRiskPlan;

  var observations = 0;
  var candidateEvents = 0;
  var candidatesWithoutEntryLevel = 0;
  var riskEligibleCandidates = 0;
  var plansStarted = 0;
  var candidatesSkippedWhileActive = 0;
  var buyCandidates = 0;
  var sellCandidates = 0;
  final riskBlocks = <RiskEligibilityBlockReason, int>{};
  final rawRiskRewards = <double>[];
  final blockedRiskRewards = <double>[];
  final entryToStopDistances = <double>[];
  final entryToTargetDistances = <double>[];
  final entryToStopAtr = <double>[];
  final entryToTargetAtr = <double>[];

  for (final step in replay.run()) {
    if (observations >= maximumObservations) break;
    observations++;

    if (observations % _progressInterval == 0) {
      final elapsed = stopwatch.elapsed;
      final rate = elapsed.inMilliseconds == 0
          ? 0.0
          : observations * 1000 / elapsed.inMilliseconds;
      stdout.writeln(
        'Progress: $observations/$maximumObservations M5 '
        'elapsed=${_duration(elapsed)} rate=${rate.toStringAsFixed(1)} obs/s',
      );
    }

    final observation = step.observation;
    final time = observation.observationTime;
    observedTradingDates.add(DateTime(time.year, time.month, time.day));

    final result = step.result;
    if (result.isCandidate) {
      candidateEvents++;
      final candidateBias = result.candidateResult!.analysis.bias;
      if (candidateBias == TradingBias.buy) {
        buyCandidates++;
      } else if (candidateBias == TradingBias.sell) {
        sellCandidates++;
      }
    }

    if (activeState != null && activeRiskPlan != null) {
      if (result.isCandidate) candidatesSkippedWhileActive++;

      final riskPlan = activeRiskPlan;
      final structuralBoundary = riskPlan.structuralStopAnalysis.stop!.price;
      final stopPrice = riskPlan.protectiveStopAnalysis.stop!.price;
      final targetPrice = riskPlan.targetAnalysis.target!.price;

      activeState = lifecycle.observeClosedM5Candle(
        state: activeState,
        candle: observation.currentM5Candle,
        observationIndex: step.index,
        structuralBoundary: structuralBoundary,
        stopPrice: stopPrice,
        targetPrice: targetPrice,
        maximumWaitingCandles: _maximumWaitingCandles,
      );

      if (activeState.isTerminal) {
        final rr = riskPlan.riskRewardAnalysis.riskReward!.ratio;
        final record = recordBuilder.build(
          state: activeState,
          terminalAtObservationIndex: step.index,
          entryPrice: riskPlan.entryZoneAnalysis.zone!.midpoint,
          stopPrice: stopPrice,
          targetPrice: targetPrice,
          riskRewardRatio: rr,
        );
        if (record != null) records.add(record);
        activeState = null;
        activeRiskPlan = null;
        // Frozen baseline policy: terminal candle is not reused to start a new
        // plan, even if a Strategy B candidate event also exists on this step.
        continue;
      }

      continue;
    }

    if (!result.isCandidate) continue;

    final riskPlan = result.riskPlan;
    if (riskPlan == null) {
      candidatesWithoutEntryLevel++;
      continue;
    }

    final entry = riskPlan.entryZoneAnalysis.zone?.midpoint;
    final stop = riskPlan.protectiveStopAnalysis.stop?.price;
    final target = riskPlan.targetAnalysis.target?.price;
    final rr = riskPlan.riskRewardAnalysis.riskReward?.ratio;
    final atr = result.atr;
    if (entry != null && stop != null && target != null && rr != null) {
      final stopDistance = (entry - stop).abs();
      final targetDistance = (target - entry).abs();
      rawRiskRewards.add(rr);
      entryToStopDistances.add(stopDistance);
      entryToTargetDistances.add(targetDistance);
      if (atr != null && atr > 0) {
        entryToStopAtr.add(stopDistance / atr);
        entryToTargetAtr.add(targetDistance / atr);
      }
    }

    if (!riskPlan.isEligible) {
      final reason = riskPlan.eligibility.blockReason!;
      if (reason == RiskEligibilityBlockReason.belowMinimumRiskReward &&
          rr != null) {
        blockedRiskRewards.add(rr);
      }
      riskBlocks.update(reason, (count) => count + 1, ifAbsent: () => 1);
      continue;
    }

    riskEligibleCandidates++;
    final signalCandidate = _buildLifecycleCandidate(
      bias: result.candidateResult!.analysis.bias,
      riskPlan: riskPlan,
    );
    final state = lifecycle.start(
      candidate: signalCandidate,
      observationIndex: step.index,
    );
    if (state == null) continue;

    plansStarted++;
    activeState = state;
    activeRiskPlan = riskPlan;
  }

  stopwatch.stop();
  final metrics = metricsCalculator.calculate(records);
  final tradingDays = observedTradingDates.length;

  stdout.writeln('');
  stdout.writeln('TradeForge V2 — Strategy B independent historical backtest');
  stdout.writeln('Timezone: broker wall-clock preserved; UTC is not assumed.');
  stdout.writeln('');
  stdout.writeln('Strategy B v1: Correction Continuation');
  stdout.writeln(
    '  regime=H4 trend + opposing H1 correction; trigger=M15 realignment to H4',
  );
  stdout.writeln(
    '  entryZone=nearest active directional M15 level behind trigger price',
  );
  stdout.writeln('  ATR=M15/$_atrPeriod multiplier=$_atrMultiplierValue');
  stdout.writeln('  minimumRR=$_minimumRiskReward');
  stdout.writeln('  maximumWaitingCandles=$_maximumWaitingCandles');
  stdout.writeln('  sweep=soft evidence only; NOT a Gate');
  stdout.writeln('  concurrency=one Strategy B plan at a time');
  stdout.writeln('');
  stdout.writeln('Observed M5 closes: $observations');
  stdout.writeln('Observed trading dates: $tradingDays');
  stdout.writeln('Elapsed: ${_duration(stopwatch.elapsed)}');
  stdout.writeln('Strategy B candidate events: $candidateEvents');
  stdout.writeln(
    'Candidates without directional entry level: $candidatesWithoutEntryLevel',
  );
  stdout.writeln('Risk eligible candidates: $riskEligibleCandidates');
  stdout.writeln('Plans started: $plansStarted');
  stdout.writeln(
    'Candidate events skipped while active: $candidatesSkippedWhileActive',
  );
  stdout.writeln('Risk blocks:');
  for (final reason in RiskEligibilityBlockReason.values) {
    stdout.writeln('  ${reason.name}: ${riskBlocks[reason] ?? 0}');
  }
  stdout.writeln('');
  stdout.writeln('Strategy B candidate / risk diagnostics:');
  stdout.writeln('  BUY candidates: $buyCandidates');
  stdout.writeln('  SELL candidates: $sellCandidates');
  _printDistribution('raw RR', rawRiskRewards);
  _printDistribution('below-minimum RR', blockedRiskRewards);
  _printDistribution('entry -> stop distance', entryToStopDistances);
  _printDistribution('entry -> target distance', entryToTargetDistances);
  _printDistribution('entry -> stop / ATR', entryToStopAtr);
  _printDistribution('entry -> target / ATR', entryToTargetAtr);
  stdout.writeln('');
  stdout.writeln('Strategy B terminal results:');
  stdout.writeln('  terminal plans: ${metrics.totalTerminalSignals}');
  stdout.writeln('  invalidated: ${metrics.invalidatedSignals}');
  stdout.writeln('  expired: ${metrics.expiredSignals}');
  stdout.writeln('  triggered resolved trades: ${metrics.triggeredTrades}');
  stdout.writeln('  wins: ${metrics.wins}');
  stdout.writeln('  losses: ${metrics.losses}');
  stdout.writeln('  win rate: ${_percent(metrics.winRate)}');
  stdout.writeln(
    '  average planned RR: ${_number(metrics.averagePlannedRiskReward)}',
  );
  stdout.writeln('  expectancy R: ${_number(metrics.expectancyR)}');
  stdout.writeln('  profit factor: ${_number(metrics.profitFactor)}');
  stdout.writeln(
    '  triggered trades / observed trading date: '
    '${tradingDays == 0 ? 'n/a' : (metrics.triggeredTrades / tradingDays).toStringAsFixed(4)}',
  );
  stdout.writeln('');
  stdout.writeln(
    'Research only. No spread/slippage/commission; results are not a production trading claim.',
  );
}

SignalCandidate _buildLifecycleCandidate({
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

void _printDistribution(String label, List<double> values) {
  if (values.isEmpty) {
    stdout.writeln('  $label: n/a');
    return;
  }

  final sorted = List<double>.of(values)..sort();
  final mean = sorted.reduce((a, b) => a + b) / sorted.length;
  stdout.writeln(
    '  $label: n=${sorted.length} '
    'min=${sorted.first.toStringAsFixed(4)} '
    'p25=${_quantile(sorted, 0.25).toStringAsFixed(4)} '
    'median=${_quantile(sorted, 0.50).toStringAsFixed(4)} '
    'p75=${_quantile(sorted, 0.75).toStringAsFixed(4)} '
    'max=${sorted.last.toStringAsFixed(4)} '
    'mean=${mean.toStringAsFixed(4)}',
  );
}

double _quantile(List<double> sorted, double probability) {
  if (sorted.length == 1) return sorted.first;
  final position = (sorted.length - 1) * probability;
  final lower = position.floor();
  final upper = position.ceil();
  if (lower == upper) return sorted[lower];
  final fraction = position - lower;
  return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction;
}

String _percent(double? value) =>
    value == null ? 'n/a' : '${(value * 100).toStringAsFixed(2)}%';
String _number(double? value) => value?.toStringAsFixed(4) ?? 'n/a';

String _duration(Duration duration) {
  if (duration.inMinutes > 0) {
    return '${duration.inMinutes}m ${(duration.inSeconds % 60)}s';
  }
  return '${(duration.inMilliseconds / 1000).toStringAsFixed(3)}s';
}
