import 'dart:io';

import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/analytics/paper_historical_replay.dart';
import 'package:tradeforge_backtesting/src/strategy_library/mainstream_strategy_batch.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_paper_historical_replay.dart <history-directory>',
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
  final results = const PaperHistoricalReplay().evaluate(batch);

  stdout.writeln('');
  stdout.writeln('TradeForge V2 — Frozen Paper Segment Historical Replay');
  stdout.writeln(
    'Historical evidence only. Never merged with Paper Forward or Production.',
  );
  stdout.writeln(
    'segment\tfound\tresolved\tW/L\twin%\tnetE\tPF\ttotalR\tmaxDD',
  );

  for (final result in results) {
    final report = result.report;
    stdout.writeln(
      '${result.definition.id}\t'
      '${result.discovered}\t'
      '${report.resolved}\t'
      '${report.wins}/${report.losses}\t'
      '${(report.winRate * 100).toStringAsFixed(2)}\t'
      '${report.netExpectancyR.toStringAsFixed(3)}\t'
      '${report.profitFactor.toStringAsFixed(3)}\t'
      '${result.totalR.toStringAsFixed(3)}\t'
      '${result.maxDrawdownR.toStringAsFixed(3)}',
    );

    final years = result.yearly.keys.toList()..sort();
    for (final year in years) {
      final y = result.yearly[year]!;
      stdout.writeln(
        '  $year\tresolved=${y.report.resolved}\t'
        'W/L=${y.report.wins}/${y.report.losses}\t'
        'win=${(y.report.winRate * 100).toStringAsFixed(2)}%\t'
        'netE=${y.report.netExpectancyR.toStringAsFixed(3)}R\t'
        'PF=${y.report.profitFactor.toStringAsFixed(3)}\t'
        'total=${y.totalR.toStringAsFixed(3)}R\t'
        'DD=${y.maxDrawdownR.toStringAsFixed(3)}R',
      );
    }
  }
}
