import 'package:signal_engine/signal_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  const historicalMonitor = HistoricalTriggeredSignalMonitor();

  group('HistoricalTriggeredSignalMonitor', () {
    test('BUY remains monitoring while candle stays between SL and TP', () {
      final result = historicalMonitor.observeClosedM5Candle(
        bias: TradingBias.buy,
        stopPrice: 2290,
        targetPrice: 2320,
        candleLow: 2295,
        candleHigh: 2310,
        observationIndex: 20,
      );

      expect(result.observationIndex, 20);
      expect(result.isTerminal, isFalse);
      expect(result.monitoring.outcome, TriggeredSignalOutcome.monitoring);
      expect(
        result.monitoring.reason,
        TriggeredSignalMonitoringReason.priceBetweenStopAndTarget,
      );
    });

    test('BUY exact TP boundary touch is terminal take profit', () {
      final result = historicalMonitor.observeClosedM5Candle(
        bias: TradingBias.buy,
        stopPrice: 2290,
        targetPrice: 2320,
        candleLow: 2300,
        candleHigh: 2320,
        observationIndex: 21,
      );

      expect(result.isTerminal, isTrue);
      expect(
        result.monitoring.outcome,
        TriggeredSignalOutcome.takeProfitReached,
      );
      expect(
        result.monitoring.reason,
        TriggeredSignalMonitoringReason.targetReached,
      );
    });

    test('BUY exact SL boundary touch is terminal stop loss', () {
      final result = historicalMonitor.observeClosedM5Candle(
        bias: TradingBias.buy,
        stopPrice: 2290,
        targetPrice: 2320,
        candleLow: 2290,
        candleHigh: 2310,
        observationIndex: 21,
      );

      expect(result.isTerminal, isTrue);
      expect(result.monitoring.outcome, TriggeredSignalOutcome.stopLossReached);
      expect(
        result.monitoring.reason,
        TriggeredSignalMonitoringReason.stopReached,
      );
    });

    test('SELL exact TP boundary touch is terminal take profit', () {
      final result = historicalMonitor.observeClosedM5Candle(
        bias: TradingBias.sell,
        stopPrice: 2320,
        targetPrice: 2290,
        candleLow: 2290,
        candleHigh: 2310,
        observationIndex: 22,
      );

      expect(result.isTerminal, isTrue);
      expect(
        result.monitoring.outcome,
        TriggeredSignalOutcome.takeProfitReached,
      );
    });

    test('SELL exact SL boundary touch is terminal stop loss', () {
      final result = historicalMonitor.observeClosedM5Candle(
        bias: TradingBias.sell,
        stopPrice: 2320,
        targetPrice: 2290,
        candleLow: 2300,
        candleHigh: 2320,
        observationIndex: 22,
      );

      expect(result.isTerminal, isTrue);
      expect(result.monitoring.outcome, TriggeredSignalOutcome.stopLossReached);
    });

    test('same candle touching both SL and TP stays ambiguous', () {
      final result = historicalMonitor.observeClosedM5Candle(
        bias: TradingBias.buy,
        stopPrice: 2290,
        targetPrice: 2320,
        candleLow: 2289,
        candleHigh: 2321,
        observationIndex: 23,
      );

      expect(result.isTerminal, isFalse);
      expect(result.monitoring.outcome, TriggeredSignalOutcome.monitoring);
      expect(
        result.monitoring.reason,
        TriggeredSignalMonitoringReason.ambiguousSameCandleOutcome,
      );
    });

    test('invalid historical observation index is rejected', () {
      expect(
        () => historicalMonitor.observeClosedM5Candle(
          bias: TradingBias.buy,
          stopPrice: 2290,
          targetPrice: 2320,
          candleLow: 2300,
          candleHigh: 2310,
          observationIndex: -1,
        ),
        throwsArgumentError,
      );
    });
  });
}
