import 'dart:io';

import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/strategy_library/mainstream_strategy_batch.dart';
import 'package:tradeforge_backtesting/src/strategy_library/strategy_robustness_validation.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_strategy_robustness.dart <history-directory>',
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
  final historicalPass = batch
      .where((r) => r.historicalGate)
      .toList(growable: false);
  stdout.writeln(
    'Historical PASS strategies: ${historicalPass.length}. Running robustness validation...',
  );

  const validator = StrategyRobustnessValidator();
  for (final result in historicalPass) {
    final report = validator.evaluate(result);
    stdout.writeln('\n=== ${report.strategyId} ===');
    _printSlices('SIDE', report.bySide);
    _printSlices('REGIME', report.byRegime);
    _printSlices('YEAR', report.byYear);
    _printSlices('QUARTER', report.byQuarter);
    _printSlices('ROLLING', report.rolling);
    stdout.writeln(
      'rollingPositive=${(report.rollingPositiveRatio * 100).toStringAsFixed(1)}% '
      'gate=${report.robustnessGate ? 'ROBUSTNESS_PASS' : 'RESEARCH_CONTINUE'}',
    );
  }

  stdout.writeln(
    '\nRobustness PASS is research evidence only; it does not enable live BUY/SELL.',
  );
}

void _printSlices(String title, List<RobustnessSlice> slices) {
  stdout.writeln('$title\tresolved\twin%\tnetE\tPF\tstatus');
  for (final slice in slices) {
    final r = slice.report;
    final status = !slice.hasEvidence
        ? 'LOW_SAMPLE'
        : (slice.positive ? 'POSITIVE' : 'NON_POSITIVE');
    stdout.writeln(
      '${slice.label}\t${r.resolved}\t${(r.winRate * 100).toStringAsFixed(2)}\t'
      '${r.netExpectancyR.toStringAsFixed(3)}\t${r.profitFactor.toStringAsFixed(3)}\t$status',
    );
  }
}
