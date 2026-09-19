import 'dart:convert';
import 'dart:io';

import 'package:tradeforge_backtesting/src/analytics/strategy_performance_adapter.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_expectancy_validator.dart';
import 'package:tradeforge_backtesting/src/validation/unified_strategy_expectancy_audit.dart';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_abc_performance_report.dart '
      '<abc-lifecycle.jsonl>',
    );
    exitCode = 64;
    return;
  }

  final file = File(args.single);
  if (!file.existsSync()) {
    stderr.writeln('Missing lifecycle export: ${file.path}');
    exitCode = 66;
    return;
  }

  final grouped = <AuditedStrategy, List<StrategyTradeResult>>{
    for (final strategy in AuditedStrategy.values) strategy: [],
  };
  final directional = <AuditedStrategy, List<DirectionalStrategyTradeResult>>{};

  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final json = jsonDecode(line) as Map<String, dynamic>;
    final strategy = _strategy(json['strategy'] as String);
    final trade = StrategyTradeResult(
      observedAt: DateTime.parse(json['observedAt'] as String).toUtc(),
      resolution: _resolution(json['resolution'] as String),
      rewardRisk: (json['rewardRisk'] as num).toDouble(),
      costR: ((json['costR'] as num?) ?? 0).toDouble(),
    );
    grouped[strategy]!.add(trade);

    final side = (json['side'] as String?)?.trim().toUpperCase();
    if (side == 'BUY' || side == 'SELL') {
      directional
          .putIfAbsent(strategy, () => [])
          .add(DirectionalStrategyTradeResult(trade: trade, side: side!));
    }
  }

  final inputs = [
    for (final entry in grouped.entries)
      StrategyAuditInput(strategy: entry.key, trades: entry.value),
  ];
  final performance = const StrategyPerformanceAdapter().fromAuditedTrades(
    inputs,
    directionalTrades: directional,
  );

  stdout.writeln('TradeForge V2 — A/B/C5 Strategy Performance');
  _print('OVERALL', performance.overall);
  for (final entry in performance.byStrategy.entries) {
    _print('Strategy ${entry.key}', entry.value);
    final sides = performance.byStrategyAndSide[entry.key] ?? const {};
    for (final side in sides.entries) {
      _print('  ${side.key}', side.value);
    }
  }
}

void _print(String label, dynamic m) {
  stdout.writeln('');
  stdout.writeln(label);
  stdout.writeln(
    '  trades=${m.tradeCount} W=${m.winCount} L=${m.lossCount} '
    'BE=${m.breakEvenCount}',
  );
  stdout.writeln(
    '  win=${m.winRate == null ? "n/a" : "${(m.winRate * 100).toStringAsFixed(2)}%"} '
    'E=${m.expectancyR == null ? "n/a" : "${m.expectancyR.toStringAsFixed(3)}R"} '
    'PF=${m.profitFactor == null
        ? "n/a"
        : m.profitFactor.isInfinite
        ? "inf"
        : m.profitFactor.toStringAsFixed(3)}',
  );
  stdout.writeln(
    '  total=${m.totalR.toStringAsFixed(3)}R '
    'maxDD=${m.maxDrawdownR.toStringAsFixed(3)}R',
  );
}

AuditedStrategy _strategy(String value) => switch (value.trim().toUpperCase()) {
  'A' => AuditedStrategy.strategyA,
  'B' => AuditedStrategy.strategyB,
  'C5' => AuditedStrategy.strategyC5,
  _ => throw FormatException('Unknown strategy: $value'),
};

TradeResolution _resolution(String value) =>
    switch (value.trim().toLowerCase()) {
      'win' => TradeResolution.win,
      'loss' => TradeResolution.loss,
      'expired' => TradeResolution.expired,
      'ambiguous' => TradeResolution.ambiguous,
      _ => throw FormatException('Unknown resolution: $value'),
    };
