import 'package:signal_engine/signal_engine.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/results/historical_signal_record.dart';
import 'package:tradeforge_backtesting/src/validation/historical_record_expectancy_adapter.dart';
import 'package:tradeforge_backtesting/src/validation/strategy_expectancy_validator.dart';

void main() {
  HistoricalSignalRecord record(
    HistoricalSignalRecordOutcome outcome, {
    int? triggeredAtObservationIndex = 11,
  }) => HistoricalSignalRecord(
    direction: SignalCandidateDirection.buy,
    readyAtObservationIndex: 10,
    triggeredAtObservationIndex: triggeredAtObservationIndex,
    terminalAtObservationIndex: 12,
    waitingCandles: 1,
    entryPrice: 2500,
    stopPrice: 2490,
    targetPrice: 2520,
    riskRewardRatio: 2,
    setupScoreEarnedPoints: 0,
    setupScoreAvailablePoints: 0,
    outcome: outcome,
  );

  test('maps triggered TP and SL to resolved expectancy outcomes', () {
    const adapter = HistoricalRecordExpectancyAdapter();
    final time = DateTime.utc(2026, 1, 1);

    expect(
      adapter
          .convert(
            record: record(HistoricalSignalRecordOutcome.takeProfitReached),
            observedAt: time,
          )!
          .resolution,
      TradeResolution.win,
    );
    expect(
      adapter
          .convert(
            record: record(HistoricalSignalRecordOutcome.stopLossReached),
            observedAt: time,
          )!
          .resolution,
      TradeResolution.loss,
    );
  });

  test('excludes pre-entry invalidation from trading expectancy', () {
    const adapter = HistoricalRecordExpectancyAdapter();
    final result = adapter.convert(
      record: record(
        HistoricalSignalRecordOutcome.invalidated,
        triggeredAtObservationIndex: null,
      ),
      observedAt: DateTime.utc(2026, 1, 1),
    );

    expect(result, isNull);
  });

  test('keeps a triggered expiry unresolved', () {
    const adapter = HistoricalRecordExpectancyAdapter();
    final result = adapter.convert(
      record: record(HistoricalSignalRecordOutcome.expired),
      observedAt: DateTime.utc(2026, 1, 1),
    );

    expect(result!.resolution, TradeResolution.expired);
  });
}
