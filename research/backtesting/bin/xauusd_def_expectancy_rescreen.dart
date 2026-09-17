import 'dart:io';

import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/diagnostics/def_expectancy_rescreen_diagnostics.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_expectancy_validator.dart';

const _rrs = <double>[1.5, 2.0, 2.5, 3.0];
const _expiry = 48;
const _m15Lookback = 20;
const _m5StopLookback = 12;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_def_expectancy_rescreen.dart '
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

  final samples = <DefStrategy, List<DefSetupSample>>{
    for (final strategy in DefStrategy.values) strategy: [],
  };

  var m15Cursor = 0;
  var lastDState = false;
  var lastEState = false;
  var lastFState = false;

  for (var i = _m5StopLookback; i < m5.length - _expiry; i++) {
    final candle = m5[i];

    while (m15Cursor + 1 < m15.length &&
        !m15[m15Cursor + 1].closeTime.isAfter(candle.closeTime)) {
      m15Cursor++;
    }
    if (m15Cursor < _m15Lookback) continue;

    final priorM15 = m15.sublist(m15Cursor - _m15Lookback, m15Cursor);
    final resistance = priorM15
        .map((c) => c.high)
        .reduce((a, b) => a > b ? a : b);
    final support = priorM15.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    final width = resistance - support;
    if (width <= 0) continue;

    // D: fresh close-through of the prior M15 rolling boundary.
    final dBuy = candle.close > resistance;
    final dSell = candle.close < support;
    final dState = dBuy || dSell;
    if (dState && !lastDState) {
      final isBuy = dBuy;
      final stop = _priorExtreme(m5, i, isBuy);
      if (_validGeometry(isBuy, candle.close, stop)) {
        samples[DefStrategy.dBreakout]!.add(
          DefSetupSample(
            strategy: DefStrategy.dBreakout,
            observedAt: candle.closeTime,
            isBuy: isBuy,
            entry: candle.close,
            stop: stop,
          ),
        );
      }
    }
    lastDState = dState;

    // E: outer 15% of prior M15 range, trading back toward the range.
    final position = (candle.close - support) / width;
    final eBuy = position <= .15;
    final eSell = position >= .85;
    final eState = eBuy || eSell;
    if (eState && !lastEState) {
      final isBuy = eBuy;
      final stop = _priorExtreme(m5, i, isBuy);
      if (_validGeometry(isBuy, candle.close, stop)) {
        samples[DefStrategy.eRangeMeanReversion]!.add(
          DefSetupSample(
            strategy: DefStrategy.eRangeMeanReversion,
            observedAt: candle.closeTime,
            isBuy: isBuy,
            entry: candle.close,
            stop: stop,
          ),
        );
      }
    }
    lastEState = eState;

    // F: one-sided sweep of prior M15 boundary with same-bar reclaim.
    final supportSweep = candle.low < support && candle.close > support;
    final resistanceSweep =
        candle.high > resistance && candle.close < resistance;
    final fState = supportSweep != resistanceSweep;
    if (fState && !lastFState) {
      final isBuy = supportSweep;
      final stop = isBuy ? candle.low : candle.high;
      if (_validGeometry(isBuy, candle.close, stop)) {
        samples[DefStrategy.fLiquiditySweep]!.add(
          DefSetupSample(
            strategy: DefStrategy.fLiquiditySweep,
            observedAt: candle.closeTime,
            isBuy: isBuy,
            entry: candle.close,
            stop: stop,
          ),
        );
      }
    }
    lastFState = fState;
  }

  final m5Index = <DateTime, int>{
    for (var i = 0; i < m5.length; i++) m5[i].closeTime.toUtc(): i,
  };

  stdout.writeln('');
  stdout.writeln('TradeForge V2 — Increment 136 D/E/F Expectancy Re-screen');
  stdout.writeln(
    'Research-only deterministic proxies; no threshold tuning is performed.',
  );
  stdout.writeln(
    'D=fresh prior-M15-range close breakout; '
    'E=outer-15% range mean reversion; '
    'F=one-sided boundary sweep + same-bar reclaim.',
  );

  for (final strategy in DefStrategy.values) {
    final strategySamples = samples[strategy]!;
    stdout.writeln('');
    stdout.writeln('${strategy.name}: setups=${strategySamples.length}');

    for (final rr in _rrs) {
      final trades = <StrategyTradeResult>[];

      for (final sample in strategySamples) {
        final start = m5Index[sample.observedAt.toUtc()];
        if (start == null || sample.risk <= 0) continue;
        final target = sample.isBuy
            ? sample.entry + sample.risk * rr
            : sample.entry - sample.risk * rr;

        var resolution = TradeResolution.expired;
        for (var j = start + 1; j <= start + _expiry && j < m5.length; j++) {
          final bar = m5[j];
          final hitStop = sample.isBuy
              ? bar.low <= sample.stop
              : bar.high >= sample.stop;
          final hitTarget = sample.isBuy
              ? bar.high >= target
              : bar.low <= target;

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

  stdout.writeln('');
  stdout.writeln(
    'A positive proxy result only earns stricter strategy-specific validation; '
    'it does not restore D/E/F to production.',
  );
}

double _priorExtreme(List<dynamic> candles, int index, bool isBuy) {
  var value = isBuy ? double.infinity : double.negativeInfinity;
  for (var j = index - _m5StopLookback; j < index; j++) {
    final candle = candles[j];
    if (isBuy) {
      if (candle.low < value) value = candle.low;
    } else {
      if (candle.high > value) value = candle.high;
    }
  }
  return value;
}

bool _validGeometry(bool isBuy, double entry, double stop) =>
    isBuy ? stop < entry : stop > entry;

String _pct(double value) => '${(value * 100).toStringAsFixed(2)}%';

String _pf(double value) => value.isInfinite ? 'inf' : value.toStringAsFixed(3);
