import 'dart:io';

import 'package:tradeforge_backtesting/src/dataset/strategy_c_entry_timing_analysis.dart';

void main(List<String> args) {
  final path = args.isEmpty
      ? '.research_cache${Platform.pathSeparator}strategy_c'
            '${Platform.pathSeparator}xauusd_c5_forward_paths.jsonl'
      : args.first;
  final file = File(path);

  if (!file.existsSync()) {
    stderr.writeln('Dataset not found: ${file.path}');
    stderr.writeln('Run Increment 111 first.');
    exitCode = 66;
    return;
  }

  final paths = file
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .map(C5ForwardPath.fromJsonLine)
      .toList();

  const analysis = C5EntryTimingAnalysis();
  const horizons = [1, 3, 6, 12, 24, 48];

  stdout.writeln('TradeForge V2 — Increment 112 C5 Entry Timing');
  stdout.writeln('Independent C5 paths: ${paths.length}');
  stdout.writeln(
    'Origin = C5 episode-start close. Positive direction = bullish.',
  );
  stdout.writeln('');

  for (final horizon in horizons) {
    final s = analysis.analyze(paths, horizon);
    stdout.writeln(
      '+$horizon M5: n=${s.samples} '
      'bullClose=${(s.bullishCloseRate * 100).toStringAsFixed(1)}% '
      'avgReturn=${s.averageCloseReturn.toStringAsFixed(3)} '
      'avgMFE=${s.averageMfe.toStringAsFixed(3)} '
      'avgMAE=${s.averageMae.toStringAsFixed(3)} '
      'medMFE=${s.medianMfe.toStringAsFixed(3)} '
      'medMAE=${s.medianMae.toStringAsFixed(3)}',
    );
    stdout.writeln(
      '  firstPositiveMedian='
      '${s.firstPositiveCloseMedianOffset.toStringAsFixed(1)} M5 '
      'prePositiveMedMAE='
      '${s.maeBeforeFirstPositiveCloseMedian.toStringAsFixed(3)} '
      'noPositive=${s.noPositiveCloseCount}',
    );
  }

  stdout.writeln('');
  stdout.writeln(
    'Diagnostic only. This does not define an entry, SL, TP, or trade '
    'lifecycle and does not modify production strategies.',
  );
}
