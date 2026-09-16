import 'package:signal_engine/signal_engine.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  const calculator = BacktestMetricsCalculator();

  test('empty input has no invented rates or ratios', () {
    final metrics = calculator.calculate(const []);

    expect(metrics.totalTerminalSignals, 0);
    expect(metrics.triggeredTrades, 0);
    expect(metrics.winRate, isNull);
    expect(metrics.averagePlannedRiskReward, isNull);
    expect(metrics.expectancyR, isNull);
    expect(metrics.profitFactor, isNull);
  });

  test('invalidated and expired signals never enter trade denominator', () {
    final metrics = calculator.calculate([
      _record(HistoricalSignalRecordOutcome.invalidated, triggered: false),
      _record(HistoricalSignalRecordOutcome.expired, triggered: false),
    ]);

    expect(metrics.totalTerminalSignals, 2);
    expect(metrics.invalidatedSignals, 1);
    expect(metrics.expiredSignals, 1);
    expect(metrics.triggeredTrades, 0);
    expect(metrics.wins, 0);
    expect(metrics.losses, 0);
    expect(metrics.winRate, isNull);
  });

  test('win rate uses only resolved triggered TP and SL records', () {
    final metrics = calculator.calculate([
      _record(HistoricalSignalRecordOutcome.invalidated, triggered: false),
      _record(HistoricalSignalRecordOutcome.expired, triggered: false),
      _record(HistoricalSignalRecordOutcome.takeProfitReached, rr: 2),
      _record(HistoricalSignalRecordOutcome.takeProfitReached, rr: 3),
      _record(HistoricalSignalRecordOutcome.stopLossReached, rr: 2),
    ]);

    expect(metrics.totalTerminalSignals, 5);
    expect(metrics.triggeredTrades, 3);
    expect(metrics.wins, 2);
    expect(metrics.losses, 1);
    expect(metrics.winRate, closeTo(2 / 3, 1e-12));
    expect(metrics.averagePlannedRiskReward, closeTo(7 / 3, 1e-12));
  });

  test('expectancy is calculated in R from planned TP RR and -1R SL', () {
    final metrics = calculator.calculate([
      _record(HistoricalSignalRecordOutcome.takeProfitReached, rr: 2),
      _record(HistoricalSignalRecordOutcome.stopLossReached, rr: 4),
    ]);

    // +2R and -1R over two resolved trades = +0.5R expectancy.
    expect(metrics.expectancyR, closeTo(0.5, 1e-12));
  });

  test('profit factor uses gross winning R over gross losing R', () {
    final metrics = calculator.calculate([
      _record(HistoricalSignalRecordOutcome.takeProfitReached, rr: 2),
      _record(HistoricalSignalRecordOutcome.takeProfitReached, rr: 3),
      _record(HistoricalSignalRecordOutcome.stopLossReached, rr: 2),
      _record(HistoricalSignalRecordOutcome.stopLossReached, rr: 4),
    ]);

    // Wins contribute +5R; two losses contribute 2R total.
    expect(metrics.profitFactor, closeTo(2.5, 1e-12));
  });

  test(
    'profit factor is null rather than invented infinity with no losses',
    () {
      final metrics = calculator.calculate([
        _record(HistoricalSignalRecordOutcome.takeProfitReached, rr: 2),
      ]);

      expect(metrics.winRate, 1);
      expect(metrics.expectancyR, 2);
      expect(metrics.profitFactor, isNull);
    },
  );

  test('TP or SL without a trigger index is rejected', () {
    expect(
      () => calculator.calculate([
        _record(
          HistoricalSignalRecordOutcome.takeProfitReached,
          triggered: false,
        ),
      ]),
      throwsStateError,
    );
  });

  test('non-positive triggered RR is rejected', () {
    expect(
      () => calculator.calculate([
        _record(HistoricalSignalRecordOutcome.stopLossReached, rr: 0),
      ]),
      throwsStateError,
    );
  });
}

HistoricalSignalRecord _record(
  HistoricalSignalRecordOutcome outcome, {
  bool triggered = true,
  double rr = 2,
}) {
  return HistoricalSignalRecord(
    direction: SignalCandidateDirection.buy,
    readyAtObservationIndex: 10,
    triggeredAtObservationIndex: triggered ? 12 : null,
    terminalAtObservationIndex: 20,
    waitingCandles: 2,
    entryPrice: 2300,
    stopPrice: 2290,
    targetPrice: 2320,
    riskRewardRatio: rr,
    setupScoreEarnedPoints: 35,
    setupScoreAvailablePoints: 100,
    outcome: outcome,
  );
}
