import 'dart:io';

import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/strategy_library/batch2_research_selection.dart';
import 'package:tradeforge_backtesting/src/strategy_library/mainstream_strategy_batch.dart';
import 'package:tradeforge_backtesting/src/strategy_library/strategy_edge_segmentation.dart';
import 'package:tradeforge_backtesting/src/strategy_library/strategy_robustness_validation.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_batch2_robustness.dart <history-directory>',
    );
    exitCode = 64;
    return;
  }

  final file = File(
    '${args.first}${Platform.pathSeparator}XAUUSD_M5_2024_2026.csv',
  );
  if (!file.existsSync()) {
    stderr.writeln('Missing: ${file.path}');
    exitCode = 66;
    return;
  }

  stdout.writeln('Loading MT5 history: ${file.path}');
  final candles = const Mt5HistoryAdapter()
      .parse(content: file.readAsStringSync(), timeframe: MarketTimeframe.m5)
      .candles;
  stdout.writeln('Loaded ${candles.length} CLOSED M5 candles.');

  final batch = const MainstreamStrategyBatch().run(candles);
  final selected = Batch2ResearchSelection.selectHistoricalPass(batch);

  stdout.writeln(
    'Batch-2 first-gate hypotheses: ${selected.length}/'
    '${Batch2ResearchSelection.historicalPassIds.length}.',
  );
  stdout.writeln(
    'Research only. No result below enables production/live BUY/SELL.',
  );

  const robustness = StrategyRobustnessValidator();
  for (final result in selected) {
    final report = robustness.evaluate(result);
    stdout.writeln('\n=== ROBUSTNESS ${report.strategyId} ===');
    _printSlices('SIDE', report.bySide);
    _printSlices('REGIME', report.byRegime);
    _printSlices('YEAR', report.byYear);
    _printSlices('QUARTER', report.byQuarter);
    _printSlices('ROLLING', report.rolling);
    stdout.writeln(
      'rollingPositive='
      '${(report.rollingPositiveRatio * 100).toStringAsFixed(1)}% '
      'gate=${report.robustnessGate ? 'ROBUSTNESS_PASS' : 'RESEARCH_CONTINUE'}',
    );
  }

  // Evaluate the full historical-pass pool first so overlap is measured
  // against all eligible strategies, then print only the frozen Batch-2 IDs.
  final allSegments = const StrategyEdgeSegmentation().evaluate(batch);
  final segments = allSegments
      .where(
        (segment) => Batch2ResearchSelection.historicalPassIds.contains(
          segment.strategyId,
        ),
      )
      .toList(growable: false);

  stdout.writeln('\n=== BATCH-2 SIDE x REGIME SEGMENTS ===');
  stdout.writeln(
    'strategy\tside\tregime\tresolved\twin%\tnetE\tPF\tfirst\tsecond\t'
    'years+\trolling+\toverlap%\tgate',
  );
  for (final segment in segments) {
    final r = segment.report;
    stdout.writeln(
      '${segment.strategyId}\t'
      '${segment.side.name.toUpperCase()}\t'
      '${segment.regime.toUpperCase()}\t'
      '${r.resolved}\t'
      '${(r.winRate * 100).toStringAsFixed(2)}\t'
      '${r.netExpectancyR.toStringAsFixed(3)}\t'
      '${r.profitFactor.toStringAsFixed(3)}\t'
      '${r.firstHalfNetExpectancyR.toStringAsFixed(3)}\t'
      '${r.secondHalfNetExpectancyR.toStringAsFixed(3)}\t'
      '${segment.positiveYears}\t'
      '${(segment.rollingPositiveRatio * 100).toStringAsFixed(1)}%\t'
      '${(segment.overlapRatio * 100).toStringAsFixed(1)}%\t'
      '${segment.segmentationGate ? 'SEGMENT_PASS' : 'RESEARCH_CONTINUE'}',
    );
  }

  final robustnessPassed = selected
      .where((result) => robustness.evaluate(result).robustnessGate)
      .length;
  final segmentPassed = segments.where((s) => s.segmentationGate).length;

  stdout.writeln(
    '\nBatch-2 summary: ROBUSTNESS_PASS=$robustnessPassed/${selected.length}, '
    'SEGMENT_PASS=$segmentPassed/${segments.length}.',
  );
  stdout.writeln(
    'PASS remains historical research evidence only; unseen paper-forward '
    'validation is still required.',
  );
}

void _printSlices(String title, List<RobustnessSlice> slices) {
  stdout.writeln('$title\tresolved\twin%\tnetE\tPF\tfirst\tsecond\tstatus');
  for (final slice in slices) {
    final r = slice.report;
    final status = !slice.hasEvidence
        ? 'LOW_SAMPLE'
        : (slice.positive ? 'POSITIVE' : 'NON_POSITIVE');
    stdout.writeln(
      '${slice.label}\t'
      '${r.resolved}\t'
      '${(r.winRate * 100).toStringAsFixed(2)}\t'
      '${r.netExpectancyR.toStringAsFixed(3)}\t'
      '${r.profitFactor.toStringAsFixed(3)}\t'
      '${r.firstHalfNetExpectancyR.toStringAsFixed(3)}\t'
      '${r.secondHalfNetExpectancyR.toStringAsFixed(3)}\t'
      '$status',
    );
  }
}
