import 'dart:io';

import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

const _expectedFiles = <MarketTimeframe, String>{
  MarketTimeframe.m5: 'XAUUSD_M5_2024_2026.csv',
  MarketTimeframe.m15: 'XAUUSD_M15_2024_2026.csv',
  MarketTimeframe.h1: 'XAUUSD_H1_2024_2026.csv',
  MarketTimeframe.h4: 'XAUUSD_H4_2024_2026.csv',
};

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_csv_inspect.dart <mt5-history-directory>',
    );
    exitCode = 64;
    return;
  }

  final directory = Directory(arguments.single);
  if (!directory.existsSync()) {
    stderr.writeln('History directory not found: ${directory.path}');
    exitCode = 66;
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

    final series = adapter.parse(
      content: file.readAsStringSync(),
      timeframe: entry.key,
    );
    if (series.candles.isEmpty) {
      stderr.writeln('History file contains no candles: ${file.path}');
      exitCode = 65;
      return;
    }
    loaded[entry.key] = series;
  }

  stdout.writeln('TradeForge V2 — XAUUSD MT5 history inspection');
  stdout.writeln('Timezone: broker wall-clock preserved; UTC is not assumed.');
  stdout.writeln('');

  for (final timeframe in _expectedFiles.keys) {
    final candles = loaded[timeframe]!.candles;
    stdout.writeln(
      '${timeframe.name.toUpperCase().padRight(3)} '
      'candles=${candles.length} '
      'first=${candles.first.openTime} '
      'last=${candles.last.openTime}',
    );
  }

  stdout.writeln('');
  stdout.writeln('CSV history loaded successfully.');
  stdout.writeln(
    'No strategy metrics were produced by this inspection command.',
  );
}
