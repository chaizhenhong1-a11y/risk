import 'dart:io';

import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/diagnostics/strategy_f_liquidity_sweep_reversal_diagnostics.dart';

const _m15Lookback = 20;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run '
      'bin/xauusd_strategy_f_liquidity_sweep_reversal_discovery.dart '
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

  final samples = <LiquiditySweepReversalSample>[];
  var m15Index = _m15Lookback;

  for (var i = 1; i + 48 < m5.length; i++) {
    final observation = m5[i];

    // Structural proxy is intentionally formed only from M15 candles whose
    // close is strictly before the observation. This avoids allowing the
    // current breakout/sweep candle to define the level it is testing.
    while (m15Index + 1 < m15.length &&
        m15[m15Index + 1].closeTime.isBefore(observation.closeTime)) {
      m15Index++;
    }
    if (m15Index < _m15Lookback - 1) continue;

    final first = m15Index - (_m15Lookback - 1);
    var resistance = double.negativeInfinity;
    var support = double.infinity;
    for (var j = first; j <= m15Index; j++) {
      if (!m15[j].closeTime.isBefore(observation.closeTime)) continue;
      if (m15[j].high > resistance) resistance = m15[j].high;
      if (m15[j].low < support) support = m15[j].low;
    }
    if (!resistance.isFinite || !support.isFinite) continue;

    final previous = m5[i - 1];

    // Fresh sweep only: previous M5 must still be on the unswept side.
    final supportSweep = previous.low >= support && observation.low < support;
    final resistanceSweep =
        previous.high <= resistance && observation.high > resistance;

    // A candle sweeping both sides is ambiguous and excluded from discovery.
    if (supportSweep == resistanceSweep) continue;

    if (supportSweep) {
      samples.add(
        LiquiditySweepReversalSample(
          time: observation.closeTime,
          side: LiquiditySweepSide.support,
          reclaimed: observation.close > support,
          return12: m5[i + 12].close - observation.close,
          return24: m5[i + 24].close - observation.close,
          return48: m5[i + 48].close - observation.close,
        ),
      );
    } else {
      samples.add(
        LiquiditySweepReversalSample(
          time: observation.closeTime,
          side: LiquiditySweepSide.resistance,
          reclaimed: observation.close < resistance,
          return12: m5[i + 12].close - observation.close,
          return24: m5[i + 24].close - observation.close,
          return48: m5[i + 48].close - observation.close,
        ),
      );
    }
  }

  final rows = const StrategyFLiquiditySweepReversalDiagnostics().summarize(
    samples,
  );

  stdout.writeln(
    'TradeForge V2 — Increment 128 Strategy F Liquidity Sweep Reversal Discovery',
  );
  stdout.writeln(
    'Structural proxy: prior $_m15Lookback M15 candles closed strictly before observation',
  );
  stdout.writeln('Fresh one-sided sweep observations: ${samples.length}');
  stdout.writeln(
    'Discovery only: reversal percentages are not trade win rates.',
  );

  for (final row in rows) {
    stdout.writeln(
      '${row.label}: n=${row.samples} '
      '12M5=${_pct(row.reversal12)} '
      '24M5=${_pct(row.reversal24)} '
      '48M5=${_pct(row.reversal48)}',
    );
  }
}

String _pct(double value) => '${(value * 100).toStringAsFixed(2)}%';
