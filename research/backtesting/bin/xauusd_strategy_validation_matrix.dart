import 'dart:io';

import 'package:tradeforge_backtesting/src/validation/strategy_audit_snapshot.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_validation_matrix.dart';
import 'package:tradeforge_backtesting/src/validation/unified_strategy_expectancy_audit.dart';

const _snapshotFiles = <AuditedStrategy, String>{
  AuditedStrategy.strategyA: 'strategy_a.json',
  AuditedStrategy.strategyB: 'strategy_b.json',
  AuditedStrategy.strategyC5: 'strategy_c5.json',
};

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_strategy_validation_matrix.dart '
      '<audit-snapshot-directory>',
    );
    exitCode = 64;
    return;
  }

  final directory = Directory(arguments.single);
  if (!directory.existsSync()) {
    stderr.writeln('Audit snapshot directory not found: ${directory.path}');
    exitCode = 66;
    return;
  }

  final snapshots = <AuditedStrategy, StrategyAuditSnapshot>{};
  for (final entry in _snapshotFiles.entries) {
    final file = File(
      '${directory.path}${Platform.pathSeparator}${entry.value}',
    );
    if (!file.existsSync()) {
      stderr.writeln('Missing audit snapshot: ${file.path}');
      exitCode = 66;
      return;
    }
    final snapshot = StrategyAuditSnapshot.fromJsonLine(
      file.readAsStringSync().trim(),
    );
    if (snapshot.verdict.strategy != entry.key) {
      throw StateError(
        'Snapshot ${file.path} contains ${snapshot.verdict.strategy.name}, '
        'expected ${entry.key.name}.',
      );
    }
    snapshots[entry.key] = snapshot;
  }

  final matrix = StrategyValidationMatrix([
    for (final strategy in AuditedStrategy.values)
      StrategyValidationEvidence.fromHistoricalAudit(
        snapshots[strategy]!.verdict,
        // Increment 119 established C5 cost-stress evidence on the same
        // historical research dataset. A/B remain explicitly not evaluated.
        costStress: strategy == AuditedStrategy.strategyC5
            ? ValidationEvidenceStatus.pass
            : ValidationEvidenceStatus.notEvaluated,
      ),
  ]);

  stdout.writeln('TradeForge V2 — Increment 143 Strategy Validation Matrix');
  stdout.writeln(
    'Evidence is loaded from strategy audit snapshots, not copied by hand.',
  );
  stdout.writeln(
    'Historical PASS only permits paper/forward observation. '
    'Unseen forward remains PENDING.',
  );
  stdout.writeln('');
  stdout.writeln(
    'Strategy | Hist E | Chrono | Sample | Cost | Unseen | Eligibility',
  );
  stdout.writeln(
    '---------|--------|--------|--------|------|--------|------------',
  );
  for (final strategy in AuditedStrategy.values) {
    final row = matrix.forStrategy(strategy);
    final snapshot = snapshots[strategy]!;
    stdout.writeln(
      '${_name(strategy).padRight(8)} | '
      '${_status(row.historicalExpectancy).padRight(6)} | '
      '${_status(row.chronologicalStability).padRight(6)} | '
      '${_status(row.sampleSufficiency).padRight(6)} | '
      '${_status(row.costStress).padRight(4)} | '
      '${_status(row.unseenForward).padRight(6)} | '
      '${row.eligibility.name}',
    );
    final r = snapshot.verdict.report;
    stdout.writeln(
      '         resolved=${r.resolved} W=${r.wins} L=${r.losses} '
      'netE=${r.netExpectancyR.toStringAsFixed(3)}R '
      'PF=${r.profitFactor.isInfinite ? "inf" : r.profitFactor.toStringAsFixed(3)} '
      'snapshot=${snapshot.generatedAt.toUtc().toIso8601String()}',
    );
  }
}

String _name(AuditedStrategy strategy) => switch (strategy) {
  AuditedStrategy.strategyA => 'A',
  AuditedStrategy.strategyB => 'B',
  AuditedStrategy.strategyC5 => 'C5',
};

String _status(ValidationEvidenceStatus status) => switch (status) {
  ValidationEvidenceStatus.pass => 'PASS',
  ValidationEvidenceStatus.fail => 'FAIL',
  ValidationEvidenceStatus.pending => 'PENDING',
  ValidationEvidenceStatus.notEvaluated => 'N/A',
};
