import '../results/historical_signal_record.dart';
import 'historical_record_expectancy_adapter.dart';
import 'unified_strategy_expectancy_audit.dart';

final class HistoricalStrategyAuditResult {
  const HistoricalStrategyAuditResult({
    required this.verdict,
    required this.terminalPlans,
    required this.triggeredTrades,
    required this.preEntryTerminalPlans,
  });

  final StrategyAuditVerdict verdict;
  final int terminalPlans;
  final int triggeredTrades;
  final int preEntryTerminalPlans;
}

/// Shared A/B audit path. Strategy generation/risk/lifecycle stay frozen in
/// their existing replay runners; this layer only evaluates their emitted
/// HistoricalSignalRecord objects under Increment 138's common standard.
final class HistoricalStrategyAudit {
  const HistoricalStrategyAudit({
    this.adapter = const HistoricalRecordExpectancyAdapter(),
    this.audit = const UnifiedStrategyExpectancyAudit(),
  });

  final HistoricalRecordExpectancyAdapter adapter;
  final UnifiedStrategyExpectancyAudit audit;

  HistoricalStrategyAuditResult evaluate({
    required AuditedStrategy strategy,
    required List<HistoricalSignalRecord> records,
    required DateTime Function(int observationIndex) timeForObservationIndex,
    double costR = 0,
  }) {
    if (strategy == AuditedStrategy.strategyC5) {
      throw ArgumentError.value(
        strategy,
        'strategy',
        'C5 uses its structural lifecycle adapter.',
      );
    }

    final trades = [
      for (final record in records)
        ?adapter.convert(
          record: record,
          observedAt: timeForObservationIndex(
            record.triggeredAtObservationIndex ??
                record.terminalAtObservationIndex,
          ),
          costR: costR,
        ),
    ];

    return HistoricalStrategyAuditResult(
      verdict: audit.evaluate([
        StrategyAuditInput(strategy: strategy, trades: trades),
      ]).single,
      terminalPlans: records.length,
      triggeredTrades: trades.length,
      preEntryTerminalPlans: records.length - trades.length,
    );
  }
}
