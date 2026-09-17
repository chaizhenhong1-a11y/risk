import 'dart:io';

import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/diagnostics/strategy_d_no_retest_confirmation_validation.dart';

const _m15Lookback = 20;
const _confirmationBars = 12;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run '
      'bin/xauusd_strategy_d_no_retest_confirmation_validation.dart '
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

  final samples = <NoRetestConfirmationSample>[];
  var m15Index = _m15Lookback - 1;
  var lastAcceptedConfirmationIndex = -1;

  // 12 closed bars are required for confirmation, then 48 future bars for
  // validation. Nothing after the confirmation close is used to qualify it.
  for (var i = 1; i + _confirmationBars + 48 < m5.length; i++) {
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
    NoRetestDirection? direction;
    double level = 0;

    if (previousClose <= resistance && breakout.close > resistance) {
      direction = NoRetestDirection.bullish;
      level = resistance;
    } else if (previousClose >= support && breakout.close < support) {
      direction = NoRetestDirection.bearish;
      level = support;
    }
    if (direction == null) continue;

    var retested = false;
    for (var offset = 1; offset <= _confirmationBars; offset++) {
      final candle = m5[i + offset];
      final touches = switch (direction) {
        NoRetestDirection.bullish => candle.low <= level,
        NoRetestDirection.bearish => candle.high >= level,
      };
      if (touches) {
        retested = true;
        break;
      }
    }
    if (retested) continue;

    final confirmationIndex = i + _confirmationBars;

    // Deduplicate confirmations that resolve to the same/earlier observation.
    if (confirmationIndex <= lastAcceptedConfirmationIndex) continue;
    lastAcceptedConfirmationIndex = confirmationIndex;

    final confirmation = m5[confirmationIndex];
    samples.add(
      NoRetestConfirmationSample(
        breakoutTime: breakout.closeTime,
        confirmationTime: confirmation.closeTime,
        direction: direction,
        return12: m5[confirmationIndex + 12].close - confirmation.close,
        return24: m5[confirmationIndex + 24].close - confirmation.close,
        return48: m5[confirmationIndex + 48].close - confirmation.close,
      ),
    );
  }

  final result = const StrategyDNoRetestConfirmationValidation().summarize(
    samples,
  );

  stdout.writeln(
    'TradeForge V2 — Increment 126 Strategy D No-Retest Confirmation Validation',
  );
  stdout.writeln('M15 structural proxy: prior $_m15Lookback closed M15 bars');
  stdout.writeln(
    'Signal observable after $_confirmationBars closed M5 bars without retest.',
  );
  stdout.writeln('Confirmed no-retest samples: ${result.samples}');
  stdout.writeln(
    'Forward outcomes start from confirmation close (no look-ahead entry).',
  );
  stdout.writeln(
    '12M5=${_pct(result.continuation12)} '
    '24M5=${_pct(result.continuation24)} '
    '48M5=${_pct(result.continuation48)}',
  );
  stdout.writeln(
    'Research only: directional continuation is not trade win rate.',
  );
}

String _pct(double value) => '${(value * 100).toStringAsFixed(2)}%';
