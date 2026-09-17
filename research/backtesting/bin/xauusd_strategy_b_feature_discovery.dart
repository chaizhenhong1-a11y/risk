import 'dart:io';

import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main(List<String> arguments) {
  if (arguments.isNotEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_strategy_b_feature_discovery.dart',
    );
    exitCode = 64;
    return;
  }

  final file = File(
    '${Directory.current.path}${Platform.pathSeparator}.research_cache'
    '${Platform.pathSeparator}strategy_b_candidates_v1.json',
  );
  final snapshot = const StrategyBResearchSnapshotStore().read(file);
  if (snapshot == null) {
    stderr.writeln('Strategy B research snapshot not found or unreadable.');
    stderr.writeln('Build it with xauusd_strategy_b_candidate_research.dart.');
    exitCode = 66;
    return;
  }

  final report = const StrategyBCandidateFeatureDiscovery().analyze(snapshot);
  stdout.writeln('TradeForge V2 — Strategy B candidate feature discovery');
  stdout.writeln('Snapshot: ${file.path}');
  stdout.writeln('Candidates: ${report.candidateCount}');
  stdout.writeln(
    'Research only. These observations do not modify Strategy B gates.',
  );

  for (final section in report.sections) {
    stdout.writeln('');
    stdout.writeln('Forward horizon: ${section.horizonM5} M5');
    _print('ALL', section.all);
    stdout.writeln('  Direction');
    for (final entry in section.byDirection.entries) {
      _print('    ${entry.key.name.toUpperCase()}', entry.value);
    }
    stdout.writeln('  Volatility');
    for (final entry in section.byVolatility.entries) {
      _print('    ${entry.key.name}', entry.value);
    }
    stdout.writeln('  Planned RR');
    for (final entry in section.byRiskReward.entries) {
      _print('    ${entry.key.name}', entry.value);
    }
    stdout.writeln('  RR-eligible only');
    _print('    ALL', section.eligibleOnly);
    for (final entry in section.eligibleByVolatility.entries) {
      _print('    ${entry.key.name}', entry.value);
    }
  }

  stdout.writeln('');
  stdout.writeln(
    'Interpretation guard: small buckets are hypotheses, not production filters.',
  );
  stdout.writeln(
    'Any Strategy B v2 rule change still requires a fresh full replay and independent validation.',
  );
}

void _print(String label, StrategyBFeatureSummary summary) {
  final continuationRate = summary.continuationRate;
  final eligibilityRate = summary.eligibilityRate;
  stdout.writeln(
    '$label: n=${summary.candidates} eligible=${summary.eligible} '
    'eligibilityRate=${_percent(eligibilityRate)} '
    'continuation=${summary.continuation} rejection=${summary.rejection} '
    'unresolved=${summary.unresolved} '
    'resolvedContinuationRate=${_percent(continuationRate)}',
  );
}

String _percent(double? value) =>
    value == null ? 'n/a' : '${(value * 100).toStringAsFixed(2)}%';
