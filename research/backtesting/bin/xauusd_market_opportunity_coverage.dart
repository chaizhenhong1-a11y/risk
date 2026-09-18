import 'dart:convert';
import 'dart:io';

import 'package:tradeforge_backtesting/src/validation/market_opportunity_coverage.dart';

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_market_opportunity_coverage.dart '
      '<coverage-observations.jsonl>',
    );
    stderr.writeln(
      'Each row: {"state":"range","candidate":false}. '
      'Optional: {"strategy":"A","evidence":"historicalPass"}.',
    );
    exitCode = 64;
    return;
  }

  final file = File(arguments.single);
  if (!file.existsSync()) {
    stderr.writeln('Coverage input not found: ${file.path}');
    exitCode = 66;
    return;
  }

  final observations = <OpportunityMarketState, int>{};
  final candidates = <OpportunityMarketState, int>{};
  final strategies = <OpportunityMarketState, String?>{};
  final evidence = <OpportunityMarketState, StrategyEvidenceTier>{};

  for (final line in file.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final row = jsonDecode(line) as Map<String, dynamic>;
    final state = OpportunityMarketState.values.byName(row['state'] as String);
    observations[state] = (observations[state] ?? 0) + 1;
    if (row['candidate'] == true) {
      candidates[state] = (candidates[state] ?? 0) + 1;
    }

    final strategy = row['strategy'] as String?;
    if (strategy != null) strategies[state] = strategy;

    final tier = row['evidence'] as String?;
    if (tier != null) {
      evidence[state] = StrategyEvidenceTier.values.byName(tier);
    }
  }

  const analyzer = MarketOpportunityCoverageAnalyzer();
  final report = analyzer.analyze([
    for (final state in OpportunityMarketState.values)
      OpportunityCoverageCell(
        state: state,
        observations: observations[state] ?? 0,
        candidateObservations: candidates[state] ?? 0,
        strategy: strategies[state],
        evidence: evidence[state] ?? StrategyEvidenceTier.unassigned,
      ),
  ]);

  stdout.writeln('TradeForge V2 — Increment 144 Market Opportunity Coverage');
  stdout.writeln(
    'Descriptive research map only. This report does NOT add a trading gate.',
  );
  stdout.writeln('');
  stdout.writeln(
    'State       | Obs      | Candidates | Coverage | Uncovered | Strategy | Evidence',
  );
  stdout.writeln(
    '------------|----------|------------|----------|-----------|----------|---------',
  );

  for (final cell in report.researchPriority) {
    stdout.writeln(
      '${cell.state.name.padRight(11)} | '
      '${cell.observations.toString().padLeft(8)} | '
      '${cell.candidateObservations.toString().padLeft(10)} | '
      '${(cell.candidateCoverage * 100).toStringAsFixed(2).padLeft(7)}% | '
      '${cell.uncoveredObservations.toString().padLeft(9)} | '
      '${(cell.strategy ?? '-').padRight(8)} | '
      '${cell.evidence.name}',
    );
  }

  stdout.writeln('');
  stdout.writeln(
    'Research priority is ranked by uncovered observations, not by a daily '
    'trade quota. A large gap is a place to search for an independent '
    'positive-expectancy strategy, not permission to loosen A/C5.',
  );
}
