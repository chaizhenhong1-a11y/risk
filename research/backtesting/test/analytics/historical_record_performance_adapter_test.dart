import 'package:signal_engine/signal_engine.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/analytics/historical_record_performance_adapter.dart';
import 'package:tradeforge_backtesting/src/results/historical_signal_record.dart';

void main() {
  HistoricalSignalRecord record({
    required SignalCandidateDirection direction,
    required int trigger,
    required int terminal,
    required HistoricalSignalRecordOutcome outcome,
    double rr = 2,
  }) {
    return HistoricalSignalRecord(
      direction: direction,
      readyAtObservationIndex: trigger - 1,
      triggeredAtObservationIndex: trigger,
      terminalAtObservationIndex: terminal,
      waitingCandles: 1,
      entryPrice: 100,
      stopPrice: direction == SignalCandidateDirection.buy ? 99 : 101,
      targetPrice: direction == SignalCandidateDirection.buy ? 102 : 98,
      riskRewardRatio: rr,
      setupScoreEarnedPoints: 0,
      setupScoreAvailablePoints: 0,
      outcome: outcome,
    );
  }

  DateTime time(int index) =>
      DateTime.utc(2026, 1, 1).add(Duration(minutes: index * 5));

  test('preserves real BUY and SELL directions', () {
    final result = const HistoricalRecordPerformanceAdapter().analyze([
      HistoricalStrategyPerformanceInput(
        strategy: 'A',
        records: [
          record(
            direction: SignalCandidateDirection.buy,
            trigger: 1,
            terminal: 2,
            outcome: HistoricalSignalRecordOutcome.takeProfitReached,
          ),
          record(
            direction: SignalCandidateDirection.sell,
            trigger: 3,
            terminal: 4,
            outcome: HistoricalSignalRecordOutcome.stopLossReached,
          ),
        ],
        timeForObservationIndex: time,
      ),
    ]);

    expect(result.overall.tradeCount, 2);
    expect(result.byStrategyAndSide['A']!['BUY']!.tradeCount, 1);
    expect(result.byStrategyAndSide['A']!['SELL']!.tradeCount, 1);
  });

  test('excludes pre-entry invalidated and expired plans', () {
    final invalidated = HistoricalSignalRecord(
      direction: SignalCandidateDirection.buy,
      readyAtObservationIndex: 1,
      triggeredAtObservationIndex: null,
      terminalAtObservationIndex: 2,
      waitingCandles: 1,
      entryPrice: 100,
      stopPrice: 99,
      targetPrice: 102,
      riskRewardRatio: 2,
      setupScoreEarnedPoints: 0,
      setupScoreAvailablePoints: 0,
      outcome: HistoricalSignalRecordOutcome.invalidated,
    );

    final result = const HistoricalRecordPerformanceAdapter().analyze([
      HistoricalStrategyPerformanceInput(
        strategy: 'A',
        records: [invalidated],
        timeForObservationIndex: time,
      ),
    ]);

    expect(result.overall.tradeCount, 0);
  });

  test('sorts A and B globally before overall drawdown calculation', () {
    final result = const HistoricalRecordPerformanceAdapter().analyze([
      HistoricalStrategyPerformanceInput(
        strategy: 'A',
        records: [
          record(
            direction: SignalCandidateDirection.buy,
            trigger: 1,
            terminal: 2,
            outcome: HistoricalSignalRecordOutcome.takeProfitReached,
            rr: 3,
          ),
          record(
            direction: SignalCandidateDirection.buy,
            trigger: 4,
            terminal: 5,
            outcome: HistoricalSignalRecordOutcome.takeProfitReached,
            rr: 1,
          ),
        ],
        timeForObservationIndex: time,
      ),
      HistoricalStrategyPerformanceInput(
        strategy: 'B',
        records: [
          record(
            direction: SignalCandidateDirection.sell,
            trigger: 2,
            terminal: 3,
            outcome: HistoricalSignalRecordOutcome.stopLossReached,
          ),
          record(
            direction: SignalCandidateDirection.sell,
            trigger: 3,
            terminal: 4,
            outcome: HistoricalSignalRecordOutcome.stopLossReached,
          ),
        ],
        timeForObservationIndex: time,
      ),
    ]);

    // Chronological sequence is +3, -1, -1, +1 => max drawdown 2R.
    expect(result.overall.maxDrawdownR, 2);
    expect(result.overall.totalR, 2);
  });
}
