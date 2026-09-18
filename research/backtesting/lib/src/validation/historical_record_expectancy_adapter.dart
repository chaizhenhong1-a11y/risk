import '../results/historical_signal_record.dart';
import 'strategy_expectancy_validator.dart';

/// Converts the frozen A/B historical lifecycle record into the unified
/// expectancy representation without reconstructing Entry/SL/TP.
///
/// Only triggered records become trades. READY plans that invalidate/expire
/// before entry are not trading P/L and therefore must not dilute expectancy.
final class HistoricalRecordExpectancyAdapter {
  const HistoricalRecordExpectancyAdapter();

  StrategyTradeResult? convert({
    required HistoricalSignalRecord record,
    required DateTime observedAt,
    double costR = 0,
  }) {
    if (!record.wasTriggered) return null;

    final resolution = switch (record.outcome) {
      HistoricalSignalRecordOutcome.takeProfitReached => TradeResolution.win,
      HistoricalSignalRecordOutcome.stopLossReached => TradeResolution.loss,
      HistoricalSignalRecordOutcome.expired => TradeResolution.expired,
      HistoricalSignalRecordOutcome.invalidated => TradeResolution.expired,
    };

    return StrategyTradeResult(
      observedAt: observedAt,
      resolution: resolution,
      rewardRisk: record.riskRewardRatio,
      costR: costR,
    );
  }
}
