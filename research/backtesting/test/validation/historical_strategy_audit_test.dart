import 'package:signal_engine/signal_engine.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/results/historical_signal_record.dart';
import 'package:tradeforge_backtesting/src/validation/historical_strategy_audit.dart';
import 'package:tradeforge_backtesting/src/validation/unified_strategy_expectancy_audit.dart';

void main() {
  HistoricalSignalRecord trade(int index, bool win) => HistoricalSignalRecord(
    direction: SignalCandidateDirection.buy,
    readyAtObservationIndex: index,
    triggeredAtObservationIndex: index,
    terminalAtObservationIndex: index + 1,
    waitingCandles: 0,
    entryPrice: 2500,
    stopPrice: 2490,
    targetPrice: 2520,
    riskRewardRatio: 2,
    setupScoreEarnedPoints: 0,
    setupScoreAvailablePoints: 0,
    outcome: win
        ? HistoricalSignalRecordOutcome.takeProfitReached
        : HistoricalSignalRecordOutcome.stopLossReached,
  );

  test('audits frozen historical records with common validation gates', () {
    final records = [for (var i = 0; i < 40; i++) trade(i * 2, i.isEven)];

    final result = const HistoricalStrategyAudit().evaluate(
      strategy: AuditedStrategy.strategyA,
      records: records,
      timeForObservationIndex: (index) =>
          DateTime.utc(2026, 1, 1).add(Duration(minutes: index * 5)),
    );

    expect(result.terminalPlans, 40);
    expect(result.triggeredTrades, 40);
    expect(result.preEntryTerminalPlans, 0);
    expect(result.verdict.passes, isTrue);
  });

  test('rejects C5 because it owns a separate structural lifecycle', () {
    expect(
      () => const HistoricalStrategyAudit().evaluate(
        strategy: AuditedStrategy.strategyC5,
        records: const [],
        timeForObservationIndex: (_) => DateTime.utc(2026),
      ),
      throwsArgumentError,
    );
  });
}
