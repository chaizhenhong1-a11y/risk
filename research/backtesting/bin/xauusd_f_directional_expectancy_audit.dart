import 'dart:io';

import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_expectancy_validator.dart';

const _riskRewards = <double>[1.5, 2.0, 2.5, 3.0];
const _expiryBars = 48;
const _m15Lookback = 20;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_f_directional_expectancy_audit.dart '
      '<history-directory>',
    );
    exitCode = 64;
    return;
  }

  const adapter = Mt5HistoryAdapter();
  final m5File = File(
    '${args.first}${Platform.pathSeparator}XAUUSD_M5_2024_2026.csv',
  );
  final m15File = File(
    '${args.first}${Platform.pathSeparator}XAUUSD_M15_2024_2026.csv',
  );
  if (!m5File.existsSync() || !m15File.existsSync()) {
    stderr.writeln('Missing XAUUSD M5 or M15 history.');
    exitCode = 66;
    return;
  }

  final m5 = adapter
      .parse(content: m5File.readAsStringSync(), timeframe: MarketTimeframe.m5)
      .candles;
  final m15 = adapter
      .parse(
        content: m15File.readAsStringSync(),
        timeframe: MarketTimeframe.m15,
      )
      .candles;

  final buySamples = <_SweepSample>[];
  final sellSamples = <_SweepSample>[];

  var m15Cursor = 0;
  var wasBuySweep = false;
  var wasSellSweep = false;

  for (var i = 0; i < m5.length - _expiryBars; i++) {
    final candle = m5[i];

    while (m15Cursor + 1 < m15.length &&
        !m15[m15Cursor + 1].closeTime.isAfter(candle.closeTime)) {
      m15Cursor++;
    }
    if (m15Cursor < _m15Lookback) continue;

    // Strictly prior M15 candles only. This avoids letting the current M15
    // candle define the boundary it is supposedly sweeping.
    final priorM15 = m15.sublist(m15Cursor - _m15Lookback, m15Cursor);
    final resistance = priorM15
        .map((c) => c.high)
        .reduce((a, b) => a > b ? a : b);
    final support = priorM15.map((c) => c.low).reduce((a, b) => a < b ? a : b);

    final buySweep = candle.low < support && candle.close > support;
    final sellSweep = candle.high > resistance && candle.close < resistance;

    final oneSidedBuy = buySweep && !sellSweep;
    final oneSidedSell = sellSweep && !buySweep;

    if (oneSidedBuy && !wasBuySweep) {
      final risk = candle.close - candle.low;
      if (risk > 0 && risk.isFinite) {
        buySamples.add(
          _SweepSample(
            observedAt: candle.closeTime.toUtc(),
            index: i,
            isBuy: true,
            entry: candle.close,
            stop: candle.low,
            risk: risk,
          ),
        );
      }
    }

    if (oneSidedSell && !wasSellSweep) {
      final risk = candle.high - candle.close;
      if (risk > 0 && risk.isFinite) {
        sellSamples.add(
          _SweepSample(
            observedAt: candle.closeTime.toUtc(),
            index: i,
            isBuy: false,
            entry: candle.close,
            stop: candle.high,
            risk: risk,
          ),
        );
      }
    }

    wasBuySweep = oneSidedBuy;
    wasSellSweep = oneSidedSell;
  }

  stdout.writeln('');
  stdout.writeln(
    'TradeForge V2 — Increment 137 F Directional Expectancy Audit',
  );
  stdout.writeln(
    'BUY = support sweep + same-bar reclaim; '
    'SELL = resistance sweep + same-bar reclaim.',
  );
  stdout.writeln(
    'Entry = reclaim candle close; SL = sweep candle extreme; expiry = 48 M5.',
  );
  stdout.writeln(
    'No RR/lookback/threshold tuning. This audit only separates F by direction.',
  );

  _printSide('F BUY support-sweep reclaim', buySamples, m5);
  _printSide('F SELL resistance-sweep reclaim', sellSamples, m5);

  stdout.writeln('');
  stdout.writeln(
    'Research only. A positive side must still survive costs and independent '
    'validation before F can return to the production candidate pool.',
  );
}

void _printSide(
  String label,
  List<_SweepSample> samples,
  List<dynamic> candles,
) {
  stdout.writeln('');
  stdout.writeln('$label: setups=${samples.length}');

  for (final rr in _riskRewards) {
    final trades = <StrategyTradeResult>[];

    for (final sample in samples) {
      final target = sample.isBuy
          ? sample.entry + sample.risk * rr
          : sample.entry - sample.risk * rr;
      var resolution = TradeResolution.expired;

      for (
        var j = sample.index + 1;
        j <= sample.index + _expiryBars && j < candles.length;
        j++
      ) {
        final bar = candles[j];
        final hitStop = sample.isBuy
            ? bar.low <= sample.stop
            : bar.high >= sample.stop;
        final hitTarget = sample.isBuy ? bar.high >= target : bar.low <= target;

        if (hitStop && hitTarget) {
          resolution = TradeResolution.ambiguous;
          break;
        }
        if (hitStop) {
          resolution = TradeResolution.loss;
          break;
        }
        if (hitTarget) {
          resolution = TradeResolution.win;
          break;
        }
      }

      trades.add(
        StrategyTradeResult(
          observedAt: sample.observedAt,
          resolution: resolution,
          rewardRisk: rr,
        ),
      );
    }

    final report = const StrategyExpectancyValidator().evaluate(trades);
    stdout.writeln(
      '  RR ${rr.toStringAsFixed(1)}: '
      'resolved=${report.resolved}/${report.total} '
      'W=${report.wins} L=${report.losses} '
      'exp=${report.expired} amb=${report.ambiguous} '
      'win=${_pct(report.winRate)} '
      'E=${report.grossExpectancyR.toStringAsFixed(3)}R '
      'PF=${_pf(report.profitFactor)} '
      'streak=${report.maxLosingStreak} '
      'first=${report.firstHalfNetExpectancyR.toStringAsFixed(3)}R '
      'second=${report.secondHalfNetExpectancyR.toStringAsFixed(3)}R',
    );
  }
}

String _pct(double value) => '${(value * 100).toStringAsFixed(2)}%';

String _pf(double value) => value.isInfinite ? 'inf' : value.toStringAsFixed(3);

final class _SweepSample {
  const _SweepSample({
    required this.observedAt,
    required this.index,
    required this.isBuy,
    required this.entry,
    required this.stop,
    required this.risk,
  });

  final DateTime observedAt;
  final int index;
  final bool isBuy;
  final double entry;
  final double stop;
  final double risk;
}
