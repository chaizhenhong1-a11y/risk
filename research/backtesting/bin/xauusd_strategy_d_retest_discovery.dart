import 'dart:io';

import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/diagnostics/strategy_d_retest_diagnostics.dart';

const _m15Lookback = 20;
const _retestHorizon = 12;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_strategy_d_retest_discovery.dart '
      '<history-directory>',
    );
    exitCode = 64;
    return;
  }

  final directory = args.first;
  final m5File = File(
    '$directory${Platform.pathSeparator}XAUUSD_M5_2024_2026.csv',
  );
  final m15File = File(
    '$directory${Platform.pathSeparator}XAUUSD_M15_2024_2026.csv',
  );

  if (!m5File.existsSync() || !m15File.existsSync()) {
    stderr.writeln('Missing XAUUSD M5 or M15 history file.');
    exitCode = 66;
    return;
  }

  const adapter = Mt5HistoryAdapter();
  final m5 = adapter
      .parse(content: m5File.readAsStringSync(), timeframe: MarketTimeframe.m5)
      .candles;
  final m15 = adapter
      .parse(
        content: m15File.readAsStringSync(),
        timeframe: MarketTimeframe.m15,
      )
      .candles;

  final samples = <BreakoutRetestSample>[];
  var m15Index = _m15Lookback - 1;

  for (var i = 1; i + 48 < m5.length; i++) {
    final breakout = m5[i];

    while (m15Index + 1 < m15.length &&
        !m15[m15Index + 1].closeTime.isAfter(breakout.closeTime)) {
      m15Index++;
    }
    if (m15Index < _m15Lookback - 1) continue;

    final first = m15Index - (_m15Lookback - 1);
    var resistance = double.negativeInfinity;
    var support = double.infinity;
    for (var j = first; j <= m15Index; j++) {
      if (m15[j].high > resistance) resistance = m15[j].high;
      if (m15[j].low < support) support = m15[j].low;
    }

    final previousClose = m5[i - 1].close;
    BreakoutRetestDirection? direction;
    double level = 0;

    if (previousClose <= resistance && breakout.close > resistance) {
      direction = BreakoutRetestDirection.bullish;
      level = resistance;
    } else if (previousClose >= support && breakout.close < support) {
      direction = BreakoutRetestDirection.bearish;
      level = support;
    }
    if (direction == null) continue;

    var outcome = BreakoutRetestOutcome.noRetest;
    int? retestOffset;

    for (var offset = 1; offset <= _retestHorizon; offset++) {
      final candle = m5[i + offset];
      final touches = switch (direction) {
        BreakoutRetestDirection.bullish => candle.low <= level,
        BreakoutRetestDirection.bearish => candle.high >= level,
      };
      if (!touches) continue;

      retestOffset = offset;
      final holds = switch (direction) {
        BreakoutRetestDirection.bullish => candle.close > level,
        BreakoutRetestDirection.bearish => candle.close < level,
      };
      outcome = holds
          ? BreakoutRetestOutcome.held
          : BreakoutRetestOutcome.failed;
      break;
    }

    samples.add(
      BreakoutRetestSample(
        breakoutTime: breakout.closeTime,
        direction: direction,
        outcome: outcome,
        retestOffset: retestOffset,
        return12: m5[i + 12].close - breakout.close,
        return24: m5[i + 24].close - breakout.close,
        return48: m5[i + 48].close - breakout.close,
      ),
    );
  }

  final rows = const StrategyDRetestDiagnostics().summarize(samples);

  stdout.writeln(
    'TradeForge V2 — Increment 125 Strategy D Breakout Retest Discovery',
  );
  stdout.writeln('M15 structural proxy: prior $_m15Lookback closed M15 bars');
  stdout.writeln('Retest observation window: $_retestHorizon M5 bars');
  stdout.writeln('Fresh structural breakout samples: ${samples.length}');
  stdout.writeln(
    'Discovery only: continuation percentages are not trade win rates.',
  );

  for (final row in rows) {
    stdout.writeln(
      '${row.label}: n=${row.samples} '
      '12M5=${_pct(row.continuation12)} '
      '24M5=${_pct(row.continuation24)} '
      '48M5=${_pct(row.continuation48)}',
    );
  }
}

String _pct(double value) => '${(value * 100).toStringAsFixed(2)}%';
