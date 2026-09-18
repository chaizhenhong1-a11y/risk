import 'package:market_models/market_models.dart';

import '../validation/strategy_expectancy_validator.dart';
import 'strategy_registry.dart';

enum ResearchSide { buy, sell }

final class ResearchCandidate {
  const ResearchCandidate({
    required this.strategyId,
    required this.observedAt,
    required this.candleIndex,
    required this.side,
    required this.entry,
    required this.stop,
    required this.target,
    required this.regime,
  });
  final String strategyId;
  final DateTime observedAt;
  final int candleIndex;
  final ResearchSide side;
  final double entry;
  final double stop;
  final double target;
  final String regime;
  double get rewardRisk => (target - entry).abs() / (entry - stop).abs();
}

final class StrategyResearchCase {
  const StrategyResearchCase({required this.candidate, required this.trade});

  final ResearchCandidate candidate;
  final StrategyTradeResult trade;
}

final class StrategyBatchResult {
  const StrategyBatchResult({
    required this.strategy,
    required this.candidates,
    required this.cases,
    required this.trades,
    required this.report,
  });
  final StrategyDefinition strategy;
  final int candidates;
  final List<StrategyResearchCase> cases;
  final List<StrategyTradeResult> trades;
  final StrategyExpectancyReport report;

  bool get historicalGate =>
      report.resolved >= 30 &&
      report.netExpectancyR > 0 &&
      report.profitFactor > 1 &&
      report.firstHalfNetExpectancyR > 0 &&
      report.secondHalfNetExpectancyR > 0;
}

/// Research-only batch screen for the mainstream Strategy Library.
///
/// These definitions deliberately emit candidates, never production signals.
/// Every candidate uses the same deterministic 1 ATR stop / 2R target and a
/// 48-M5-bar lifecycle so cross-strategy comparisons use one baseline.
final class MainstreamStrategyBatch {
  const MainstreamStrategyBatch({this.expiryBars = 48, this.rewardRisk = 2});
  final int expiryBars;
  final double rewardRisk;

  List<ResearchCandidate> discoverAtClose(
    List<Candle> candles, {
    StrategyRegistry registry = const StrategyRegistry(),
  }) {
    if (candles.length < 60) {
      return const <ResearchCandidate>[];
    }

    final i = candles.length - 1;
    final history = candles.sublist(i - 59, i + 1);
    final atr = _atr(history, 14);
    if (atr == null || atr <= 0) {
      return const <ResearchCandidate>[];
    }

    final regime = _regime(history, atr);
    final signals = _signals(history, atr, regime);
    final out = <ResearchCandidate>[];

    for (final strategy in registry.research) {
      final side = signals[strategy.id];
      if (side == null) {
        continue;
      }

      final entry = history.last.close;
      final stop = side == ResearchSide.buy ? entry - atr : entry + atr;
      final target = side == ResearchSide.buy
          ? entry + atr * rewardRisk
          : entry - atr * rewardRisk;

      out.add(
        ResearchCandidate(
          strategyId: strategy.id,
          observedAt: history.last.closeTime,
          candleIndex: i,
          side: side,
          entry: entry,
          stop: stop,
          target: target,
          regime: regime,
        ),
      );
    }

    return out;
  }

  List<StrategyBatchResult> run(
    List<Candle> candles, {
    StrategyRegistry registry = const StrategyRegistry(),
  }) {
    final candidates = <String, List<ResearchCandidate>>{
      for (final s in registry.research) s.id: <ResearchCandidate>[],
    };
    for (var i = 60; i < candles.length; i++) {
      final history = candles.sublist(i - 59, i + 1);
      final atr = _atr(history, 14);
      if (atr == null || atr <= 0) {
        continue;
      }
      final regime = _regime(history, atr);
      final signals = _signals(history, atr, regime);
      for (final strategy in registry.research) {
        final side = signals[strategy.id];
        if (side == null) {
          continue;
        }
        final entry = history.last.close;
        final stop = side == ResearchSide.buy ? entry - atr : entry + atr;
        final target = side == ResearchSide.buy
            ? entry + atr * rewardRisk
            : entry - atr * rewardRisk;
        candidates[strategy.id]!.add(
          ResearchCandidate(
            strategyId: strategy.id,
            observedAt: history.last.closeTime,
            candleIndex: i,
            side: side,
            entry: entry,
            stop: stop,
            target: target,
            regime: regime,
          ),
        );
      }
    }

    return registry.research
        .map((strategy) {
          final raw = _dedupeEpisodes(candidates[strategy.id]!);
          final cases = raw
              .map(
                (candidate) => StrategyResearchCase(
                  candidate: candidate,
                  trade: _resolve(candidate, candles),
                ),
              )
              .toList(growable: false);
          final trades = cases
              .map((item) => item.trade)
              .toList(growable: false);
          return StrategyBatchResult(
            strategy: strategy,
            candidates: raw.length,
            cases: cases,
            trades: trades,
            report: const StrategyExpectancyValidator().evaluate(trades),
          );
        })
        .toList(growable: false);
  }

  List<ResearchCandidate> _dedupeEpisodes(List<ResearchCandidate> input) {
    final out = <ResearchCandidate>[];
    ResearchCandidate? previous;
    for (final candidate in input) {
      if (previous != null &&
          candidate.side == previous.side &&
          candidate.observedAt.difference(previous.observedAt).inMinutes <=
              15) {
        continue;
      }
      out.add(candidate);
      previous = candidate;
    }
    return out;
  }

  StrategyTradeResult _resolve(ResearchCandidate c, List<Candle> candles) {
    final start = c.candleIndex;
    if (start < 0 || start >= candles.length) {
      return StrategyTradeResult(
        observedAt: c.observedAt,
        resolution: TradeResolution.expired,
        rewardRisk: rewardRisk,
      );
    }
    final end = (start + expiryBars).clamp(start, candles.length - 1);
    for (var i = start + 1; i <= end; i++) {
      final bar = candles[i];
      final stopHit = c.side == ResearchSide.buy
          ? bar.low <= c.stop
          : bar.high >= c.stop;
      final targetHit = c.side == ResearchSide.buy
          ? bar.high >= c.target
          : bar.low <= c.target;
      if (stopHit && targetHit) {
        return StrategyTradeResult(
          observedAt: c.observedAt,
          resolution: TradeResolution.ambiguous,
          rewardRisk: rewardRisk,
        );
      }
      if (stopHit) {
        return StrategyTradeResult(
          observedAt: c.observedAt,
          resolution: TradeResolution.loss,
          rewardRisk: rewardRisk,
        );
      }
      if (targetHit) {
        return StrategyTradeResult(
          observedAt: c.observedAt,
          resolution: TradeResolution.win,
          rewardRisk: rewardRisk,
        );
      }
    }
    return StrategyTradeResult(
      observedAt: c.observedAt,
      resolution: TradeResolution.expired,
      rewardRisk: rewardRisk,
    );
  }

  Map<String, ResearchSide> _signals(
    List<Candle> h,
    double atr,
    String regime,
  ) {
    final out = <String, ResearchSide>{};
    final close = h.last.close;
    final ema9 = _ema(h, 9)!;
    final ema20 = _ema(h, 20)!;
    final ema50 = _ema(h, 50)!;
    final prev = h.sublist(0, h.length - 1);
    final pEma9 = _ema(prev, 9)!;
    final pEma20 = _ema(prev, 20)!;
    final rsi = _rsi(h, 14)!;
    final pRsi = _rsi(prev, 14)!;
    final macd = _ema(h, 12)! - _ema(h, 26)!;
    final macdPrev = _ema(prev, 12)! - _ema(prev, 26)!;
    final signal = _emaValues(_macdSeries(h), 9);
    final bb = _bands(h, 20, 2);
    final hi20 = h
        .sublist(h.length - 21, h.length - 1)
        .map((e) => e.high)
        .reduce(_max);
    final lo20 = h
        .sublist(h.length - 21, h.length - 1)
        .map((e) => e.low)
        .reduce(_min);
    final body = (h.last.close - h.last.open).abs();
    final bullish = h.last.close > h.last.open;
    final bearish = h.last.close < h.last.open;
    final last = h.last;
    final p1 = h[h.length - 2];
    final p2 = h[h.length - 3];
    final emaDistance = (close - ema20).abs();
    final priorBody = (p1.close - p1.open).abs();
    final priorBullish = p1.close > p1.open;
    final priorBearish = p1.close < p1.open;
    final priorRange = p1.high - p1.low;
    final olderRange = p2.high - p2.low;
    final insideBar = p1.high < p2.high && p1.low > p2.low;
    final recent10 = h.sublist(h.length - 11, h.length - 1);
    final hi10 = recent10.map((e) => e.high).reduce(_max);
    final lo10 = recent10.map((e) => e.low).reduce(_min);
    final beforeP1 = h.sublist(0, h.length - 2);
    final preP1Recent20 = beforeP1.sublist(beforeP1.length - 20);
    final preP1Hi20 = preP1Recent20.map((e) => e.high).reduce(_max);
    final preP1Lo20 = preP1Recent20.map((e) => e.low).reduce(_min);
    final preP1Recent10 = beforeP1.sublist(beforeP1.length - 10);
    final preP1Hi10 = preP1Recent10.map((e) => e.high).reduce(_max);
    final preP1Lo10 = preP1Recent10.map((e) => e.low).reduce(_min);
    final upperWick = last.high - _max(last.open, last.close);
    final lowerWick = _min(last.open, last.close) - last.low;
    final p1BodyHigh = _max(p1.open, p1.close);
    final p1BodyLow = _min(p1.open, p1.close);
    final bodyHigh = _max(last.open, last.close);
    final bodyLow = _min(last.open, last.close);
    final prior7 = h.sublist(h.length - 8, h.length - 1);
    final p1IsNr7 =
        priorRange <= prior7.map((e) => e.high - e.low).reduce(_min);
    final p3 = h[h.length - 4];

    ResearchSide? evaluate(String id) {
      switch (id) {
        case 'EMA_TREND':
          if (ema9 > ema20 && ema20 > ema50 && close > ema20) {
            return ResearchSide.buy;
          }
          if (ema9 < ema20 && ema20 < ema50 && close < ema20) {
            return ResearchSide.sell;
          }
        case 'EMA_CROSS':
          if (pEma9 <= pEma20 && ema9 > ema20) {
            return ResearchSide.buy;
          }
          if (pEma9 >= pEma20 && ema9 < ema20) {
            return ResearchSide.sell;
          }
        case 'MACD_TREND':
          if (macd > 0 && macd > signal && ema20 > ema50) {
            return ResearchSide.buy;
          }
          if (macd < 0 && macd < signal && ema20 < ema50) {
            return ResearchSide.sell;
          }
        case 'MACD_MOMENTUM':
          if (macd > signal && macd > macdPrev && body > atr * .8) {
            return ResearchSide.buy;
          }
          if (macd < signal && macd < macdPrev && body > atr * .8) {
            return ResearchSide.sell;
          }
        case 'RSI_MOMENTUM':
          if (rsi > 55 && rsi < 75 && rsi > pRsi) {
            return ResearchSide.buy;
          }
          if (rsi < 45 && rsi > 25 && rsi < pRsi) {
            return ResearchSide.sell;
          }
        case 'RSI_REVERSAL':
          if (pRsi < 30 && rsi >= 30 && bullish) {
            return ResearchSide.buy;
          }
          if (pRsi > 70 && rsi <= 70 && bearish) {
            return ResearchSide.sell;
          }
        case 'BB_RANGE':
          if (regime == 'range' && h.last.low <= bb.$1 && bullish) {
            return ResearchSide.buy;
          }
          if (regime == 'range' && h.last.high >= bb.$3 && bearish) {
            return ResearchSide.sell;
          }
        case 'BB_SQUEEZE':
          final width = (bb.$3 - bb.$1) / bb.$2;
          if (width < .004 && close > hi20) {
            return ResearchSide.buy;
          }
          if (width < .004 && close < lo20) {
            return ResearchSide.sell;
          }
        case 'ADX_TREND':
          final strength = (ema9 - ema50).abs() / atr;
          if (strength > 1.5 && ema9 > ema50 && bullish) {
            return ResearchSide.buy;
          }
          if (strength > 1.5 && ema9 < ema50 && bearish) {
            return ResearchSide.sell;
          }
        case 'DONCHIAN_BREAKOUT':
          if (close > hi20) {
            return ResearchSide.buy;
          }
          if (close < lo20) {
            return ResearchSide.sell;
          }
        case 'SR_BREAKOUT':
          if (close > hi20 && body > atr) {
            return ResearchSide.buy;
          }
          if (close < lo20 && body > atr) {
            return ResearchSide.sell;
          }
        case 'BREAKOUT_RETEST':
          final pHi = prev
              .sublist(prev.length - 21, prev.length - 1)
              .map((e) => e.high)
              .reduce(_max);
          final pLo = prev
              .sublist(prev.length - 21, prev.length - 1)
              .map((e) => e.low)
              .reduce(_min);
          if (prev.last.close > pHi && h.last.low <= pHi && close > pHi) {
            return ResearchSide.buy;
          }
          if (prev.last.close < pLo && h.last.high >= pLo && close < pLo) {
            return ResearchSide.sell;
          }
        case 'TREND_PULLBACK':
          if (ema20 > ema50 &&
              h.last.low <= ema20 &&
              close > ema20 &&
              bullish) {
            return ResearchSide.buy;
          }
          if (ema20 < ema50 &&
              h.last.high >= ema20 &&
              close < ema20 &&
              bearish) {
            return ResearchSide.sell;
          }
        case 'MOMENTUM_CONT':
          if (body > atr * 1.2 && bullish && close > hi20) {
            return ResearchSide.buy;
          }
          if (body > atr * 1.2 && bearish && close < lo20) {
            return ResearchSide.sell;
          }
        case 'ATR_EXPANSION':
          if (body > atr * 1.5 && bullish) {
            return ResearchSide.buy;
          }
          if (body > atr * 1.5 && bearish) {
            return ResearchSide.sell;
          }
        case 'LIQ_SWEEP':
          if (h.last.low < lo20 && close > lo20 && bullish) {
            return ResearchSide.buy;
          }
          if (h.last.high > hi20 && close < hi20 && bearish) {
            return ResearchSide.sell;
          }
        case 'CHOCH_BOS':
          if (close > hi20 && ema9 > ema20) {
            return ResearchSide.buy;
          }
          if (close < lo20 && ema9 < ema20) {
            return ResearchSide.sell;
          }
        case 'FAILED_BREAKOUT':
          if (p1.high > hi20 && p1.close < hi20 && bearish && close < p1.low) {
            return ResearchSide.sell;
          }
          if (p1.low < lo20 && p1.close > lo20 && bullish && close > p1.high) {
            return ResearchSide.buy;
          }
        case 'VOL_COMPRESSION_BREAK':
          final compressed = priorRange < atr * .65 && olderRange < atr * .85;
          if (compressed && bullish && body > atr && close > p2.high) {
            return ResearchSide.buy;
          }
          if (compressed && bearish && body > atr && close < p2.low) {
            return ResearchSide.sell;
          }
        case 'SR_RECLAIM':
          if (p1.close < lo10 && close > lo10 && bullish) {
            return ResearchSide.buy;
          }
          if (p1.close > hi10 && close < hi10 && bearish) {
            return ResearchSide.sell;
          }
        case 'IMPULSE_PULLBACK':
          if (priorBullish &&
              priorBody > atr * 1.2 &&
              last.low <= p1.close - priorBody * .5 &&
              close > p1.open &&
              bullish) {
            return ResearchSide.buy;
          }
          if (priorBearish &&
              priorBody > atr * 1.2 &&
              last.high >= p1.close + priorBody * .5 &&
              close < p1.open &&
              bearish) {
            return ResearchSide.sell;
          }
        case 'SWEEP_STRUCTURE':
          if (last.low < lo20 && close > lo20 && close > p1.high) {
            return ResearchSide.buy;
          }
          if (last.high > hi20 && close < hi20 && close < p1.low) {
            return ResearchSide.sell;
          }
        case 'EMA_MEAN_REVERT':
          if (regime == 'range' &&
              close < ema20 &&
              emaDistance > atr * 1.2 &&
              bullish) {
            return ResearchSide.buy;
          }
          if (regime == 'range' &&
              close > ema20 &&
              emaDistance > atr * 1.2 &&
              bearish) {
            return ResearchSide.sell;
          }
        case 'INSIDE_BAR_BREAK':
          if (insideBar && close > p1.high && bullish && body > atr * .6) {
            return ResearchSide.buy;
          }
          if (insideBar && close < p1.low && bearish && body > atr * .6) {
            return ResearchSide.sell;
          }
        case 'TWO_BAR_MOMENTUM':
          if (priorBullish &&
              bullish &&
              priorBody > atr * .7 &&
              body > atr * .7 &&
              close > p1.high) {
            return ResearchSide.buy;
          }
          if (priorBearish &&
              bearish &&
              priorBody > atr * .7 &&
              body > atr * .7 &&
              close < p1.low) {
            return ResearchSide.sell;
          }
        case 'FAILED_BREAKOUT_V2':
          if (p1.high > preP1Hi20 &&
              p1.close < preP1Hi20 &&
              bearish &&
              close < p1.low) {
            return ResearchSide.sell;
          }
          if (p1.low < preP1Lo20 &&
              p1.close > preP1Lo20 &&
              bullish &&
              close > p1.high) {
            return ResearchSide.buy;
          }
        case 'SR_RECLAIM_V2':
          if (p1.close < preP1Lo10 && bullish && close > preP1Lo10) {
            return ResearchSide.buy;
          }
          if (p1.close > preP1Hi10 && bearish && close < preP1Hi10) {
            return ResearchSide.sell;
          }
        case 'PIN_BAR_REVERSAL':
          if (last.low < lo20 &&
              lowerWick > body * 2 &&
              lowerWick > upperWick * 1.5 &&
              close > lo20) {
            return ResearchSide.buy;
          }
          if (last.high > hi20 &&
              upperWick > body * 2 &&
              upperWick > lowerWick * 1.5 &&
              close < hi20) {
            return ResearchSide.sell;
          }
        case 'ENGULFING_REVERSAL':
          if (priorBearish &&
              bullish &&
              bodyLow <= p1BodyLow &&
              bodyHigh >= p1BodyHigh &&
              body > priorBody) {
            return ResearchSide.buy;
          }
          if (priorBullish &&
              bearish &&
              bodyHigh >= p1BodyHigh &&
              bodyLow <= p1BodyLow &&
              body > priorBody) {
            return ResearchSide.sell;
          }
        case 'NR7_BREAKOUT':
          if (p1IsNr7 && bullish && close > p1.high && body > atr * .5) {
            return ResearchSide.buy;
          }
          if (p1IsNr7 && bearish && close < p1.low && body > atr * .5) {
            return ResearchSide.sell;
          }
        case 'EMA_TREND_RECLAIM':
          if (ema20 > ema50 && p1.close < pEma20 && bullish && close > ema20) {
            return ResearchSide.buy;
          }
          if (ema20 < ema50 && p1.close > pEma20 && bearish && close < ema20) {
            return ResearchSide.sell;
          }
        case 'VOL_SPIKE_FADE':
          if (priorBearish &&
              priorBody > atr * 1.8 &&
              bullish &&
              close > p1.open &&
              last.low >= p1.low) {
            return ResearchSide.buy;
          }
          if (priorBullish &&
              priorBody > atr * 1.8 &&
              bearish &&
              close < p1.open &&
              last.high <= p1.high) {
            return ResearchSide.sell;
          }
        case 'THREE_BAR_PULLBACK':
          final p2Bearish = p2.close < p2.open;
          final p3Bearish = p3.close < p3.open;
          final p2Bullish = p2.close > p2.open;
          final p3Bullish = p3.close > p3.open;
          if (ema20 > ema50 &&
              p3Bearish &&
              p2Bearish &&
              priorBearish &&
              bullish &&
              close > p1.high) {
            return ResearchSide.buy;
          }
          if (ema20 < ema50 &&
              p3Bullish &&
              p2Bullish &&
              priorBullish &&
              bearish &&
              close < p1.low) {
            return ResearchSide.sell;
          }
        case 'RANGE_REJECTION':
          if (regime == 'range' && h.last.low < lo20 && close > lo20) {
            return ResearchSide.buy;
          }
          if (regime == 'range' && h.last.high > hi20 && close < hi20) {
            return ResearchSide.sell;
          }
      }
      return null;
    }

    for (final strategy in const StrategyRegistry().research) {
      final side = evaluate(strategy.id);
      if (side != null) {
        out[strategy.id] = side;
      }
    }
    return out;
  }

  String _regime(List<Candle> h, double atr) {
    final move = (h.last.close - h[h.length - 20].close).abs();
    final range =
        h.sublist(h.length - 20).map((e) => e.high).reduce(_max) -
        h.sublist(h.length - 20).map((e) => e.low).reduce(_min);
    if (move > atr * 4) {
      return 'trend';
    }
    if (range < atr * 6) {
      return 'range';
    }
    return 'transition';
  }

  double? _atr(List<Candle> h, int n) {
    if (h.length < n + 1) {
      return null;
    }
    var sum = 0.0;
    for (var i = h.length - n; i < h.length; i++) {
      final previousClose = h[i - 1].close;
      sum += _max(
        h[i].high - h[i].low,
        _max(
          (h[i].high - previousClose).abs(),
          (h[i].low - previousClose).abs(),
        ),
      );
    }
    return sum / n;
  }

  double? _ema(List<Candle> h, int n) =>
      h.length < n ? null : _emaValues(h.map((e) => e.close).toList(), n);

  double _emaValues(List<double> values, int n) {
    final k = 2 / (n + 1);
    var out = values[values.length - n];
    for (var i = values.length - n + 1; i < values.length; i++) {
      out = values[i] * k + out * (1 - k);
    }
    return out;
  }

  List<double> _macdSeries(List<Candle> h) {
    final out = <double>[];
    for (var i = 26; i <= h.length; i++) {
      final slice = h.sublist(0, i);
      out.add(_ema(slice, 12)! - _ema(slice, 26)!);
    }
    return out;
  }

  double? _rsi(List<Candle> h, int n) {
    if (h.length < n + 1) {
      return null;
    }
    var gain = 0.0;
    var loss = 0.0;
    for (var i = h.length - n; i < h.length; i++) {
      final delta = h[i].close - h[i - 1].close;
      if (delta > 0) {
        gain += delta;
      } else {
        loss -= delta;
      }
    }
    if (loss == 0) {
      return 100;
    }
    final rs = gain / loss;
    return 100 - 100 / (1 + rs);
  }

  (double, double, double) _bands(List<Candle> h, int n, double mult) {
    final values = h.sublist(h.length - n).map((e) => e.close).toList();
    final mean = values.reduce((a, b) => a + b) / n;
    final variance =
        values.fold<double>(
          0,
          (sum, value) => sum + (value - mean) * (value - mean),
        ) /
        n;
    final sd = _sqrt(variance);
    return (mean - mult * sd, mean, mean + mult * sd);
  }

  double _sqrt(double x) {
    if (x <= 0) {
      return 0;
    }
    var result = x;
    for (var i = 0; i < 12; i++) {
      result = (result + x / result) / 2;
    }
    return result;
  }

  double _max(double a, double b) => a > b ? a : b;
  double _min(double a, double b) => a < b ? a : b;
}
