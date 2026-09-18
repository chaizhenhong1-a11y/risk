import 'dart:convert';

import 'strategy_expectancy_validator.dart';
import 'unified_strategy_expectancy_audit.dart';

final class StrategyAuditSnapshot {
  const StrategyAuditSnapshot({
    required this.verdict,
    required this.generatedAt,
  });

  final StrategyAuditVerdict verdict;
  final DateTime generatedAt;

  String toJsonLine() => jsonEncode({
    'schemaVersion': 1,
    'strategy': verdict.strategy.name,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'report': {
      'total': verdict.report.total,
      'resolved': verdict.report.resolved,
      'wins': verdict.report.wins,
      'losses': verdict.report.losses,
      'expired': verdict.report.expired,
      'ambiguous': verdict.report.ambiguous,
      'winRate': verdict.report.winRate,
      'averageWinR': verdict.report.averageWinR,
      'averageLossR': verdict.report.averageLossR,
      'grossExpectancyR': verdict.report.grossExpectancyR,
      'netExpectancyR': verdict.report.netExpectancyR,
      'profitFactor': verdict.report.profitFactor.isInfinite
          ? 'infinity'
          : verdict.report.profitFactor,
      'maxLosingStreak': verdict.report.maxLosingStreak,
      'firstHalfNetExpectancyR': verdict.report.firstHalfNetExpectancyR,
      'secondHalfNetExpectancyR': verdict.report.secondHalfNetExpectancyR,
    },
    'gates': {
      'sample': verdict.meetsResolvedSampleFloor,
      'expectancy': verdict.hasPositiveExpectancy,
      'profitFactor': verdict.hasProfitFactorAboveOne,
      'firstHalf': verdict.hasPositiveFirstHalf,
      'secondHalf': verdict.hasPositiveSecondHalf,
    },
  });

  factory StrategyAuditSnapshot.fromJsonLine(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    if (json['schemaVersion'] != 1) {
      throw FormatException(
        'Unsupported strategy audit snapshot schema: ${json['schemaVersion']}',
      );
    }

    final reportJson = json['report'] as Map<String, dynamic>;
    final gates = json['gates'] as Map<String, dynamic>;
    final profitFactorValue = reportJson['profitFactor'];

    final report = StrategyExpectancyReport(
      total: reportJson['total'] as int,
      resolved: reportJson['resolved'] as int,
      wins: reportJson['wins'] as int,
      losses: reportJson['losses'] as int,
      expired: reportJson['expired'] as int,
      ambiguous: reportJson['ambiguous'] as int,
      winRate: (reportJson['winRate'] as num).toDouble(),
      averageWinR: (reportJson['averageWinR'] as num).toDouble(),
      averageLossR: (reportJson['averageLossR'] as num).toDouble(),
      grossExpectancyR: (reportJson['grossExpectancyR'] as num).toDouble(),
      netExpectancyR: (reportJson['netExpectancyR'] as num).toDouble(),
      profitFactor: profitFactorValue == 'infinity'
          ? double.infinity
          : (profitFactorValue as num).toDouble(),
      maxLosingStreak: reportJson['maxLosingStreak'] as int,
      firstHalfNetExpectancyR: (reportJson['firstHalfNetExpectancyR'] as num)
          .toDouble(),
      secondHalfNetExpectancyR: (reportJson['secondHalfNetExpectancyR'] as num)
          .toDouble(),
    );

    return StrategyAuditSnapshot(
      verdict: StrategyAuditVerdict(
        strategy: AuditedStrategy.values.byName(json['strategy'] as String),
        report: report,
        meetsResolvedSampleFloor: gates['sample'] as bool,
        hasPositiveExpectancy: gates['expectancy'] as bool,
        hasProfitFactorAboveOne: gates['profitFactor'] as bool,
        hasPositiveFirstHalf: gates['firstHalf'] as bool,
        hasPositiveSecondHalf: gates['secondHalf'] as bool,
      ),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );
  }
}
