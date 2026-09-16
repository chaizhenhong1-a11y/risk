import 'dart:io';

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

/// Explicit, uncalibrated Phase 7 research configuration.
///
/// These are hypotheses for the first real lifecycle run, not production
/// defaults and not claims of optimal XAUUSD parameters.
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
      'Usage: dart run bin/xauusd_full_lifecycle_backtest.dart '
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

  final stopwatch = Stopwatch()..start();

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
          'Eligible historical setup must retain its matched pullback level.',
        );
      }
      return level.midpoint;
    },
  );

  final candidateReplay = const SignalCandidateHistoricalReplay().create(
    feed: feed,
    riskReplay: const RiskPlanHistoricalReplay(),
    strategyReplay: const StrategySetupHistoricalReplay(),
    strategyParameters: strategyParameters,
    riskParameters: riskParameters,
  );

  const lifecycleReplay = HistoricalSignalLifecycleReplay();
  const recordBuilder = HistoricalSignalRecordBuilder();
  const reportBuilder = BacktestRunReportBuilder();

  HistoricalSignalLifecycleState? activeState;
  HistoricalSignalCandidateResult? activeCandidateResult;
  final records = <HistoricalSignalRecord>[];

  var observations = 0;
  var qualifiedCandidatesStarted = 0;
  var qualifiedCandidatesSkippedWhilePlanActive = 0;
  var blockedCandidates = 0;

  DateTime? firstObservation;
  DateTime? lastObservation;
  final observedTradingDates = <DateTime>{};
  var uniqueQualifiedOpportunityEpisodes = 0;
  var previousObservationWasQualified = false;
  var strategySkippedObservations = 0;
  var noTradeBiasBlocks = 0;
  var pullbackNotPresentBlocks = 0;
  var insufficientAtrHistoryObservations = 0;
  var riskAnalyzedObservations = 0;
  var riskEligibleObservations = 0;
  final riskBlockReasons = <RiskEligibilityBlockReason, int>{};
  const regimeClassifier = MarketRegimeClassifier();
  final regimeDiagnostics = _MarketRegimeDiagnostics();
  final correctionDiagnostics = CorrectionRegimeDiagnostics();
  final correctionOutcomeDiagnostics = CorrectionStrategyOutcomeDiagnostics();
  const correctionOutcomeAtr = AverageTrueRange();
  var correctionOutcomeM15HistoryLength = -1;
  double? correctionOutcomeM15Atr;

  for (final step in candidateReplay.run()) {
    if (observations >= maximumObservations) {
      break;
    }

    observations++;
    if (observations % _progressInterval == 0) {
      final elapsed = stopwatch.elapsed;
      final perSecond = elapsed.inMilliseconds == 0
          ? 0.0
          : observations * 1000 / elapsed.inMilliseconds;
      stdout.writeln(
        'Progress: $observations/$maximumObservations M5 '
        'elapsed=${_duration(elapsed)} '
        'rate=${perSecond.toStringAsFixed(1)} obs/s',
      );
    }

    final observation = step.observation;
    firstObservation ??= observation.observationTime;
    lastObservation = observation.observationTime;
    final observationTime = observation.observationTime;
    observedTradingDates.add(
      DateTime(
        observationTime.year,
        observationTime.month,
        observationTime.day,
      ),
    );

    final diagnosticRiskResult = step.result.riskResult;
    final strategyAnalysis = diagnosticRiskResult.strategyResult.analysis;
    final regimeAnalysis = strategyAnalysis == null
        ? null
        : regimeClassifier.classify(
            h4Structure: strategyAnalysis.bias.h4Structure,
            h1Structure: strategyAnalysis.bias.h1Structure,
          );
    final regime = regimeAnalysis?.regime ?? MarketRegime.unknown;
    regimeDiagnostics.observe(regime);
    if (regimeAnalysis != null) {
      final strategyResult = diagnosticRiskResult.strategyResult;
      final m15History = observation.historyFor(MarketTimeframe.m15);
      if (correctionOutcomeM15HistoryLength != m15History.length) {
        correctionOutcomeM15HistoryLength = m15History.length;
        if (m15History.length >= _atrPeriod + 1) {
          correctionOutcomeM15Atr = correctionOutcomeAtr.calculate(
            candles: m15History.sublist(m15History.length - _atrPeriod - 1),
            period: _atrPeriod,
          );
        } else {
          correctionOutcomeM15Atr = null;
        }
      }
      correctionDiagnostics.observe(
        regimeAnalysis: regimeAnalysis,
        m15Structure: strategyResult.m15Structure!,
        levelLiquidityAnalysis: strategyResult.levelLiquidityAnalysis!,
      );
      correctionOutcomeDiagnostics.observe(
        currentM5Candle: observation.currentM5Candle,
        regimeAnalysis: regimeAnalysis,
        m15Structure: strategyResult.m15Structure!,
        levelLiquidityAnalysis: strategyResult.levelLiquidityAnalysis!,
        m15Atr: correctionOutcomeM15Atr,
      );
    }

    switch (diagnosticRiskResult.decision) {
      case RiskReplayDecision.strategySkipped:
        strategySkippedObservations++;
      case RiskReplayDecision.strategyBlocked:
        final blockReason =
            diagnosticRiskResult.strategyResult.analysis!.snapshot.blockReason;
        switch (blockReason) {
          case SetupBlockReason.noTradeBias:
            noTradeBiasBlocks++;
          case SetupBlockReason.pullbackNotPresent:
            pullbackNotPresentBlocks++;
          case null:
            throw StateError(
              'Blocked historical strategy setup must retain a block reason.',
            );
        }
      case RiskReplayDecision.insufficientAtrHistory:
        insufficientAtrHistoryObservations++;
      case RiskReplayDecision.analyzed:
        riskAnalyzedObservations++;
        final eligibility = diagnosticRiskResult.riskPlan!.eligibility;
        if (eligibility.isEligible) {
          riskEligibleObservations++;
        } else {
          final reason = eligibility.blockReason!;
          riskBlockReasons.update(
            reason,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
    }

    // A signal plan is advanced before considering a new candidate on this
    // candle. If it terminates here, this same candle is not reused to start
    // another plan. That avoids silently granting two chronological roles to
    // one OHLC observation.
    if (activeState != null && activeCandidateResult != null) {
      final riskResult = activeCandidateResult.riskResult;
      final riskPlan = riskResult.riskPlan!;

      activeState = lifecycleReplay.observeClosedM5Candle(
        state: activeState,
        candle: observation.currentM5Candle,
        observationIndex: observation.index,
        structuralBoundary: riskPlan.structuralStopAnalysis.stop!.price,
        stopPrice: riskPlan.protectiveStopAnalysis.stop!.price,
        targetPrice: riskPlan.targetAnalysis.target!.price,
        maximumWaitingCandles: _maximumWaitingCandles,
      );

      if (activeState.isTerminal) {
        final riskReward = riskPlan.riskRewardAnalysis.riskReward!;
        final record = recordBuilder.build(
          state: activeState,
          terminalAtObservationIndex: observation.index,
          entryPrice: riskResult.entryPrice!,
          stopPrice: riskPlan.protectiveStopAnalysis.stop!.price,
          targetPrice: riskPlan.targetAnalysis.target!.price,
          riskRewardRatio: riskReward.ratio,
        );
        if (record == null) {
          throw StateError('Terminal historical lifecycle must emit a record.');
        }
        records.add(record);
        activeState = null;
        activeCandidateResult = null;
        continue;
      }

      final observationIsQualified =
          step.result.wasBuilt && step.result.candidate!.isQualified;
      if (observationIsQualified) {
        if (!previousObservationWasQualified) {
          uniqueQualifiedOpportunityEpisodes++;
        }
        qualifiedCandidatesSkippedWhilePlanActive++;
      }
      previousObservationWasQualified = observationIsQualified;
      continue;
    }

    final result = step.result;
    if (!result.wasBuilt) {
      previousObservationWasQualified = false;
      continue;
    }

    final candidate = result.candidate!;
    if (!candidate.isQualified) {
      previousObservationWasQualified = false;
      blockedCandidates++;
      continue;
    }

    if (!previousObservationWasQualified) {
      uniqueQualifiedOpportunityEpisodes++;
    }
    previousObservationWasQualified = true;

    final started = lifecycleReplay.start(
      candidate: candidate,
      observationIndex: observation.index,
    );
    if (started == null) {
      throw StateError('Qualified historical candidate must enter READY.');
    }

    activeState = started;
    activeCandidateResult = result;
    qualifiedCandidatesStarted++;
  }

  stopwatch.stop();

  final report = reportBuilder.build(records);
  final metrics = report.metrics;

  stdout.writeln('TradeForge V2 — REAL XAUUSD full lifecycle backtest');
  stdout.writeln('Timezone: broker wall-clock preserved; UTC is not assumed.');
  stdout.writeln('');
  stdout.writeln('Research configuration (explicit, uncalibrated):');
  stdout.writeln('  equalityTolerance=$_equalityTolerance');
  stdout.writeln('  zoneHalfWidth=$_zoneHalfWidth');
  stdout.writeln('  levelMergeMaxGap=$_levelMergeMaxGap');
  stdout.writeln(
    '  scoreProfile=${SetupScoreProfiles.baselineResearchV1.profileKey}',
  );
  stdout.writeln('  ATR=M15/$_atrPeriod');
  stdout.writeln('  atrMultiplier=$_atrMultiplierValue');
  stdout.writeln('  minimumRR=$_minimumRiskReward');
  stdout.writeln('  maximumWaitingCandles=$_maximumWaitingCandles');
  stdout.writeln('  entryPolicy=matched M15 pullback level midpoint');
  stdout.writeln(
    '  concurrencyPolicy=one signal plan at a time; '
    'new qualified candidates are ignored while a plan is active',
  );
  stdout.writeln(
    '  terminalCandlePolicy=terminal candle is not reused to start a new plan',
  );
  stdout.writeln('');
  stdout.writeln('Observed M5 closes: $observations');
  stdout.writeln('Elapsed replay time: ${_duration(stopwatch.elapsed)}');
  final overallRate = stopwatch.elapsed.inMilliseconds == 0
      ? 0.0
      : observations * 1000 / stopwatch.elapsed.inMilliseconds;
  stdout.writeln(
    'Average replay rate: ${overallRate.toStringAsFixed(1)} obs/s',
  );
  stdout.writeln('First observation: $firstObservation');
  stdout.writeln('Last observation:  $lastObservation');
  stdout.writeln('Qualified plans started: $qualifiedCandidatesStarted');
  stdout.writeln(
    'Qualified candidates skipped while active: '
    '$qualifiedCandidatesSkippedWhilePlanActive',
  );
  stdout.writeln('Blocked candidates while idle: $blockedCandidates');
  stdout.writeln('Unresolved plan at run end: ${activeState != null ? 1 : 0}');
  final allQualifiedCandidateObservations =
      qualifiedCandidatesStarted + qualifiedCandidatesSkippedWhilePlanActive;
  stdout.writeln('');
  stdout.writeln('Gate funnel diagnostics:');
  stdout.writeln('  total M5 observations: $observations');
  stdout.writeln(
    '  strategy skipped (no closed M15): $strategySkippedObservations',
  );
  stdout.writeln('  blocked — H4/H1 no-trade bias: $noTradeBiasBlocks');
  stdout.writeln(
    '  blocked — directional pullback absent: $pullbackNotPresentBlocks',
  );
  stdout.writeln(
    '  blocked — insufficient ATR history: $insufficientAtrHistoryObservations',
  );
  stdout.writeln('  reached risk analysis: $riskAnalyzedObservations');
  stdout.writeln('  risk eligible: $riskEligibleObservations');
  for (final reason in RiskEligibilityBlockReason.values) {
    stdout.writeln(
      '  risk blocked — ${reason.name}: ${riskBlockReasons[reason] ?? 0}',
    );
  }
  stdout.writeln('');
  stdout.writeln('Market regime historical diagnostics:');
  stdout.writeln(
    '  note: range requires explicit range evidence; this replay does not '
    'inject a range detector, so neutral non-unknown structure is transition',
  );
  for (final regime in MarketRegime.values) {
    final stats = regimeDiagnostics.statsFor(regime);
    stdout.writeln(
      '  ${regime.name}: observations=${stats.observations} '
      'share=${_share(stats.observations, observations)} '
      'episodes=${stats.episodes} '
      'avgEpisodeM5=${_ratio(stats.observations, stats.episodes)} '
      'maxEpisodeM5=${stats.maxEpisodeObservations}',
    );
  }
  stdout.writeln('');

  correctionDiagnostics.finish();
  correctionOutcomeDiagnostics.finish();
  stdout.writeln('Correction regime research diagnostics:');
  stdout.writeln(
    '  observations: ${correctionDiagnostics.observations} '
    '(bullish=${correctionDiagnostics.bullishObservations}, '
    'bearish=${correctionDiagnostics.bearishObservations})',
  );
  stdout.writeln(
    '  episodes: ${correctionDiagnostics.episodes} '
    '(bullish=${correctionDiagnostics.bullishEpisodes}, '
    'bearish=${correctionDiagnostics.bearishEpisodes}) '
    'maxEpisodeM5=${correctionDiagnostics.maximumEpisodeM5}',
  );
  for (final structure in MarketStructure.values) {
    final count = correctionDiagnostics.m15StructureObservations[structure]!;
    stdout.writeln(
      '  M15 ${structure.name}: $count '
      '(${(correctionDiagnostics.share(count) * 100).toStringAsFixed(2)}%)',
    );
  }
  stdout.writeln(
    '  M15 aligned with H4: ${correctionDiagnostics.m15AlignedWithH4} '
    '(${(correctionDiagnostics.share(correctionDiagnostics.m15AlignedWithH4) * 100).toStringAsFixed(2)}%)',
  );
  stdout.writeln(
    '  M15 opposed to H4: ${correctionDiagnostics.m15OpposedToH4} '
    '(${(correctionDiagnostics.share(correctionDiagnostics.m15OpposedToH4) * 100).toStringAsFixed(2)}%)',
  );
  stdout.writeln(
    '  M15 neutral/unknown: ${correctionDiagnostics.m15NeutralOrUnknown} '
    '(${(correctionDiagnostics.share(correctionDiagnostics.m15NeutralOrUnknown) * 100).toStringAsFixed(2)}%)',
  );
  stdout.writeln(
    '  directional level-sweep observations: '
    '${correctionDiagnostics.directionalLevelSweepObservations}',
  );
  stdout.writeln(
    '  directional pool-sweep observations: '
    '${correctionDiagnostics.directionalPoolSweepObservations}',
  );
  stdout.writeln(
    '  any directional sweep observations: '
    '${correctionDiagnostics.anyDirectionalSweepObservations} '
    '(${(correctionDiagnostics.share(correctionDiagnostics.anyDirectionalSweepObservations) * 100).toStringAsFixed(2)}%)',
  );
  stdout.writeln('');

  stdout.writeln();
  stdout.writeln('Strategy B correction outcome research (NOT trading rules):');
  stdout.writeln(
    '  trigger candle excluded; outcomes use later M5 candles only; '
    'M15 ATR=$_atrPeriod; same-candle barrier conflicts are ambiguous',
  );
  for (final hypothesis in CorrectionOutcomeHypothesis.values) {
    stdout.writeln('  ${hypothesis.name}:');
    final byHorizon = correctionOutcomeDiagnostics.summaries[hypothesis]!;
    for (final horizon in correctionOutcomeDiagnostics.horizonsM5) {
      final summary = byHorizon[horizon]!;
      stdout.writeln(
        '    horizon=${horizon}M5 triggers=${summary.triggers} '
        'resolved=${summary.resolved} '
        'avgMFE_ATR=${summary.averageMfeAtr.toStringAsFixed(4)} '
        'avgMAE_ATR=${summary.averageMaeAtr.toStringAsFixed(4)} '
        '1ATR-first=${(summary.favorableOneAtrFirstShare * 100).toStringAsFixed(2)}% '
        '2ATR-before-1ATR=${(summary.favorableTwoToOneShare * 100).toStringAsFixed(2)}% '
        'ambiguous1=${summary.ambiguousOneAtrBarrier} '
        'ambiguous2to1=${summary.ambiguousTwoToOneBarrier}',
      );
    }
  }
  stdout.writeln();
  stdout.writeln('Opportunity frequency diagnostics:');
  stdout.writeln('  observed trading dates: ${observedTradingDates.length}');
  stdout.writeln(
    '  all qualified candidate observations: '
    '$allQualifiedCandidateObservations',
  );
  stdout.writeln(
    '  unique qualified opportunity episodes: '
    '$uniqueQualifiedOpportunityEpisodes',
  );
  stdout.writeln(
    '  qualified plans per observed trading date: '
    '${_ratio(qualifiedCandidatesStarted, observedTradingDates.length)}',
  );
  stdout.writeln(
    '  all qualified candidate observations per observed trading date: '
    '${_ratio(allQualifiedCandidateObservations, observedTradingDates.length)}',
  );
  stdout.writeln(
    '  unique qualified opportunities per observed trading date: '
    '${_ratio(uniqueQualifiedOpportunityEpisodes, observedTradingDates.length)}',
  );
  stdout.writeln(
    '  active-plan suppression share: '
    '${_share(qualifiedCandidatesSkippedWhilePlanActive, allQualifiedCandidateObservations)}',
  );
  stdout.writeln('');
  stdout.writeln('Terminal signal records: ${metrics.totalTerminalSignals}');
  stdout.writeln('Invalidated: ${metrics.invalidatedSignals}');
  stdout.writeln('Expired:     ${metrics.expiredSignals}');
  stdout.writeln('Triggered resolved trades: ${metrics.triggeredTrades}');
  stdout.writeln('Wins:   ${metrics.wins}');
  stdout.writeln('Losses: ${metrics.losses}');
  stdout.writeln('Win rate: ${_percent(metrics.winRate)}');
  stdout.writeln(
    'Average planned RR: ${_number(metrics.averagePlannedRiskReward)}',
  );
  stdout.writeln('Expectancy R: ${_number(metrics.expectancyR)}');
  stdout.writeln('Profit factor: ${_number(metrics.profitFactor)}');
  stdout.writeln('');
  stdout.writeln(
    'Backtest complete. Results are baseline research output, not a '
    'production trading claim.',
  );
}

String _duration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  final seconds = value.inSeconds.remainder(60);
  final milliseconds = value.inMilliseconds.remainder(1000);

  if (hours > 0) {
    return '$hours'
        'h ${minutes}m ${seconds}s';
  }
  if (minutes > 0) {
    return '$minutes'
        'm ${seconds}s';
  }
  return '$seconds.${milliseconds.toString().padLeft(3, '0')}s';
}

String _percent(double? value) =>
    value == null ? 'N/A' : '${(value * 100).toStringAsFixed(2)}%';

String _number(double? value) =>
    value == null ? 'N/A' : value.toStringAsFixed(4);

String _ratio(int numerator, int denominator) {
  if (denominator == 0) {
    return 'n/a';
  }
  return (numerator / denominator).toStringAsFixed(4);
}

String _share(int numerator, int denominator) {
  if (denominator == 0) {
    return 'n/a';
  }
  return '${(numerator / denominator * 100).toStringAsFixed(2)}%';
}

final class _MarketRegimeDiagnostics {
  final Map<MarketRegime, _MarketRegimeStats> _stats = {
    for (final regime in MarketRegime.values) regime: _MarketRegimeStats(),
  };

  MarketRegime? _activeRegime;
  int _activeEpisodeObservations = 0;

  void observe(MarketRegime regime) {
    final stats = _stats[regime]!;
    stats.observations++;

    if (_activeRegime == regime) {
      _activeEpisodeObservations++;
      return;
    }

    _closeActiveEpisode();
    _activeRegime = regime;
    _activeEpisodeObservations = 1;
    stats.episodes++;
  }

  _MarketRegimeStats statsFor(MarketRegime regime) {
    if (_activeRegime == regime &&
        _activeEpisodeObservations > _stats[regime]!.maxEpisodeObservations) {
      _stats[regime]!.maxEpisodeObservations = _activeEpisodeObservations;
    }
    return _stats[regime]!;
  }

  void _closeActiveEpisode() {
    final regime = _activeRegime;
    if (regime == null) {
      return;
    }
    final stats = _stats[regime]!;
    if (_activeEpisodeObservations > stats.maxEpisodeObservations) {
      stats.maxEpisodeObservations = _activeEpisodeObservations;
    }
  }
}

final class _MarketRegimeStats {
  int observations = 0;
  int episodes = 0;
  int maxEpisodeObservations = 0;
}
