import 'dart:io';

import 'package:technical_analysis/technical_analysis.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/diagnostics/strategy_d_structural_breakout_diagnostics.dart';

const _m15Lookback = 20;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_strategy_d_structural_breakout_discovery.dart '
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

  const atrCalculator = AverageTrueRange();
  final samples = <StructuralBreakoutSample>[];
  var m15Index = _m15Lookback - 1;

  for (var i = 14; i + 48 < m5.length; i++) {
    final candle = m5[i];

    // Only M15 candles closed no later than this M5 observation are visible.
    while (m15Index + 1 < m15.length &&
        !m15[m15Index + 1].closeTime.isAfter(candle.closeTime)) {
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

    final atr = atrCalculator.calculate(
      candles: m5.sublist(i - 14, i + 1),
      period: 14,
    );
    if (!atr.isFinite || atr <= 0) continue;

    final previousClose = i > 0 ? m5[i - 1].close : candle.open;
    StructuralBreakoutDirection? direction;
    double breakDistance = 0;

    // Require a fresh close-through, not repeated observations already beyond
    // the level. The M15 range is a frozen research proxy for structure.
    if (previousClose <= resistance && candle.close > resistance) {
      direction = StructuralBreakoutDirection.bullish;
      breakDistance = candle.close - resistance;
    } else if (previousClose >= support && candle.close < support) {
      direction = StructuralBreakoutDirection.bearish;
      breakDistance = support - candle.close;
    }
    if (direction == null) continue;

    samples.add(
      StructuralBreakoutSample(
        time: candle.closeTime,
        direction: direction,
        breakDistanceAtr: breakDistance / atr,
        rangeAtr: (candle.high - candle.low) / atr,
        bodyAtr: (candle.close - candle.open).abs() / atr,
        return12: m5[i + 12].close - candle.close,
        return24: m5[i + 24].close - candle.close,
        return48: m5[i + 48].close - candle.close,
      ),
    );
  }

  final rows = const StrategyDStructuralBreakoutDiagnostics().summarize(
    samples,
  );

  stdout.writeln(
    'TradeForge V2 — Increment 124 Strategy D Structural Breakout Discovery',
  );
  stdout.writeln('M15 structural proxy: prior $_m15Lookback closed M15 bars');
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
