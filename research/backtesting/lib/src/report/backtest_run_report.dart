import '../metrics/backtest_metrics.dart';
import '../results/historical_signal_record.dart';

/// Immutable result of one completed historical research run.
///
/// This object intentionally does not perform replay or invent execution
/// assumptions. It is the integration boundary between collected historical
/// signal-plan records and aggregate metrics.
final class BacktestRunReport {
  BacktestRunReport({
    required Iterable<HistoricalSignalRecord> records,
    required this.metrics,
  }) : records = List.unmodifiable(records);

  final List<HistoricalSignalRecord> records;
  final BacktestMetrics metrics;
}

/// Builds one internally consistent report from completed historical records.
final class BacktestRunReportBuilder {
  const BacktestRunReportBuilder({
    this.metricsCalculator = const BacktestMetricsCalculator(),
  });

  final BacktestMetricsCalculator metricsCalculator;

  BacktestRunReport build(Iterable<HistoricalSignalRecord> records) {
    final frozenRecords = List<HistoricalSignalRecord>.unmodifiable(records);
    final metrics = metricsCalculator.calculate(frozenRecords);

    return BacktestRunReport(records: frozenRecords, metrics: metrics);
  }
}
