import 'dart:io';

import 'package:technical_analysis/technical_analysis.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/diagnostics/strategy_d_breakout_feature_diagnostics.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_strategy_d_breakout_discovery.dart '
      '<history-directory>',
    );
    exitCode = 64;
    return;
  }

  final file = File(
    '${args.first}${Platform.pathSeparator}XAUUSD_M5_2024_2026.csv',
  );
  if (!file.existsSync()) {
    stderr.writeln('Missing ${file.path}');
    exitCode = 66;
    return;
  }

  const adapter = Mt5HistoryAdapter();
  final candles = adapter
      .parse(content: file.readAsStringSync(), timeframe: MarketTimeframe.m5)
      .candles;

  const atrCalculator = AverageTrueRange();
  final samples = <BreakoutExpansionSample>[];

  for (var i = 14; i + 48 < candles.length; i++) {
    final window = candles.sublist(i - 14, i + 1);
    final atr = atrCalculator.calculate(candles: window, period: 14);
    if (!atr.isFinite || atr <= 0) continue;

    final candle = candles[i];
    final direction = candle.close > candle.open
        ? BreakoutExpansionDirection.bullish
        : candle.close < candle.open
        ? BreakoutExpansionDirection.bearish
        : null;
    if (direction == null) continue;

    samples.add(
      BreakoutExpansionSample(
        time: candle.closeTime,
        direction: direction,
        rangeAtr: (candle.high - candle.low) / atr,
        bodyAtr: (candle.close - candle.open).abs() / atr,
        return12: candles[i + 12].close - candle.close,
        return24: candles[i + 24].close - candle.close,
        return48: candles[i + 48].close - candle.close,
      ),
    );
  }

  final summaries = const StrategyDBreakoutFeatureDiagnostics().summarize(
    samples,
  );

  stdout.writeln('TradeForge V2 — Increment 123 Strategy D Discovery');
  stdout.writeln('Usable directional M5 observations: ${samples.length}');
  stdout.writeln(
    'Discovery only: continuation percentages are not trade win rates.',
  );
  for (final row in summaries) {
    stdout.writeln(
      '${row.label}: n=${row.samples} '
      '12M5=${_pct(row.continuation12)} '
      '24M5=${_pct(row.continuation24)} '
      '48M5=${_pct(row.continuation48)}',
    );
  }
}

String _pct(double value) => '${(value * 100).toStringAsFixed(2)}%';
