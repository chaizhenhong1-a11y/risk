import 'dart:io';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main(List<String> arguments) {
  if (arguments.isNotEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_strategy_b_enriched_feature_discovery.dart',
    );
    exitCode = 64;
    return;
  }
  final file = File(
    '${Directory.current.path}${Platform.pathSeparator}.research_cache${Platform.pathSeparator}strategy_b_candidates_v1.json',
  );
  final snapshot = const StrategyBResearchSnapshotStore().read(file);
  if (snapshot == null) {
    stderr.writeln('Strategy B research snapshot not found or unreadable.');
    stderr.writeln('Build it with xauusd_strategy_b_candidate_research.dart.');
    exitCode = 66;
    return;
  }
  final report = const StrategyBEnrichedFeatureDiscovery().analyze(snapshot);
  stdout.writeln(
    'TradeForge V2 — Strategy B enriched candidate feature discovery',
  );
  stdout.writeln('Snapshot: ${file.path}');
  stdout.writeln('Candidates: ${report.candidateCount}');
  stdout.writeln(
    'Snapshot-only research. No historical replay and no Strategy B gate change.',
  );
  for (final s in report.sections) {
    stdout.writeln('\nForward horizon: ${s.horizonM5} M5');
    _section('H1 correction excursion / M15 ATR', s.byCorrectionExcursion);
    _section('H1 correction duration', s.byCorrectionDuration);
    _section('M15 realignment body / ATR', s.byRealignmentBody);
    _section('M15 directional close location', s.byDirectionalClose);
    stdout.writeln('  RR-eligible only');
    _section(
      '    H1 correction excursion / M15 ATR',
      s.eligibleByCorrectionExcursion,
    );
    _section('    H1 correction duration', s.eligibleByCorrectionDuration);
    _section('    M15 realignment body / ATR', s.eligibleByRealignmentBody);
    _section(
      '    M15 directional close location',
      s.eligibleByDirectionalClose,
    );
  }
  stdout.writeln(
    '\nInterpretation guard: these buckets are discovery hypotheses, not production filters.',
  );
  stdout.writeln(
    'Any Strategy B v2 rule change requires fresh full replay and independent validation.',
  );
}

void _section<T extends Object>(
  String label,
  Map<T, StrategyBEnrichedFeatureSummary> values,
) {
  stdout.writeln('  $label');
  for (final e in values.entries) {
    final s = e.value;
    stdout.writeln(
      '    ${_name(e.key)}: n=${s.candidates} eligible=${s.eligible} continuation=${s.continuation} rejection=${s.rejection} unresolved=${s.unresolved} resolvedContinuationRate=${_pct(s.continuationRate)}',
    );
  }
}

String _name(Object v) => v.toString().split('.').last;
String _pct(double? v) =>
    v == null ? 'n/a' : '${(v * 100).toStringAsFixed(2)}%';
