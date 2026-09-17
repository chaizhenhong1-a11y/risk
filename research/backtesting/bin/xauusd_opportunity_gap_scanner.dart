import 'dart:convert';
import 'dart:io';

import 'package:strategy_engine/strategy_engine.dart';

import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/diagnostics/opportunity_gap_scanner.dart';

const _files = <MarketTimeframe, String>{
  MarketTimeframe.m5: 'XAUUSD_M5_2024_2026.csv',
  MarketTimeframe.m15: 'XAUUSD_M15_2024_2026.csv',
  MarketTimeframe.h1: 'XAUUSD_H1_2024_2026.csv',
  MarketTimeframe.h4: 'XAUUSD_H4_2024_2026.csv',
};

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_opportunity_gap_scanner.dart '
      '<history-directory>',
    );
    exitCode = 64;
    return;
  }

  const adapter = Mt5HistoryAdapter();
  final loaded = <MarketTimeframe, Mt5HistorySeries>{};

  for (final entry in _files.entries) {
    final file = File('${args.first}${Platform.pathSeparator}${entry.value}');
    if (!file.existsSync()) {
      stderr.writeln('Missing: ${file.path}');
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

  final parameters = StrategyReplayResearchParameters(
    equalityTolerance: .10,
    zoneHalfWidth: .50,
    levelMergeMaxGap: .20,
    scoreProfile: SetupScoreProfiles.baselineResearchV1,
  );

  const sourceReplay = StrategySetupHistoricalReplay();
  final aEvaluator = sourceReplay
      .create(feed: feed, parameters: parameters)
      .evaluator;
  final bEvaluator = const CorrectionContinuationHistoricalReplay()
      .create(
        feed: feed,
        sourceReplay: sourceReplay,
        sourceParameters: parameters,
      )
      .evaluator;

  const regimeClassifier = MarketRegimeClassifier();
  final scanner = OpportunityGapScanner();
  var previousA = false;
  var observations = 0;
  final stopwatch = Stopwatch()..start();

  for (final observation in feed.observations()) {
    observations++;
    if (observations % 10000 == 0) {
      stdout.writeln(
        'Progress: $observations/100049 elapsed=${stopwatch.elapsed}',
      );
    }

    final source = aEvaluator(observation);
    if (!source.wasAnalyzed) continue;

    final analysis = source.analysis!;
    final regime = regimeClassifier.classify(
      h4Structure: analysis.bias.h4Structure,
      h1Structure: analysis.bias.h1Structure,
    );

    final aEligible = analysis.evaluation.isEligible;
    final aStarted = aEligible && !previousA;
    previousA = aEligible;

    final b = bEvaluator(observation);
    final bCandidate = b != null && b.isCandidate;

    scanner.observe(
      observedAt: observation.observationTime,
      signature: OpportunityGapSignature(
        regime: regime.regime,
        h4: analysis.bias.h4Structure,
        h1: analysis.bias.h1Structure,
        m15: source.m15Structure!,
      ),
      hasOpportunity: aStarted || bCandidate,
    );
  }

  final c5File = File(
    '.research_cache${Platform.pathSeparator}strategy_c'
    '${Platform.pathSeparator}xauusd_c5_structural_risk.jsonl',
  );
  if (!c5File.existsSync()) {
    stderr.writeln(
      'Missing C5 cache: ${c5File.path}. Run Increment 117 first.',
    );
    exitCode = 66;
    return;
  }

  for (final line in c5File.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final json = jsonDecode(line) as Map<String, dynamic>;
    scanner.markOpportunity(DateTime.parse(json['time'] as String));
  }

  final report = scanner.finish();
  stopwatch.stop();

  stdout.writeln('');
  stdout.writeln(
    'TradeForge V2 — Increment 129 A+B+C5 Opportunity Gap Scanner',
  );
  stdout.writeln('Observed M5 closes: $observations');
  stdout.writeln('Trading days: ${report.tradingDays}');
  stdout.writeln('A+B+C5 zero-opportunity days: ${report.zeroOpportunityDays}');
  stdout.writeln(
    'Structural observations on zero days: ${report.zeroDayObservations}',
  );
  stdout.writeln('');
  stdout.writeln('Top recurring uncovered structural states:');

  final limit = report.rows.length < 15 ? report.rows.length : 15;
  for (var i = 0; i < limit; i++) {
    final row = report.rows[i];
    final share = report.zeroDayObservations == 0
        ? 0.0
        : row.observations / report.zeroDayObservations * 100;
    stdout.writeln(
      '${i + 1}. ${row.signature.label} '
      'observations=${row.observations} '
      'share=${share.toStringAsFixed(2)}% '
      'daysPresent=${row.daysPresent} '
      'dominantDays=${row.dominantDays}',
    );
  }

  stdout.writeln('');
  stdout.writeln(
    'Research only: ranking identifies coverage gaps, not trading edge.',
  );
  stdout.writeln(
    'Do not create a strategy from frequency alone; the leading state must '
    'pass a separate forward-outcome discovery.',
  );
}
