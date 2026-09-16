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

/// Increment 070 is deliberately a bounded REAL-DATA replay smoke run.
///
/// The values below are explicit research hypotheses, not production defaults
/// and not claims that they are optimal for XAUUSD. The full lifecycle/metrics
/// run remains a later increment after this real-data bridge is verified.
const _equalityTolerance = 0.10;
const _zoneHalfWidth = 0.50;
const _levelMergeMaxGap = 0.20;
const _atrPeriod = 14;
const _atrMultiplierValue = 0.50;
const _minimumRiskReward = 2.0;
const _defaultSmokeObservations = 250;

void main(List<String> arguments) {
  if (arguments.isEmpty || arguments.length > 2) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_replay_smoke.dart '
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
      : _defaultSmokeObservations;
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
    // Explicit research entry policy for this smoke run:
    // use the midpoint of the directional M15 pullback level.
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

  final replay = const SignalCandidateHistoricalReplay().create(
    feed: feed,
    riskReplay: const RiskPlanHistoricalReplay(),
    strategyReplay: const StrategySetupHistoricalReplay(),
    strategyParameters: strategyParameters,
    riskParameters: riskParameters,
  );

  var observations = 0;
  var upstreamUnavailable = 0;
  var candidatesBuilt = 0;
  var qualified = 0;
  var blocked = 0;
  var buy = 0;
  var sell = 0;
  var noTrade = 0;

  DateTime? firstObservation;
  DateTime? lastObservation;

  for (final step in replay.run()) {
    if (observations >= maximumObservations) {
      break;
    }

    observations++;
    firstObservation ??= step.observation.observationTime;
    lastObservation = step.observation.observationTime;

    final result = step.result;
    if (!result.wasBuilt) {
      upstreamUnavailable++;
      continue;
    }

    candidatesBuilt++;
    final candidate = result.candidate!;

    if (candidate.isQualified) {
      qualified++;
    } else {
      blocked++;
    }

    switch (candidate.direction) {
      case SignalCandidateDirection.buy:
        buy++;
      case SignalCandidateDirection.sell:
        sell++;
      case SignalCandidateDirection.noTrade:
        noTrade++;
    }
  }

  stdout.writeln('TradeForge V2 — REAL XAUUSD replay smoke run');
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
  stdout.writeln('  entryPolicy=matched M15 pullback level midpoint');
  stdout.writeln('');
  stdout.writeln('Observed M5 closes: $observations');
  stdout.writeln('First observation: $firstObservation');
  stdout.writeln('Last observation:  $lastObservation');
  stdout.writeln('Upstream unavailable: $upstreamUnavailable');
  stdout.writeln('Candidates built:     $candidatesBuilt');
  stdout.writeln('Qualified candidates: $qualified');
  stdout.writeln('Blocked candidates:   $blocked');
  stdout.writeln('BUY candidates:       $buy');
  stdout.writeln('SELL candidates:      $sell');
  stdout.writeln('NO TRADE candidates:  $noTrade');
  stdout.writeln('');
  stdout.writeln(
    'Smoke run complete. This command does NOT yet report TP/SL performance.',
  );
}
