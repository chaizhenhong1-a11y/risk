import 'dart:convert';
import 'dart:io';

import 'package:tradeforge_backtesting/src/validation/strategy_expectancy_validator.dart';
import 'package:tradeforge_backtesting/src/validation/unified_strategy_expectancy_audit.dart';

/// Audits lifecycle exports produced by the frozen A/B/C5 strategy runners.
///
/// JSONL row:
/// {"strategy":"A","observedAt":"...","resolution":"win",
///  "rewardRisk":2.0,"costR":0.0}
///
/// This runner intentionally refuses to reconstruct Entry/SL/TP with generic
/// proxies. A/B/C5 have different frozen risk rules, so their own replay
/// runners must own lifecycle generation.
void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_abc_expectancy_audit.dart '
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

  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final json = jsonDecode(line) as Map<String, dynamic>;
    final strategy = _strategy(json['strategy'] as String);
    grouped[strategy]!.add(
      StrategyTradeResult(
        observedAt: DateTime.parse(json['observedAt'] as String).toUtc(),
        resolution: _resolution(json['resolution'] as String),
        rewardRisk: (json['rewardRisk'] as num).toDouble(),
        costR: ((json['costR'] as num?) ?? 0).toDouble(),
      ),
    );
  }

  final verdicts = const UnifiedStrategyExpectancyAudit().evaluate([
    for (final entry in grouped.entries)
      StrategyAuditInput(strategy: entry.key, trades: entry.value),
  ]);

  stdout.writeln('');
  stdout.writeln(
    'TradeForge V2 — Increment 138 A/B/C5 Unified Expectancy Audit',
  );
  stdout.writeln(
    'Frozen standard: resolved>=30, net expectancy>0, PF>1, '
    'first-half>0, second-half>0.',
  );

  for (final verdict in verdicts) {
    final r = verdict.report;
    stdout.writeln('');
    stdout.writeln(
      '${verdict.strategy.name}: ${verdict.passes ? "PASS" : "FAIL"}',
    );
    stdout.writeln(
      '  total=${r.total} resolved=${r.resolved} W=${r.wins} L=${r.losses} '
      'expired=${r.expired} ambiguous=${r.ambiguous}',
    );
    stdout.writeln(
      '  win=${(r.winRate * 100).toStringAsFixed(2)}% '
      'netE=${r.netExpectancyR.toStringAsFixed(3)}R '
      'PF=${r.profitFactor.isInfinite ? "inf" : r.profitFactor.toStringAsFixed(3)} '
      'streak=${r.maxLosingStreak}',
    );
    stdout.writeln(
      '  first=${r.firstHalfNetExpectancyR.toStringAsFixed(3)}R '
      'second=${r.secondHalfNetExpectancyR.toStringAsFixed(3)}R',
    );
    stdout.writeln(
      '  gates: sample=${verdict.meetsResolvedSampleFloor} '
      'expectancy=${verdict.hasPositiveExpectancy} '
      'pf=${verdict.hasProfitFactorAboveOne} '
      'first=${verdict.hasPositiveFirstHalf} '
      'second=${verdict.hasPositiveSecondHalf}',
    );
  }
}

AuditedStrategy _strategy(String value) {
  switch (value.trim().toUpperCase()) {
    case 'A':
      return AuditedStrategy.strategyA;
    case 'B':
      return AuditedStrategy.strategyB;
    case 'C5':
      return AuditedStrategy.strategyC5;
    default:
      throw FormatException('Unknown strategy: $value');
  }
}

TradeResolution _resolution(String value) {
  switch (value.trim().toLowerCase()) {
    case 'win':
      return TradeResolution.win;
    case 'loss':
      return TradeResolution.loss;
    case 'expired':
      return TradeResolution.expired;
    case 'ambiguous':
      return TradeResolution.ambiguous;
    default:
      throw FormatException('Unknown resolution: $value');
  }
}
