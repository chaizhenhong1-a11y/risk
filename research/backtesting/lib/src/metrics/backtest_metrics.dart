import '../results/historical_signal_record.dart';

final class BacktestMetrics {
  const BacktestMetrics({
    required this.totalTerminalSignals,
    required this.invalidatedSignals,
    required this.expiredSignals,
    required this.triggeredTrades,
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.averagePlannedRiskReward,
    required this.expectancyR,
    required this.profitFactor,
  });

  final int totalTerminalSignals;
  final int invalidatedSignals;
  final int expiredSignals;
  final int triggeredTrades;
  final int wins;
  final int losses;

  /// Wins / (wins + losses). Null when no resolved triggered trade exists.
  final double? winRate;

  /// Mean explicit planned RR across resolved triggered records.
  final double? averagePlannedRiskReward;

  /// Baseline R expectancy: TP = +planned RR, SL = -1R.
  final double? expectancyR;

  /// Gross winning R / gross losing R.
  /// Null when there are no losses, avoiding an invented finite value.
  final double? profitFactor;
}

final class BacktestMetricsCalculator {
  const BacktestMetricsCalculator();

  BacktestMetrics calculate(Iterable<HistoricalSignalRecord> records) {
    var total = 0;
    var invalidated = 0;
    var expired = 0;
    var wins = 0;
    var losses = 0;
    var plannedRrSum = 0.0;
    var grossWinningR = 0.0;

    for (final record in records) {
      total++;

      switch (record.outcome) {
        case HistoricalSignalRecordOutcome.invalidated:
          invalidated++;
        case HistoricalSignalRecordOutcome.expired:
          expired++;
        case HistoricalSignalRecordOutcome.takeProfitReached:
          _validateTriggeredRecord(record);
          wins++;
          plannedRrSum += record.riskRewardRatio;
          grossWinningR += record.riskRewardRatio;
        case HistoricalSignalRecordOutcome.stopLossReached:
          _validateTriggeredRecord(record);
          losses++;
          plannedRrSum += record.riskRewardRatio;
      }
    }

    final triggeredTrades = wins + losses;
    if (triggeredTrades == 0) {
      return BacktestMetrics(
        totalTerminalSignals: total,
        invalidatedSignals: invalidated,
        expiredSignals: expired,
        triggeredTrades: 0,
        wins: 0,
        losses: 0,
        winRate: null,
        averagePlannedRiskReward: null,
        expectancyR: null,
        profitFactor: null,
      );
    }

    final grossLosingR = losses.toDouble();

    return BacktestMetrics(
      totalTerminalSignals: total,
      invalidatedSignals: invalidated,
      expiredSignals: expired,
      triggeredTrades: triggeredTrades,
      wins: wins,
      losses: losses,
      winRate: wins / triggeredTrades,
      averagePlannedRiskReward: plannedRrSum / triggeredTrades,
      expectancyR: (grossWinningR - grossLosingR) / triggeredTrades,
      profitFactor: losses == 0 ? null : grossWinningR / grossLosingR,
    );
  }

  void _validateTriggeredRecord(HistoricalSignalRecord record) {
    if (!record.wasTriggered) {
      throw StateError(
        'A TP/SL record must retain a triggered observation index.',
      );
    }
    if (!record.riskRewardRatio.isFinite || record.riskRewardRatio <= 0) {
      throw StateError('Triggered record RR must be finite and > 0.');
    }
  }
}
