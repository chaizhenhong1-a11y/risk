import 'dart:io';

import 'package:technical_analysis/technical_analysis.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';
import 'package:tradeforge_backtesting/src/cache/market_structure_research_cache.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_expectancy_validator.dart';

const _riskRewards = <double>[1.5, 2.0, 2.5, 3.0];
const _expiryBars = 48;
const _lookbackBars = 12;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_g4_ohlc_expectancy_validation.dart '
      '<history-directory>',
    );
    exitCode = 64;
    return;
  }

  final cacheFile = File(
    '.research_cache${Platform.pathSeparator}market_structure'
    '${Platform.pathSeparator}xauusd_market_structure.jsonl',
  );
  if (!cacheFile.existsSync()) {
    stderr.writeln('Missing cache: ${cacheFile.path}');
    exitCode = 66;
    return;
  }

  final historyFile = File(
    '${args.first}${Platform.pathSeparator}XAUUSD_M5_2024_2026.csv',
  );
  if (!historyFile.existsSync()) {
    stderr.writeln('Missing: ${historyFile.path}');
    exitCode = 66;
    return;
  }

  final rows = const MarketStructureResearchCache().read(cacheFile);
  final candles = const Mt5HistoryAdapter()
      .parse(
        content: historyFile.readAsStringSync(),
        timeframe: MarketTimeframe.m5,
      )
      .candles;

  final candleByCloseTime = {
    for (final candle in candles) candle.closeTime.toUtc(): candle,
  };
  final rowIndexByTime = {
    for (var i = 0; i < rows.length; i++) rows[i].time.toUtc(): i,
  };

  final episodes = <_Episode>[];
  var wasG4 = false;

  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final isG4 =
        row.h4 == MarketStructure.neutral &&
        row.h1 == MarketStructure.bearish &&
        row.m15 == MarketStructure.bearish;

    if (!isG4) {
      wasG4 = false;
      continue;
    }
    if (wasG4) continue;
    wasG4 = true;

    final candle = candleByCloseTime[row.time.toUtc()];
    if (candle == null) continue;

    var priorLow = double.infinity;
    var available = true;
    for (var j = 1; j <= _lookbackBars; j++) {
      final priorTimeIndex = i - j;
      if (priorTimeIndex < 0) {
        available = false;
        break;
      }
      final prior = candleByCloseTime[rows[priorTimeIndex].time.toUtc()];
      if (prior == null) {
        available = false;
        break;
      }
      if (prior.low < priorLow) priorLow = prior.low;
    }
    if (!available || !priorLow.isFinite) continue;

    final entry = candle.close;
    final risk = entry - priorLow;
    if (!risk.isFinite || risk <= 0) continue;

    episodes.add(
      _Episode(
        observedAt: row.time.toUtc(),
        entry: entry,
        stop: priorLow,
        risk: risk,
      ),
    );
  }

  stdout.writeln('');
  stdout.writeln('TradeForge V2 — Increment 135 G4 OHLC Expectancy Validation');
  stdout.writeln(
    'G4 = H4 neutral / H1 bearish / M15 bearish; BUY reversal hypothesis.',
  );
  stdout.writeln(
    'Entry = G4 episode-start M5 close; stop proxy = lowest prior 12 M5 lows; '
    'expiry = 48 M5.',
  );
  stdout.writeln(
    'OHLC lifecycle marks a bar ambiguous if both stop and target are touched.',
  );
  stdout.writeln('Eligible episodes: ${episodes.length}');
  stdout.writeln('');

  const validator = StrategyExpectancyValidator();

  for (final rr in _riskRewards) {
    final trades = <StrategyTradeResult>[];

    for (final episode in episodes) {
      final startIndex = rowIndexByTime[episode.observedAt];
      if (startIndex == null) continue;
      final target = episode.entry + episode.risk * rr;
      var resolution = TradeResolution.expired;

      for (var offset = 1; offset <= _expiryBars; offset++) {
        final index = startIndex + offset;
        if (index >= rows.length) break;
        final candle = candleByCloseTime[rows[index].time.toUtc()];
        if (candle == null) continue;

        final hitStop = candle.low <= episode.stop;
        final hitTarget = candle.high >= target;

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
          observedAt: episode.observedAt,
          resolution: resolution,
          rewardRisk: rr,
        ),
      );
    }

    final report = validator.evaluate(trades);
    stdout.writeln('RR ${rr.toStringAsFixed(1)}');
    stdout.writeln(
      '  total=${report.total} resolved=${report.resolved} '
      'wins=${report.wins} losses=${report.losses} '
      'expired=${report.expired} ambiguous=${report.ambiguous}',
    );
    stdout.writeln(
      '  winRate=${_pct(report.winRate)} '
      'avgWin=${report.averageWinR.toStringAsFixed(3)}R '
      'avgLoss=${report.averageLossR.toStringAsFixed(3)}R',
    );
    stdout.writeln(
      '  expectancy=${report.grossExpectancyR.toStringAsFixed(3)}R '
      'PF=${_pf(report.profitFactor)} '
      'maxLosingStreak=${report.maxLosingStreak}',
    );
    stdout.writeln(
      '  chronological expectancy: '
      'first=${report.firstHalfNetExpectancyR.toStringAsFixed(3)}R '
      'second=${report.secondHalfNetExpectancyR.toStringAsFixed(3)}R',
    );
  }

  stdout.writeln('');
  stdout.writeln(
    'Research only. A positive result here still requires a real structural '
    'invalidation rule, transaction-cost stress, and unseen validation.',
  );
}

String _pct(double value) => '${(value * 100).toStringAsFixed(2)}%';

String _pf(double value) => value.isInfinite ? 'inf' : value.toStringAsFixed(3);

final class _Episode {
  const _Episode({
    required this.observedAt,
    required this.entry,
    required this.stop,
    required this.risk,
  });

  final DateTime observedAt;
  final double entry;
  final double stop;
  final double risk;
}
