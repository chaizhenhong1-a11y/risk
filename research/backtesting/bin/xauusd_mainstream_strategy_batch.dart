import 'dart:io';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/strategy_library/mainstream_strategy_batch.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_mainstream_strategy_batch.dart <history-directory>',
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
  final loadWatch = Stopwatch()..start();
  final candles = const Mt5HistoryAdapter()
      .parse(content: file.readAsStringSync(), timeframe: MarketTimeframe.m5)
      .candles;
  stdout.writeln(
    'Loaded ${candles.length} CLOSED M5 candles in ${loadWatch.elapsed}.',
  );
  stdout.writeln(
    'Running 18 research strategies with bounded-window indicators...',
  );
  final researchWatch = Stopwatch()..start();
  final results = const MainstreamStrategyBatch().run(candles);
  stdout.writeln('Research completed in ${researchWatch.elapsed}.');
  stdout.writeln('TradeForge V2 — Mainstream Strategy Research Batch');
  stdout.writeln(
    'Research only. PASS does not promote a strategy to production.',
  );
  stdout.writeln(
    'strategy\tcandidates\tresolved\twin%\tnetE\tPF\tfirst\tsecond\tstreak\tgate',
  );
  for (final r in results) {
    final x = r.report;
    stdout.writeln(
      '${r.strategy.id}\t${r.candidates}\t${x.resolved}\t${(x.winRate * 100).toStringAsFixed(2)}\t${x.netExpectancyR.toStringAsFixed(3)}\t${x.profitFactor.toStringAsFixed(3)}\t${x.firstHalfNetExpectancyR.toStringAsFixed(3)}\t${x.secondHalfNetExpectancyR.toStringAsFixed(3)}\t${x.maxLosingStreak}\t${r.historicalGate ? 'HISTORICAL_PASS' : 'RESEARCH_FAIL'}',
    );
  }
}
