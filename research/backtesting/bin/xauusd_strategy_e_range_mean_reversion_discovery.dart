import 'dart:io';

import 'package:technical_analysis/technical_analysis.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/diagnostics/strategy_e_range_mean_reversion_diagnostics.dart';

const _m15Lookback = 20;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run '
      'bin/xauusd_strategy_e_range_mean_reversion_discovery.dart '
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
  final samples = <RangeReversionSample>[];
  var m15Index = _m15Lookback - 1;

  for (var i = 14; i + 48 < m5.length; i++) {
    final observation = m5[i];

    while (m15Index + 1 < m15.length &&
        !m15[m15Index + 1].closeTime.isAfter(observation.closeTime)) {
      m15Index++;
    }
    if (m15Index < _m15Lookback - 1) continue;

    final first = m15Index - (_m15Lookback - 1);
    var high = double.negativeInfinity;
    var low = double.infinity;
    for (var j = first; j <= m15Index; j++) {
      if (m15[j].high > high) high = m15[j].high;
      if (m15[j].low < low) low = m15[j].low;
    }

    final width = high - low;
    if (!width.isFinite || width <= 0) continue;

    final position = (observation.close - low) / width;
    if (position < 0 || position > 1) continue;

    RangeReversionSide? side;
    if (position <= .20) {
      side = RangeReversionSide.lowerExtreme;
    } else if (position >= .80) {
      side = RangeReversionSide.upperExtreme;
    } else {
      continue;
    }

    final atr = atrCalculator.calculate(
      candles: m5.sublist(i - 14, i + 1),
      period: 14,
    );
    if (!atr.isFinite || atr <= 0) continue;

    samples.add(
      RangeReversionSample(
        time: observation.closeTime,
        side: side,
        rangePosition: position,
        rangeWidthAtr: width / atr,
        return12: m5[i + 12].close - observation.close,
        return24: m5[i + 24].close - observation.close,
        return48: m5[i + 48].close - observation.close,
      ),
    );
  }

  final rows = const StrategyERangeMeanReversionDiagnostics().summarize(
    samples,
  );

  stdout.writeln(
    'TradeForge V2 — Increment 127 Strategy E Range Mean-Reversion Discovery',
  );
  stdout.writeln('M15 range proxy: prior $_m15Lookback closed M15 bars');
  stdout.writeln('Extreme observations: ${samples.length}');
  stdout.writeln(
    'Discovery only: reversion percentages are not trade win rates.',
  );
  for (final row in rows) {
    stdout.writeln(
      '${row.label}: n=${row.samples} '
      '12M5=${_pct(row.reversion12)} '
      '24M5=${_pct(row.reversion24)} '
      '48M5=${_pct(row.reversion48)}',
    );
  }
}

String _pct(double value) => '${(value * 100).toStringAsFixed(2)}%';
