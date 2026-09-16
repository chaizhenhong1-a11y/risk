import 'package:signal_engine/signal_engine.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  const builder = BacktestRunReportBuilder();

  group('BacktestRunReportBuilder', () {
    test('builds empty report without inventing metrics', () {
      final report = builder.build(const []);

      expect(report.records, isEmpty);
      expect(report.metrics.totalTerminalSignals, 0);
      expect(report.metrics.triggeredTrades, 0);
      expect(report.metrics.winRate, isNull);
      expect(report.metrics.expectancyR, isNull);
      expect(report.metrics.profitFactor, isNull);
    });

    test('retains records and calculates one consistent metrics snapshot', () {
      final records = [
        _record(
          HistoricalSignalRecordOutcome.takeProfitReached,
          rr: 2,
          terminalIndex: 20,
        ),
        _record(
          HistoricalSignalRecordOutcome.stopLossReached,
          rr: 3,
          terminalIndex: 30,
        ),
        _record(
          HistoricalSignalRecordOutcome.expired,
          triggered: false,
          terminalIndex: 40,
        ),
      ];

      final report = builder.build(records);

      expect(report.records, hasLength(3));
      expect(report.metrics.totalTerminalSignals, 3);
      expect(report.metrics.expiredSignals, 1);
      expect(report.metrics.triggeredTrades, 2);
      expect(report.metrics.wins, 1);
      expect(report.metrics.losses, 1);
      expect(report.metrics.winRate, 0.5);
      expect(report.metrics.averagePlannedRiskReward, 2.5);
      expect(report.metrics.expectancyR, 0.5);
      expect(report.metrics.profitFactor, 2);
    });

    test('report records are immutable', () {
      final source = [
        _record(
          HistoricalSignalRecordOutcome.takeProfitReached,
          terminalIndex: 20,
        ),
      ];

      final report = builder.build(source);
      source.add(
        _record(
          HistoricalSignalRecordOutcome.stopLossReached,
          terminalIndex: 30,
        ),
      );

      expect(report.records, hasLength(1));
      expect(
        () => report.records.add(
          _record(
            HistoricalSignalRecordOutcome.expired,
            triggered: false,
            terminalIndex: 40,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test(
      'invalidated and expired records stay outside win/loss denominator',
      () {
        final report = builder.build([
          _record(
            HistoricalSignalRecordOutcome.invalidated,
            triggered: false,
            terminalIndex: 20,
          ),
          _record(
            HistoricalSignalRecordOutcome.expired,
            triggered: false,
            terminalIndex: 30,
          ),
          _record(
            HistoricalSignalRecordOutcome.takeProfitReached,
            rr: 2,
            terminalIndex: 40,
          ),
        ]);

        expect(report.metrics.totalTerminalSignals, 3);
        expect(report.metrics.invalidatedSignals, 1);
        expect(report.metrics.expiredSignals, 1);
        expect(report.metrics.triggeredTrades, 1);
        expect(report.metrics.wins, 1);
        expect(report.metrics.losses, 0);
        expect(report.metrics.winRate, 1);
      },
    );
  });
}

HistoricalSignalRecord _record(
  HistoricalSignalRecordOutcome outcome, {
  bool triggered = true,
  double rr = 2,
  required int terminalIndex,
}) {
  return HistoricalSignalRecord(
    direction: SignalCandidateDirection.buy,
    readyAtObservationIndex: 10,
    triggeredAtObservationIndex: triggered ? 12 : null,
    terminalAtObservationIndex: terminalIndex,
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
