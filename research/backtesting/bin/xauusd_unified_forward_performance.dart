import 'dart:io';

import 'package:tradeforge_backtesting/src/analytics/performance_sample_formatter.dart';
import 'package:tradeforge_backtesting/src/analytics/strategy_performance_analytics.dart';
import 'package:tradeforge_backtesting/src/analytics/unified_forward_performance_adapter.dart';
import 'package:tradeforge_backtesting/src/forward/paper_signal_journal.dart';
import 'package:tradeforge_backtesting/src/forward/paper_trade_result_journal.dart';

void main(List<String> args) {
  final root = Directory(args.isEmpty ? '.paper_forward' : args.first);
  final signalsFile = File(
    '${root.path}${Platform.pathSeparator}xauusd_signals.jsonl',
  );
  final resultsFile = File(
    '${root.path}${Platform.pathSeparator}xauusd_results.jsonl',
  );

  if (!signalsFile.existsSync() || !resultsFile.existsSync()) {
    stderr.writeln(
      'Unified forward performance requires both files:\n'
      '  ${signalsFile.path}\n'
      '  ${resultsFile.path}',
    );
    exitCode = 66;
    return;
  }

  final signals = const PaperSignalJournal().readAll(signalsFile);
  final results = const PaperTradeResultJournal().readAll(resultsFile);
  final report = const UnifiedForwardPerformanceAdapter().analyze(
    signals: signals,
    results: results,
  );

  stdout.writeln('TradeForge V2 — Unified Forward Performance');
  stdout.writeln('Evidence: new paper/live forward results only.');
  stdout.writeln('Historical baseline and Segment research are excluded.');
  _printMetrics('OVERALL', report.overall);

  for (final strategy in const ['A', 'B', 'C5']) {
    final metrics = report.byStrategy[strategy];
    if (metrics == null) {
      stdout.writeln('\n$strategy\n  no resolved forward trades');
      continue;
    }
    _printMetrics(strategy, metrics);
    final sides = report.byStrategyAndSide[strategy] ?? const {};
    for (final side in const ['BUY', 'SELL']) {
      final sideMetrics = sides[side];
      if (sideMetrics != null) _printMetrics('  $side', sideMetrics);
    }
  }
}

void _printMetrics(String label, StrategyPerformanceMetrics m) {
  stdout.writeln('\n$label');
  stdout.writeln('  sample=${formatPerformanceSampleQuality(m.tradeCount)}');
  stdout.writeln(
    '  trades=${m.tradeCount} W=${m.winCount} L=${m.lossCount} '
    'BE=${m.breakEvenCount}',
  );
  stdout.writeln(
    '  win=${_percent(m.winRate)} E=${_r(m.expectancyR)} '
    'PF=${_pf(m.profitFactor)}',
  );
  stdout.writeln(
    '  total=${m.totalR.toStringAsFixed(3)}R '
    'maxDD=${m.maxDrawdownR.toStringAsFixed(3)}R',
  );
}

String _percent(double? value) =>
    value == null ? 'n/a' : '${(value * 100).toStringAsFixed(2)}%';
String _r(double? value) =>
    value == null ? 'n/a' : '${value.toStringAsFixed(3)}R';
String _pf(double? value) => value == null
    ? 'n/a'
    : value.isInfinite
    ? 'inf'
    : value.toStringAsFixed(3);
