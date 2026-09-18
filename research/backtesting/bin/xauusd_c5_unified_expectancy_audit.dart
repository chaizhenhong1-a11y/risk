import 'dart:io';

import 'package:tradeforge_backtesting/src/dataset/strategy_c_structural_lifecycle_validation.dart';
import 'package:tradeforge_backtesting/src/validation/c5_expectancy_adapter.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_audit_snapshot.dart';
import 'package:tradeforge_backtesting/src/validation/unified_strategy_expectancy_audit.dart';

const _rewardMultiple = 2.0;

void main(List<String> args) {
  if (args.length < 2 || args.length > 3) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_c5_unified_expectancy_audit.dart '
      '<structural-risk.jsonl> <forward-path.jsonl> '
      '[audit-snapshot-directory]',
    );
    exitCode = 64;
    return;
  }

  final riskFile = File(args[0]);
  final pathFile = File(args[1]);
  if (!riskFile.existsSync() || !pathFile.existsSync()) {
    stderr.writeln('Missing C5 structural-risk or forward-path dataset.');
    exitCode = 66;
    return;
  }

  final risks = riskFile
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .map(C5StructuralRisk.fromJsonLine)
      .toList();
  final paths = pathFile
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .map(C5StructuralPath.fromJsonLine)
      .toList();

  const lifecycle = C5StructuralLifecycleValidation();
  const adapter = C5ExpectancyAdapter(rewardMultiple: _rewardMultiple);
  final cases = lifecycle.join(risks: risks, paths: paths);
  final trades = [
    for (final sample in cases)
      adapter.convert(sample, lifecycle.settle(sample, _rewardMultiple)),
  ];

  final verdict = const UnifiedStrategyExpectancyAudit().evaluate([
    StrategyAuditInput(strategy: AuditedStrategy.strategyC5, trades: trades),
  ]).single;
  final r = verdict.report;

  if (args.length == 3) {
    final output = Directory(args[2])..createSync(recursive: true);
    final snapshot = StrategyAuditSnapshot(
      verdict: verdict,
      generatedAt: DateTime.now().toUtc(),
    );
    File(
      '${output.path}${Platform.pathSeparator}strategy_c5.json',
    ).writeAsStringSync('${snapshot.toJsonLine()}\n');
    stdout.writeln('Audit snapshot written to: ${output.path}');
  }

  stdout.writeln('');
  stdout.writeln('TradeForge V2 — Increment 139 C5 Unified Expectancy Audit');
  stdout.writeln(
    'Frozen C5 geometry: structural support + M15 ATR14 x 0.50 stop + 2R TP.',
  );
  stdout.writeln('Joined structural cases: ${cases.length}');
  stdout.writeln('Audit verdict: ${verdict.passes ? "PASS" : "FAIL"}');
  stdout.writeln(
    'total=${r.total} resolved=${r.resolved} W=${r.wins} L=${r.losses} '
    'expired=${r.expired} ambiguous=${r.ambiguous}',
  );
  stdout.writeln(
    'win=${(r.winRate * 100).toStringAsFixed(2)}% '
    'netE=${r.netExpectancyR.toStringAsFixed(3)}R '
    'PF=${r.profitFactor.isInfinite ? "inf" : r.profitFactor.toStringAsFixed(3)} '
    'streak=${r.maxLosingStreak}',
  );
  stdout.writeln(
    'first=${r.firstHalfNetExpectancyR.toStringAsFixed(3)}R '
    'second=${r.secondHalfNetExpectancyR.toStringAsFixed(3)}R',
  );
  stdout.writeln(
    'gates: sample=${verdict.meetsResolvedSampleFloor} '
    'expectancy=${verdict.hasPositiveExpectancy} '
    'pf=${verdict.hasProfitFactorAboveOne} '
    'first=${verdict.hasPositiveFirstHalf} '
    'second=${verdict.hasPositiveSecondHalf}',
  );
  stdout.writeln(
    'Research only. This is still the same historical discovery dataset; '
    'PASS does not replace unseen forward validation.',
  );
}
